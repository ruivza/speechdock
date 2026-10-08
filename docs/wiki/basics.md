# Getting Started

## Transcription

1. Open the transcription panel from the menu bar, then select an audio source, recognition language, and provider.
2. Grant microphone access for microphone recording, or screen and system audio recording access for system or application audio.
3. Start recording and stop when finished. Copy the result and paste it into your chosen app.

The floating microphone button also copies completed text. The main app runs in a sandbox. It does not use Accessibility to read or write other apps or simulate paste keystrokes.

## Voice Input

1. Choose the Voice Input installation command from the menu bar. Follow the folder selection prompt to install it in your user's Input Methods folder.
2. Log out and back in if prompted, then add SpeechDock Voice Input in the system's input source settings.
3. Place the cursor in a text field and switch to SpeechDock Voice Input.
4. Press Control + Option + R to start or finish recognition. Press Esc to cancel.

Voice Input uses native local recognition and submits text through InputMethodKit. Switching targets, moving the cursor, typing other text, or entering secure input cancels the current session so that results are not sent to the wrong location. Input method transcriptions are not saved in history.

Voice Input and the main app are separate applications. Confirm microphone and speech recognition permissions, as well as interface language settings, separately. Input method language changes usually require logging out and back in.

## Text to speech, OCR, and subtitles

Paste, type, or drop text into the text to speech panel, choose a voice, and play it. To save audio, select a destination when prompted. OCR captures a screen region you select and puts the recognized text into the panel for editing.

Live subtitles display transcription and can use your chosen translation provider. See [Privacy and Cache](advanced.md) for information about data sent to cloud providers.

## Settings and quitting

Appearance settings include interface language selection and cache cleanup. Transcription settings include a history saving option.

Choose Quit SpeechDock from the menu to exit completely. Closing a panel leaves the menu bar app running. During development, you can also stop the app in Xcode.

[Permissions](permissions.md) · [Home](index.md)

Source: [yohasebe/speechdock](https://github.com/yohasebe/speechdock). This page describes the current fork.
