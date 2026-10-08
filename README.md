# SpeechDock

A macOS menu bar app for speech to text, text to speech, system and application audio capture, live subtitles, OCR, and translation.

This repository is an independently maintained fork of [yohasebe/speechdock](https://github.com/yohasebe/speechdock). This README describes the current fork. For documentation about earlier upstream versions, visit the original repository. The original license and copyright notices are retained.

## Downloads and documentation

- [Releases](https://github.com/ruivza/speechdock/releases): official packages will be available after signing and notarization.
- [English Wiki](https://github.com/ruivza/speechdock/wiki): the user guide for this fork.
- [Getting started](https://github.com/ruivza/speechdock/wiki/Getting-Started) · [Permissions](https://github.com/ruivza/speechdock/wiki/Permissions) · [Privacy and cache](https://github.com/ruivza/speechdock/wiki/Privacy-and-Cache)
- [Build and release](https://github.com/ruivza/speechdock/wiki/Build-and-Release) · [AppleScript](https://github.com/ruivza/speechdock/wiki/AppleScript)
- [Chinese documentation](docs/index.md) · [Japanese overview](README_ja.md)

Updates are installed manually from this repository's Releases. The app does not check for or download updates automatically. The upstream project's Homebrew commands do not install this fork.

## Features and current behavior

- Transcribe microphone, system, application, or file audio, with live subtitles.
- Use native macOS or optional cloud providers for speech recognition, text to speech, and translation.
- Both the main app and the separate Voice Input input method use App Sandbox and Hardened Runtime.
- Ordinary transcription copies text to the clipboard for manual pasting. Voice Input enters text directly through InputMethodKit.
- OCR recognizes a screen region you select and puts the text into the speech panel for editing.
- Choose System Default, Simplified Chinese, English, Japanese, German, French, or Korean for the interface. Language changes take effect after restarting.
- Keep up to 50 transcripts in local history, disable saving, or clear saved history. History is stored as plain text and is not encrypted.
- API keys are stored in macOS Keychain. 1Password integration and the related private APIs have been removed.
- Temporary audio is cleaned up automatically. Settings include cleanup for voice lists and network caches.

## Development

Requires macOS 14 or later, Xcode 26 or later, and XcodeGen. Native speech recognition depends on local language and device support. On macOS 14 and 15, unsupported languages produce an error without falling back to cloud recognition.

```bash
git clone https://github.com/ruivza/speechdock.git
cd speechdock
cp Signing.local.xcconfig.example Signing.local.xcconfig
# Set your own Team ID in this Git-ignored local file.
xcodegen generate
open SpeechDock.xcodeproj
```

Current shared configuration does not contain a developer's Team ID, personal certificate name, or private key. GitHub Actions builds an unsigned app; the maintainer signs, notarizes, and uploads the release from a local Mac. Developer ID private keys and notarization credentials stay in the local Keychain. See the [release guide](docs/wiki/build-release.md). Distributed packages contain the necessary public signing information. Older upstream commits retain the original author's public signing settings.

## License and source

[Apache License 2.0](LICENSE). The original project is [yohasebe/speechdock](https://github.com/yohasebe/speechdock), created by Yoichiro Hasebe. This fork is maintained by [ruivza](https://github.com/ruivza). The About page identifies both roles, and distributed apps include `LICENSE` and `NOTICE`.
