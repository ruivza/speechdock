#!/usr/bin/env python3
"""Sign the CI app inside out, using entitlements from the local checkout."""

import argparse
import plistlib
import shlex
import subprocess
import tempfile
from pathlib import Path


MACH_O = {
    bytes.fromhex(magic)
    for magic in ("feedface", "cefaedfe", "feedfacf", "cffaedfe",
                  "cafebabe", "bebafeca", "cafebabf", "bfbafeca")
}


def bundle_info(bundle):
    for location in ("Contents/Info.plist", "Resources/Info.plist", "Info.plist"):
        path = bundle / location
        if path.is_file():
            return plistlib.loads(path.read_bytes())
    raise ValueError(f"Missing Info.plist: {bundle}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--identity", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    app = args.app.resolve()
    project = Path(__file__).resolve().parent.parent
    helper = app / "Contents/Resources/InputMethods/SpeechDockVoiceInput.app"
    applications = {
        app: ("com.speechdock.app", project / "Resources/SpeechDock.entitlements"),
        helper: ("com.speechdock.inputmethod.voice", project / "InputMethod/VoiceInput.entitlements"),
    }
    bundles = set(applications)
    executables = set()
    files = list(app.rglob("*"))

    # Framework symlinks are expected; none may point outside this app.
    for path in files:
        if not path.resolve().is_relative_to(app):
            raise ValueError(f"Path leaves app bundle: {path}")
        if path.is_symlink():
            continue
        if path.is_dir() and path.suffix in (".app", ".appex", ".xpc") and path not in applications:
            raise ValueError(f"No entitlement policy for nested executable bundle: {path}")
        if path.is_dir() and path.suffix in (".framework", ".bundle"):
            # Resource-only bundles need no code signature.
            try:
                info = bundle_info(path)
            except ValueError:
                if path.suffix == ".framework":
                    raise
                continue
            if info.get("CFBundleExecutable"):
                bundles.add(path)

    for bundle in bundles:
        info = bundle_info(bundle)
        name = info.get("CFBundleExecutable", "")
        if not name or Path(name).name != name:
            raise ValueError(f"Invalid bundle executable: {bundle}")
        executable = bundle / ("Contents/MacOS" if (bundle / "Contents").is_dir() else "") / name
        if not executable.is_file() or not executable.resolve().is_relative_to(app):
            raise ValueError(f"Missing bundle executable: {executable}")
        executables.add(executable.resolve())
        if bundle in applications:
            identifier, _ = applications[bundle]
            if info.get("CFBundleIdentifier") != identifier:
                raise ValueError(f"Unexpected bundle identifier: {bundle}")
            if any(info.get(key) != args.version for key in ("CFBundleShortVersionString", "CFBundleVersion")):
                raise ValueError(f"App version does not match {args.version}: {bundle}")

    # Sign loose libraries first; enclosing frameworks and apps follow at their
    # depth. Never use --deep for signing: each app has its own entitlements.
    loose_code = set()
    for path in files:
        if path.is_file() and not path.is_symlink() and path.resolve() not in executables:
            with path.open("rb") as stream:
                if stream.read(4) in MACH_O:
                    loose_code.add(path)
    plan = sorted(bundles | loose_code, key=lambda path: (-len(path.parts), str(path)))
    with tempfile.TemporaryDirectory(prefix="speechdock-entitlements-") as temporary:
        for path in plan:
            command = ["codesign", "--force", "--sign", args.identity, "--timestamp", "--options", "runtime"]
            if path in applications:
                identifier, source = applications[path]
                entitlements = plistlib.loads(source.read_text().replace("$(PRODUCT_BUNDLE_IDENTIFIER)", identifier).encode())
                if entitlements.get("com.apple.security.get-task-allow"):
                    raise ValueError("Release entitlements must not enable get-task-allow")
                destination = Path(temporary) / f"{identifier}.plist"
                destination.write_bytes(plistlib.dumps(entitlements))
                command += ["--entitlements", str(destination), "--generate-entitlement-der"]
            command.append(str(path))
            print(shlex.join(command), flush=True)
            if not args.dry_run:
                subprocess.run(command, check=True)
        if not args.dry_run:
            for bundle in (helper, app):
                subprocess.run(["codesign", "--verify", "--deep", "--strict", str(bundle)], check=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
