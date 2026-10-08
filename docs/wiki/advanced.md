# Privacy and Cache

## Local and cloud processing

Native macOS speech recognition requires local recognition support. On macOS 14 and 15, an unsupported language produces an error and does not automatically fall back to cloud recognition. Apple may need to download native language models, which are managed by macOS.

When you select cloud transcription, recordings or audio segments are sent to the chosen provider. Cloud text to speech sends the entered text to that provider. Cloud live translation repeatedly sends the accumulated transcript with recent context. Select a provider according to the data you want it to process.

## API keys

API keys are stored in macOS Keychain. Settings accept actual keys; 1Password references, CLI integration, and the related private APIs have been removed.

Build scripts use an allowlist of environment variables for Xcode commands to keep shell credentials out of build logs and DerivedData.

## Transcription history

The main app saves up to 50 recent transcripts by default. You can disable saving in settings and clear history from the history menu. Disabling saving stops new records and clears the in-memory list. Existing records on disk must be deleted with the clear action.

History is stored in the app sandbox's Application Support directory. The directory uses permissions `0700` and the file uses `0600`. The contents are plain-text JSON and are not encrypted. File permissions do not encrypt the contents. Voice Input does not save transcription history.

## Cache cleanup

- Temporary speech, transcription, and intermediate audio files are cleaned up as sessions end. Startup cleanup removes leftovers older than one hour.
- Temporary audio from failed speech synthesis is also cleaned up. Voice list caches expire after 24 hours.
- Clear Cache in Appearance settings clears voice lists, network caches, and idle speech audio held in memory. It is unavailable during playback or synthesis.
- Cache cleanup preserves history, API keys, audio you saved, and Apple language models. macOS manages model downloads.

Routine manual cleanup is usually unnecessary. If storage use seems excessive, stop playback and clear the cache, then manage language models through system settings. Deleting the entire sandbox directory can remove settings and history.

## Clipboard

Ordinary transcription copies text to the system clipboard. Clipboard contents may also be processed by the system and other clipboard tools. Use Voice Input to enter text directly without using the clipboard.

[Getting Started](basics.md) · [Home](index.md) · Source: [yohasebe/speechdock](https://github.com/yohasebe/speechdock)
