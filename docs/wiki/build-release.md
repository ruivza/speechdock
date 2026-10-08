# Build and Release

You can sign releases with your own certificate while keeping shared source configuration independent of an account. Signed packages contain public Team ID, certificate, and signature information. Current source configuration contains build rules and placeholders. Older upstream commits retain the original author's public signing settings.

## Local Debug builds

Install Xcode 26 or later and XcodeGen. Your Mac also needs an Apple Development certificate and its private key.

```bash
cp Signing.local.xcconfig.example Signing.local.xcconfig
# Replace YOUR_TEAM_ID in the local file with your own Team ID.
xcodegen generate
open SpeechDock.xcodeproj
```

Git ignores `Signing.local.xcconfig`. Every target optionally loads it through `Signing.xcconfig`. Generated Xcode projects are also excluded from Git. A stable development signature helps macOS retain permissions between builds. After changing the signature, grant permissions to the current app again.

## Local release builds

Install your Developer ID Application certificate and its private key. Apple Development certificates are for development and cannot replace Developer ID signing and notarization for distribution outside the Mac App Store.

```bash
TEAM_ID=YOUR_TEAM_ID SIGNING_IDENTITY='Developer ID Application' bash scripts/build.sh
bash scripts/create-dmg.sh
xcrun notarytool store-credentials speechdock-release
NOTARY_PROFILE=speechdock-release bash scripts/notarize.sh
```

The build script creates a universal arm64 and x86_64 Release and writes export settings into the ignored `build/` directory. Use `SIGNING_IDENTITY` to select a local certificate name or SHA-1 fingerprint without editing tracked source. Notarization credentials are read from a Keychain profile.

## Build on GitHub, sign and publish on your Mac

GitHub Actions builds a universal arm64 and x86_64 Release and stores an unsigned artifact. It does not create a Release. Developer ID private keys and notarization credentials remain in the maintainer's local Keychain. No Apple certificate, certificate password, or notarization secrets are needed on GitHub.

### One-time local setup

Install your Developer ID Application certificate with its private key and Xcode command-line tools. You do not need to export a .p12 or upload a certificate to GitHub.

```bash
brew install gh
gh auth login
xcrun notarytool store-credentials speechdock-release
```

The last command interactively saves your Apple Account, Team ID, and app-specific password in the Keychain. The release script reads the stored profile. Keep passwords out of commands, source, and GitHub.

The script automatically selects a certificate if exactly one valid Developer ID Application is available. For multiple certificates, inspect the public SHA-1 fingerprints with `security find-identity -v -p codesigning` and set `SIGNING_IDENTITY` to an exact certificate name or fingerprint.

DMGs are created with macOS `hdiutil` and `ditto` and contain the app and an Applications shortcut. GitHub's official `gh` is the only additional local release tool to install; packaging requires no third-party tools.

### Each release

This fork maintains its own version numbers independently of upstream. Use this repository's release notes and `vX.Y.Z` tags for new versions; preserve existing changelog history and never replace old tags.

1. Keep `VERSION` and both application targets in `project.yml` aligned. Commit and push the verified changes.
2. Push the matching `vX.Y.Z` tag to trigger **Build Release Artifact**, or run `rake release:github`. Existing tags are never replaced.
3. Wait for a successful run and copy RUN_ID from its `/actions/runs/` URL. Artifacts expire after 30 days and are intended for maintainer signing, not user installation.
4. Check out the tag locally and run the release script.

```bash
# Replace X.Y.Z and RUN_ID with the actual version and run number.
git fetch origin tag vX.Y.Z
git switch --detach vX.Y.Z
NOTARY_PROFILE=speechdock-release bash scripts/release-local.sh --run RUN_ID --publish
```

The script checks the remote tag, build commit, and local signing script revision, downloads the artifact, and restores executable modes and framework symlinks. It signs nested code, the Voice Input helper, and the main app separately with their own entitlements, then creates and signs a DMG, notarizes and staples it, and checks signatures and Gatekeeper. Only after all checks succeed does it upload the DMG and its SHA-256 checksum to a new Release. It does not overwrite releases or create missing tags.

Omit `--publish` to generate only a local package. The equivalent Rake command is `NOTARY_PROFILE=speechdock-release PUBLISH=1 rake 'release:local[RUN_ID]'`. Other forks can supply `--repo OWNER/REPO`.

The unsigned ZIP is in `build/SpeechDock-X.Y.Z-unsigned.zip`; the signed DMG is in the project root. Git ignores these outputs. Fully local builds still work using `scripts/build.sh`, as above; `bash scripts/build.sh --unsigned` exercises the certificate-free build path locally.

Users download and install updates manually from this fork's Releases. The app does not check for or download updates automatically, and releases do not update the upstream Homebrew tap.

## Wiki synchronization

The English Wiki is generated from `docs/wiki/`. Create the first Home page on GitHub to initialize the Wiki, then run:

```bash
python3 scripts/sync-wiki.py --preview /tmp/speechdock-wiki-preview
python3 scripts/sync-wiki.py --repository ruivza/speechdock
```

Synchronization replaces the Wiki's current pages with this English guide and retains upstream attribution. It preserves Git history and uses a normal push.

References: [Apple distribution signing](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac), [GitHub workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts), [GitHub CLI releases](https://cli.github.com/manual/gh_release_create).

[Home](index.md) · Source: [yohasebe/speechdock](https://github.com/yohasebe/speechdock)
