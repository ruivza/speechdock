#!/bin/bash
set -euo pipefail

# CI bootstrap: send the existing app password to notarytool's secure prompt,
# keeping it out of both argv and the child environment. No third-party modules.
python3 - <<'PY'
import os
import pty
import select
import subprocess
import termios
import time

required = ("NOTARY_PROFILE", "APPLE_ID", "TEAM_ID", "APP_PASSWORD")
if any(not os.environ.get(name) for name in required):
    raise SystemExit("Missing notary profile credentials")
password = os.environ.pop("APP_PASSWORD")
if "\n" in password or "\r" in password:
    raise SystemExit("Invalid notary password")
args = ["xcrun", "notarytool", "store-credentials", os.environ["NOTARY_PROFILE"],
        "--apple-id", os.environ["APPLE_ID"], "--team-id", os.environ["TEAM_ID"],
        "--no-validate"]
if os.environ.get("NOTARY_KEYCHAIN"):
    args += ["--keychain", os.environ["NOTARY_KEYCHAIN"]]
master, slave = pty.openpty()
attributes = termios.tcgetattr(slave)
attributes[3] &= ~(termios.ECHO | termios.ECHONL)
termios.tcsetattr(slave, termios.TCSANOW, attributes)
process = subprocess.Popen(args, stdin=slave, stdout=slave, stderr=slave)
os.close(slave)
deadline = time.monotonic() + 30
output = b""
sent = False
try:
    while process.poll() is None and time.monotonic() < deadline:
        if not select.select([master], [], [], 0.25)[0]:
            continue
        try:
            chunk = os.read(master, 4096)
        except OSError:
            break
        if not chunk:
            break
        output = (output + chunk)[-8192:]
        if not sent and b"password" in output.lower():
            os.write(master, (password + "\n").encode())
            sent = True
    if process.poll() is None:
        try:
            process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    if process.returncode != 0 or not sent:
        raise SystemExit("Could not create notary Keychain profile")
finally:
    os.close(master)
PY
