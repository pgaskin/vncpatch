# vncpatch
Patches the RealVNC 4.x Android app to fix bugs and improve usability.

Currently supports VNC Viewer 4.9.1.60165 (May 2024).

For VNC Viewer 3.x, see [here](https://gist.github.com/pgaskin/fe3bd93d851f5ac63e40f9fb9cdf264a) for a patch to fix the double-backspace bug.

## Features

- Renamed package so it can be installed alongside the official one.
- Fix bug where taps are frequently ignored on certain devices (e.g., Pixel 9).
- Fix bug where rapidly pressing non-lockable-modifier extension keyboard keys would only send half the expected number of key presses (also so pressing arrow keys isn't as painful).
- Add long-press key-repeat support to the extension keyboard (so pressing arrow keys isn't as painful).
- Add a pin-to-home button to the connection details toolbar (since the dynamic shortcuts only includes the first four connections).
- Replace annoying floating toolbar with invisible touch regions (top-left corner is disconnect, top is connection info, bottom is keyboard, bottom-right corner is mouse).
- Dark theme.

## Usage

1. Install dependencies:
    - git
    - Java 11+
    - [zipalign](https://developer.android.com/tools/releases/build-tools)
    - [apksigner](https://developer.android.com/tools/releases/build-tools) (>= 0.9) (this repo contains a vendored copy)
    - [apktool](https://github.com/iBotPeaches/Apktool/releases) (= 2.8.1) (newer versions will probably work, but the patches may need to be updated) (this repo contains a vendored copy)
    - wget (only needed if downloading the APK)
2. Run `./vncpatch.sh` (see `./vncpatch.sh -h` for options). To modify the patches, you can amend or add new commits to the git repo created at `./src`, then run `./vncpatch.sh` again.
3. Uninstall the original app, then install `build/signed.apk`.
