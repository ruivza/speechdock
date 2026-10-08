# Contributing

This fork is maintained at [ruivza/speechdock](https://github.com/ruivza/speechdock) and is based on [yohasebe/speechdock](https://github.com/yohasebe/speechdock). The Apache License 2.0 and original copyright notices are retained.

## Local development

Use macOS 14 or later, Xcode 26 or later, and XcodeGen. All application targets share `Signing.xcconfig`, which optionally loads the Git-ignored `Signing.local.xcconfig`.

1. Copy `Signing.local.xcconfig.example` to `Signing.local.xcconfig` and replace the placeholder with your own Team ID.
2. Sign in to your Apple Account in Xcode and make sure your Mac has a matching Apple Development certificate and private key.
3. Run `xcodegen generate`, open the project, and select the SpeechDock scheme.
4. Debug builds use `SpeechDock Dev` and a separate bundle identifier. Their system permissions are stored separately from Release builds.

Keep real Team IDs, personal certificate names, private keys, API keys, and local machine paths out of shared configuration. Generated Xcode projects, certificate files, and local signing configuration must remain outside tracked files.

## Checks

```bash
xcodegen generate
xcodebuild test -project SpeechDock.xcodeproj -scheme SpeechDock -destination 'platform=macOS'
ruby scripts/lint/check_tracked_paths.rb
git diff --check
```

Tests can run with the command-line build settings `CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=`. For actual microphone recording or screen capture, use a stable development certificate. Automated tests do not replace manual validation of macOS permissions, input method installation, and cloud providers.

## Releases

The [Build and Release guide](https://github.com/ruivza/speechdock/wiki/Build-and-Release) covers Developer ID Application signing, notarization, and Sparkle update signatures. CI uses credentials from GitHub Secrets. Apple Account credentials must never be written into source. The Sparkle public key in the repository verifies updates and is safe to publish.

## Documentation and Wiki

Repository documentation lives in `docs/`. The published English user guide is available in the [Wiki](https://github.com/ruivza/speechdock/wiki). Keep documentation aligned with the current interface and permission behavior. Remove obsolete upstream instructions and link to the original repository when referring to historical behavior.

Wiki pages, the sidebar, and the footer should be in English. Inspect the language, links, and behavior described in generated content before publishing. To render a local preview:

```bash
python3 scripts/sync-wiki.py --preview /tmp/speechdock-wiki-preview
```

Publish reviewed English pages through the Wiki editor or a normal Git push. Preserve Wiki history so earlier versions can be recovered. Signing credentials and private transcription content must not appear in documentation.

## Code layout

- `App/`, `Views/`: application lifecycle, state, and SwiftUI views.
- `Services/`, `Models/`, `Utilities/`: audio, translation, storage, and shared logic.
- `InputMethod/`: the separate InputMethodKit voice input method.
- `Resources/`: permission configuration, assets, and localization for six languages.
- `Tests/`: regression tests, including cancellation, denial, and stale asynchronous results in permission flows.
- `scripts/`, `.github/workflows/`: builds, tracked path checks, notarization, and releases.
