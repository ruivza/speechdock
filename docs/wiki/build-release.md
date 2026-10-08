# Build and Release

You can sign releases with your own certificate while keeping shared source configuration independent of an account. Signed packages contain public Team ID, certificate, and signature information. Current source configuration contains build rules, placeholders, and an update verification public key. Older upstream commits retain the original author's public signing settings.

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

## GitHub releases

Under this repository's Settings > Secrets and variables > Actions, configure these repository secrets:

| Secret | Value |
| --- | --- |
| `CERTIFICATE_BASE64` | Base64 of a .p12 containing the Developer ID Application certificate and private key |
| `CERTIFICATE_PASSWORD` | The .p12 export password |
| `KEYCHAIN_PASSWORD` | Password for the temporary CI Keychain |
| `TEAM_ID` | The Team ID matching the certificate |
| `APPLE_ID` | Apple Account used for notarization |
| `APP_PASSWORD` | That account's app-specific password |
| `SPARKLE_PRIVATE_KEY` | Update signing private key matching the app's `SUPublicEDKey` |

Never commit certificates, private keys, or passwords to Git or put them in issues, Wiki pages, chat, or build logs. Actions imports signing material into a temporary Keychain only for the release job. Xcode build commands do not inherit the secret environment variables, and the job cleans up signing material afterward.

Keep `VERSION` and the version settings for both application targets in `project.yml` aligned. After checking and committing the version changes, push the matching `vX.Y.Z` tag to trigger a release. For example:

```bash
rake version:patch
rake version:verify
# Commit the verified version changes and push main first.
git tag vX.Y.Z
git push origin vX.Y.Z
```

Replace X.Y.Z with the actual version. The workflow stops if secrets are missing, the certificate type or Team ID is wrong, the tag does not match the version, or signing or notarization fails. It pushes the signed appcast to main only after creating the Release. It does not update the upstream Homebrew tap.

## Sparkle update signing

Developer ID and Sparkle signatures serve different purposes. The repository includes a public `SUPublicEDKey`. Only its matching private key can sign updates accepted by the app. CI verifies the DMG update signature against the public key embedded in the app before publishing.

Manage update keys with official Sparkle tools from a verified version and SHA-256 download. Keep the private key in a local Keychain. To configure CI, the maintainer exports it outside the repository, sets `SPARKLE_PRIVATE_KEY`, and removes the exported file. A newly generated private key cannot sign updates for the existing public key; changing that key requires an update trust migration for existing users.

Reading a Keychain private key may require local authorization. Editing source and verifying public samples do not require private key access. The maintainer should perform key export on their own Mac.

## Wiki synchronization

The English Wiki is generated from `docs/wiki/`. Create the first Home page on GitHub to initialize the Wiki, then run:

```bash
python3 scripts/sync-wiki.py --preview /tmp/speechdock-wiki-preview
python3 scripts/sync-wiki.py --repository ruivza/speechdock
```

Synchronization replaces the Wiki's current pages with this English guide and retains upstream attribution. It preserves Git history and uses a normal push.

References: [GitHub macOS runner certificate setup](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications) and [Sparkle publishing guide](https://sparkle-project.org/documentation/).

[Home](index.md) · Source: [yohasebe/speechdock](https://github.com/yohasebe/speechdock)
