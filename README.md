# A fork of the original Vimac

Maintained fork of [Vimac](https://github.com/dexterleng/vimac) by [kaiwen-wang](https://github.com/kaiwen-wang). Visit the [website](https://kaiwen-wang.github.io/vimac/), download releases from [GitHub Releases](https://github.com/kaiwen-wang/vimac/releases/latest), and get updates via Sparkle.

## Improvements in this fork

### Hint mode
- **Middle-click** support in hint mode
- **Click modifiers** remapped and documented (Shift = double-click, Option = middle-click, Command = right-click, Control = move without clicking)
- **Crash fix** when generating hints over web areas (e.g. browser content)
- **Faster quit** by limiting accessibility tree teardown on exit
- **Defaults**: launch at login on; hold-space hint activation off (less accidental activation)

### Scroll mode
- **Instant j/k reversal** — rapidly alternating scroll keys switches direction immediately, including overlapping key presses
- **Smoother scrolling** — higher-frequency ticks, sub-pixel accumulation, and trackpad-style scroll phases
- **Less Vim-like defaults** — scroll key directions swapped (e.g. j = up, k = down) to match macOS expectations

### Preferences & UX
- Click modifier controls use **native picker styling** and match other preference panes
- **Open Accessibility Settings** menu item for quicker permission setup
- Preference pane switching **without animation** flicker
- Key sequence activation defaults fixed; keyboard layout behavior documented in settings

### Distribution & development
- **Analytics removed**
- **Sparkle auto-updates** via GitHub-hosted appcast (migrated from App Center)
- **GitHub Actions** for CI and tagged releases (signed Sparkle feed, release notes)
- **Makefile** for build, run, deploy, and dependency setup
- **macOS 26 / Xcode compatibility** fixes (CoreGraphics import, pod deployment target)
- Unsigned **Debug builds** and improved local dev workflow

---


# Vimac - Productive macOS keyboard-driven navigation

Vimac is a macOS productivity application that provides keyboard-driven navigation and control of the macOS Graphical User Interface (GUI).

Vimac is heavily inspired by [Vimium](https://github.com/philc/vimium/).

## Getting Started

You can download Vimac from the [latest release](https://github.com/kaiwen-wang/vimac/releases/latest). Unzip the file and move `Vimac.app` to `Applications/`.

Visit the [website](https://kaiwen-wang.github.io/vimac/) or refer to the manual [here](https://github.com/kaiwen-wang/vimac/blob/master/docs/manual.md).

## How does Vimac work?

The current Vimac workflow works like this:

1. Activate a mode (`Hold Space to activate Hint-mode` is the default)
2. Perform actions within the activated mode
3. Exit the mode, either manually or automatically when the mode's task is complete

### Hint-mode

Activating Hint-mode allows one to perform a click, double-click, or right-click on an actionable UI element

Upon activation, "hints" will be generated for each actionable element on the frontmost window:

<img src="docs/hint-mode.gif">

Simply type the assigned "hint-text" (eg. "ka") to perform a click at the location!

### Scroll-mode

Activating Scroll-mode allows one to scroll through the scrollable areas of the frontmost window.

Upon activation, a red border surrounds the active scroll area:

<img src="docs/scroll-mode.gif">

HJKL keys can be used to scroll within the scroll area.

## Building

### Prerequisites

- **Xcode**: Install from the Mac App Store
- **Homebrew**: used for Carthage (`brew`)
- **Ruby ≥ 3**: required for CocoaPods (recommend a version manager like `mise`)
- **CocoaPods**: `pod`
- **Carthage**: `carthage`

### Setup

Recommended (Makefile will verify tools and guide you):

```
make setup
open Vimac.xcworkspace
```

Manual:

```
gem install cocoapods
brew install carthage
pod install
carthage build
open Vimac.xcworkspace
```

Notes:

- Avoid `sudo gem install ...` unless you intend to use the macOS system Ruby. If you use `mise`, make sure it’s activated in your shell so `ruby`/`gem` point to the mise Ruby.

Modify the Signing and Capabilities to the following (note the `Disable Library Validation` option):

![](docs/remove_signing.png)

Add Vimac and Xcode (for running AppleScript) to the list of Accessibility apps under **System Preferences > Security & Privacy > Accessibility**:

![](docs/vimac_xcode_accessibility.png)

Keep System Preferences open under this section during development with the settings unlocked. This is because the `grant-accessibility-permission-dev.scpt` AppleScript is scheduled to run after each build to re-grant Accessibility permissions.

The AppleScript simply checks and unchecks Vimac to re-grant permissions which are lost after a cleanbuild.

Build Vimac now! You may have to build it several times as the AppleScript may not run well the first time.

At this point running `git status` would bring up:

```
modified:   ViMac-Swift/ViMac_Swift.entitlements
modified:   Vimac.xcodeproj/project.pbxproj
modified:   grant-accessibility-permission-dev.scpt
```

Avoid committing them.

## CI and releases

GitHub Actions runs on every push and pull request to `master` / `main`:

- **CI** (`.github/workflows/ci.yml`) — installs CocoaPods/Carthage dependencies and runs `make ci-build`.

To publish a **GitHub Release** with Sparkle auto-updates:

1. Add the Sparkle EdDSA private key as the repository secret `SPARKLE_PRIVATE_KEY` (from `security find-generic-password -s "https://sparkle-project.org" -a ed25519 -w`).
2. Commit and push.
3. Create and push a version tag (this sets the marketing version, e.g. `v1.0.1` → `1.0.1`):

```bash
git tag v1.0.0
git push origin v1.0.0
```

The **Release** workflow (`.github/workflows/release.yml`) builds an unsigned Release `.app`, zips it, signs it for Sparkle, creates a GitHub Release, and commits an updated `appcast.xml` to `master` (served at the `SUFeedURL` in `Info.plist`). Builds are unsigned, so macOS Gatekeeper may require right-click → Open the first time.

For signed/notarized builds (App Store or distribution without Gatekeeper warnings), you need Apple Developer certificates configured as repository secrets; the local `make archive` target is set up for that path.

## Contributing

Feel free to contribute to Vimac. Make sure to open an issue / ask to work on something first!
