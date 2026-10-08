# AppleScript

The command definitions in [SpeechDock.sdef](https://github.com/ruivza/speechdock/blob/main/Resources/SpeechDock.sdef) are the reference for supported commands. AppleScript can control speech playback, file transcription, translation, and panels. Each operation still requires the appropriate provider settings and user permissions.

```applescript
tell application "SpeechDock"
    speak text "Hello from SpeechDock"
end tell
```

Use the current app name, `SpeechDock Dev`, when addressing a development build. macOS manages Automation permissions for applications that send commands to SpeechDock.

## Clipboard commands

`copy to clipboard` copies the supplied text. The retained `paste text` command also only copies to the clipboard and returns the copy status. It does not select a target app, simulate keystrokes, or paste into another application. Paste manually or use Voice Input to enter text in an editor.

## Files and panels

AppleScript does not bypass the sandbox's file access restrictions. File transcription and audio saving require a file the running app can access or a destination selected by the user.

Recording behavior when showing, hiding, or switching panels follows the current command implementation. A caller should not assume that hiding a panel completes a transcription.

Earlier instructions about automatic pasting and Accessibility do not describe this fork. For upstream historical behavior, see [yohasebe/speechdock](https://github.com/yohasebe/speechdock).

[Home](index.md) · [Getting Started](basics.md)
