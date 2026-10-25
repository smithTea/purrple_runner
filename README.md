# Purrple

A purple, offline music player for iOS. It plays your own MP3, FLAC, OGG (Vorbis/Opus), M4A, WAV and other files.

- **Add music:** tap **+** to import files or folders, or copy them into *Files › On My iPhone › Purrple*. The library rescans every time the app opens.
- **Playback:** [SFBAudioEngine](https://github.com/sbooth/SFBAudioEngine), with background audio, lock-screen and Control Center controls, and AirPlay.
- **UI:** SwiftUI with a dark theme. Spacing and sizes follow a familiar streaming-app layout, with a purple accent.

## Build
Every push to `main` builds an unsigned `.ipa` on GitHub's macOS runners (`.github/workflows/build.yml`). Download it from the run's artifacts and install it with SideStore.

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). On a Mac: `brew install xcodegen && xcodegen generate && open Purrple.xcodeproj`.
