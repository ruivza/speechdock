# SpeechDock User Guide

SpeechDock is a macOS menu bar app for transcription, text to speech, live subtitles, OCR, and translation. Both the main app and the Voice Input input method run in App Sandbox.

This guide covers the current [ruivza/speechdock](https://github.com/ruivza/speechdock) fork, based on [yohasebe/speechdock](https://github.com/yohasebe/speechdock). For documentation about earlier upstream versions, visit the original repository.

## Documentation

- [Getting started and Voice Input](basics.md)
- [System permissions and troubleshooting](permissions.md)
- [Privacy, transcription history, and cache](advanced.md)
- [Building, signing, and releasing](build-release.md)
- [AppleScript behavior](applescript.md)

## Installation

Download official packages from [this repository's Releases](https://github.com/ruivza/speechdock/releases). Release packages require the maintainer's Developer ID Application signature, notarization, and update signature. If no package is available, follow the [build guide](build-release.md) to build locally.

The upstream Homebrew tap and older upstream packages do not install this fork. Update checks use this repository's appcast. Until its first signed release, the feed has no installable update.

## Requirements and languages

SpeechDock requires macOS 14 or later. Development builds use Xcode 26 or later and XcodeGen. Native speech recognition depends on local support for the selected language and device. macOS may download missing language models. On macOS 14 and 15, languages without local recognition support are reported as unavailable.

Choose the interface language in Appearance settings, then quit and reopen the app. Available choices are System Default, Simplified Chinese, English, Japanese, German, French, and Korean. Interface, recognition, and translation languages are configured separately.

## Permissions

Microphone access is needed for recording. Screen and system audio recording access is needed for OCR and system or application audio capture. Reading text aloud does not require microphone access. Voice Input has its own permission records. See [Permissions](permissions.md) for details.

## License and source

SpeechDock retains the [Apache License 2.0](https://github.com/ruivza/speechdock/blob/main/LICENSE) and original copyright notices. The original project is [yohasebe/speechdock](https://github.com/yohasebe/speechdock), created by Yoichiro Hasebe. This fork is maintained by [ruivza](https://github.com/ruivza).
