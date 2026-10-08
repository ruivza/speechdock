# Permissions

| Feature | Required permission |
| --- | --- |
| Microphone transcription | Microphone access for the main app |
| OCR, system audio, and application audio | Screen and system audio recording access for the main app |
| Voice Input | Separate microphone and native speech recognition permissions for the input method |
| Reading entered text aloud | No microphone or screen recording permission |

The main app does not require Accessibility permission. App Sandbox and Hardened Runtime define the app's security boundaries; users still grant macOS privacy permissions separately.

## Permission is enabled but the app still asks

macOS associates permissions with an application's signing identity. Older versions, Debug builds, builds signed with a different certificate, or earlier builds with temporary signatures may leave mismatched records. Debug uses `com.speechdock.app.dev`; Release uses `com.speechdock.app`. They have separate permissions.

1. On the app's permissions page, choose Show This App in Finder to locate the running application bundle.
2. Choose Quit SpeechDock from the menu. During development, stop the app in Xcode.
3. In System Settings > Privacy & Security > Screen & System Audio Recording, remove the old SpeechDock entry, add the current app you located, and enable access.
4. Reopen that app, choose Check Again on its permissions page, and try the feature again.

Only update the mismatched SpeechDock entry. There is no need to reset permissions for every app. Permissions granted to the main app do not automatically apply to Voice Input.

## Permission checks

Microphone status is refreshed through AVFoundation. ScreenCaptureKit validates access for the current session when you explicitly recheck or use a capture feature. An older preflight result does not independently block capture. Canceled or outdated asynchronous checks cannot overwrite newer results.

If restarting or updating the app entry does not resolve the issue, report the running version, whether you are using the main app or Voice Input, the feature involved, and the error message. Regression tests cover state transitions, but cannot guarantee that a particular Mac's permission records are valid.

References: [Apple screen recording permissions](https://support.apple.com/guide/mac-help/mchld6aa7d23/mac) and [Apple discussion of signing changes and permissions](https://developer.apple.com/forums/thread/819406).

[Home](index.md) · Source: [yohasebe/speechdock](https://github.com/yohasebe/speechdock)
