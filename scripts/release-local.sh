#!/bin/bash
set -euo pipefail

# The Developer ID private key and notary profile stay in this Mac's Keychain.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

usage() {
    cat <<'HELP'
Usage: bash scripts/release-local.sh --run RUN_ID [--repo OWNER/REPO] [--publish]

Download a successful tag build, sign the app and DMG, and notarize locally.
Default: create a local DMG. --publish also creates a new GitHub Release.
Packaging uses macOS tools; only GitHub's official gh must be installed.

Required: NOTARY_PROFILE (notarytool credentials in the local Keychain).
Optional: SIGNING_IDENTITY (Developer ID certificate name or SHA-1).
If exactly one valid Developer ID Application is installed, it is selected.
HELP
}

RUN_ID=""
REPOSITORY="ruivza/speechdock"
PUBLISH=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --run|--repo)
            [ "$#" -ge 2 ] || { usage >&2; exit 1; }
            if [ "$1" = --run ]; then RUN_ID="$2"; else REPOSITORY="$2"; fi
            shift 2 ;;
        --publish) PUBLISH=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done
[[ "$RUN_ID" =~ ^[0-9]+$ ]] || { echo "Error: --run requires a numeric Actions run ID." >&2; exit 1; }
[[ "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "Error: invalid repository." >&2; exit 1; }
: "${NOTARY_PROFILE:?Create a local profile with: xcrun notarytool store-credentials speechdock-release}"
for tool in gh python3 security codesign ditto hdiutil xcrun; do
    command -v "$tool" >/dev/null || { echo "Error: missing $tool (see docs/build-release.md)." >&2; exit 1; }
done

VERSION=$(cat VERSION)
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Error: invalid VERSION." >&2; exit 1; }
TAG="v$VERSION"
COMMIT=$(git rev-parse "refs/tags/$TAG^{commit}")
[[ "$(git rev-parse HEAD)" = "$COMMIT" ]] || { echo "Error: check out $TAG before signing." >&2; exit 1; }
git diff --quiet "$COMMIT" -- scripts VERSION Resources/SpeechDock.entitlements InputMethod/VoiceInput.entitlements || {
    echo "Error: release scripts and entitlements must match $TAG. Commit changes before tagging." >&2
    exit 1
}
gh auth status --hostname github.com >/dev/null
[[ "$(gh api "repos/$REPOSITORY/commits/$TAG" --jq .sha)" = "$COMMIT" ]] || {
    echo "Error: local and remote tags differ." >&2; exit 1;
}
if [ "$PUBLISH" = true ] && gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
    echo "Error: Release $TAG already exists. Existing releases are not overwritten." >&2
    exit 1
fi

# Resolve only a valid Developer ID Application from the local Keychain.
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | python3 -c '
import re, sys
requested = sys.argv[1]
identities = re.findall(r"\b([A-Fa-f0-9]{40})\s+\"(Developer ID Application:[^\"]+)\"", sys.stdin.read())
matches = [(key, name) for key, name in identities if not requested or requested in (key, name)]
matches = list(dict.fromkeys(matches))
if len(matches) != 1:
    raise SystemExit("Install one Developer ID Application with its private key, or set SIGNING_IDENTITY to an exact name or SHA-1.")
print(matches[0][0])
' "${SIGNING_IDENTITY:-}")

mkdir -p "$PROJECT_DIR/build"
WORK_DIR=$(mktemp -d "$PROJECT_DIR/build/local-release.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT
gh run view "$RUN_ID" --repo "$REPOSITORY" \
    --json headSha,headBranch,status,conclusion,event,workflowName > "$WORK_DIR/run.json"
python3 - "$WORK_DIR/run.json" "$COMMIT" "$TAG" <<'PY'
import json
import sys
from pathlib import Path
run = json.loads(Path(sys.argv[1]).read_text())
expected = {"headSha": sys.argv[2], "headBranch": sys.argv[3], "status": "completed",
            "conclusion": "success", "event": "push", "workflowName": "Build Release Artifact"}
if any(run.get(key) != value for key, value in expected.items()):
    raise SystemExit("Actions run must be a successful Build Release Artifact push for this exact tag and commit.")
PY
gh run download "$RUN_ID" --repo "$REPOSITORY" \
    --name "SpeechDock-$VERSION-unsigned" --dir "$WORK_DIR/download"
ARCHIVE="$WORK_DIR/download/SpeechDock-$VERSION-unsigned.zip"

# Validate archive paths before ditto restores executable modes and symlinks.
python3 - "$ARCHIVE" "$VERSION" "$COMMIT" <<'PY'
import json
import posixpath
import stat
import sys
import zipfile
from pathlib import PurePosixPath
with zipfile.ZipFile(sys.argv[1]) as archive:
    names = set()
    links = {}
    app_paths = []
    for entry in archive.infolist():
        path = PurePosixPath(entry.filename)
        if path.is_absolute() or ".." in path.parts or "\\" in entry.filename or not path.parts:
            raise SystemExit("Unsafe archive path")
        normalized = str(path)
        if path.parts[0] not in ("SpeechDock.app", "release.json", "__MACOSX") or normalized in names:
            raise SystemExit("Unexpected or duplicate archive entry")
        names.add(normalized)
        mode = stat.S_IFMT(entry.external_attr >> 16)
        if mode not in (0, stat.S_IFREG, stat.S_IFDIR, stat.S_IFLNK):
            raise SystemExit("Archive contains a special file")
        if path.parts[0] == "SpeechDock.app":
            app_paths.append(normalized)
        if mode == stat.S_IFLNK:
            if path.parts[0] != "SpeechDock.app":
                raise SystemExit("Archive symlink outside app bundle")
            target = archive.read(entry).decode()
            resolved = posixpath.normpath(posixpath.join(str(path.parent), target))
            if target.startswith("/") or "\\" in target or not resolved.startswith("SpeechDock.app/"):
                raise SystemExit("Archive symlink leaves app bundle")
            links[normalized] = target

    # Resolve every path through the archive's entire symlink graph before
    # extraction. Individually safe relative links can combine to escape.
    for path in app_paths:
        pending = list(PurePosixPath(path).parts)
        resolved = []
        followed = set()
        while pending:
            part = pending.pop(0)
            if part == ".":
                continue
            if part == "..":
                if not resolved:
                    raise SystemExit("Archive symlink traverses outside app bundle")
                resolved.pop()
                continue
            resolved.append(part)
            current = "/".join(resolved)
            if current in links:
                if current in followed:
                    raise SystemExit("Archive contains a symlink cycle")
                followed.add(current)
                resolved.pop()
                pending = list(PurePosixPath(links[current]).parts) + pending
        if not resolved or resolved[0] != "SpeechDock.app":
            raise SystemExit("Archive path leaves app bundle through symlinks")
    metadata = json.loads(archive.read("release.json"))
    if metadata.get("version") != sys.argv[2] or metadata.get("commit") != sys.argv[3]:
        raise SystemExit("Artifact version or commit does not match this tag")
PY
ditto -x -k "$ARCHIVE" "$WORK_DIR/extracted"
APP="$PROJECT_DIR/build/SpeechDock.app"
rm -rf "$APP"
ditto "$WORK_DIR/extracted/SpeechDock.app" "$APP"
for EXECUTABLE in "$APP/Contents/MacOS/SpeechDock" "$APP/Contents/Resources/InputMethods/SpeechDockVoiceInput.app/Contents/MacOS/SpeechDockVoiceInput"; do
    ARCHS=$(lipo -archs "$EXECUTABLE")
    [[ " $ARCHS " == *" arm64 "* && " $ARCHS " == *" x86_64 "* ]] || {
        echo "Error: both apps must contain arm64 and x86_64." >&2; exit 1;
    }
done
python3 "$SCRIPT_DIR/sign-app.py" "$APP" --identity "$SIGNING_IDENTITY" --version "$VERSION"

bash "$SCRIPT_DIR/create-dmg.sh"
DMG="$PROJECT_DIR/SpeechDock-$VERSION.dmg"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
codesign --verify --strict "$DMG"
bash "$SCRIPT_DIR/notarize.sh"
spctl --assess --type execute --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
(cd "$PROJECT_DIR" && shasum -a 256 "SpeechDock-$VERSION.dmg") > "$PROJECT_DIR/build/SpeechDock-$VERSION.dmg.sha256"

if [ "$PUBLISH" = true ]; then
    # Do not let gh silently create a tag at the default branch or replace assets.
    [[ "$(gh api "repos/$REPOSITORY/commits/$TAG" --jq .sha)" = "$COMMIT" ]] || {
        echo "Error: the remote tag changed during notarization." >&2; exit 1;
    }
    gh release create "$TAG" "$DMG" "$PROJECT_DIR/build/SpeechDock-$VERSION.dmg.sha256" \
        --repo "$REPOSITORY" --verify-tag --title "SpeechDock $VERSION" --generate-notes
else
    echo "Ready: $DMG"
    echo "Use --publish to also upload the verified package to a new GitHub Release."
fi
