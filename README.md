<img src="icon/icon.png" width="128" alt="Hidden Toggle icon">

# Hidden Toggle

[![Build](https://github.com/salihmarangoz/hidden_toggle_finder_app/actions/workflows/build.yml/badge.svg)](https://github.com/salihmarangoz/hidden_toggle_finder_app/actions/workflows/build.yml)

A tiny macOS menu bar app that shows or hides hidden files in Finder with one click.

> [!WARNING]
> This project is completely vibecoded. It was written by AI and hasn't been carefully reviewed. Use it at your own risk.

## Features

- **Click** the eye icon in the menu bar to show or hide hidden files (dotfiles, `~/Library`, and so on).
- The icon shows the current state: an open eye means hidden files are visible, and a crossed-out eye means they're hidden.
- **Right-click** the icon for options:
  - **Toggle Without Restarting Finder** (on by default). Hidden files switch instantly. Needs Accessibility permission.
  - **Open at Login**
  - **Quit**
- Starts automatically at login. It registers itself on first launch.
- No Dock icon and no windows.

With **Toggle Without Restarting Finder** turned off, Finder restarts after each toggle so it picks up the change. Its windows close and reopen.

## Install

Requires macOS 13 or later. The app runs on both Apple Silicon and Intel Macs.

1. Download `HiddenToggle.zip` from the [latest release](https://github.com/salihmarangoz/hidden_toggle_finder_app/releases/latest) and unzip it.
2. Move `HiddenToggle.app` to your **Applications** folder.
3. The app isn't signed with an Apple Developer ID, so macOS blocks it on first open. Unblock it in one of two ways:
   - **Terminal:** run `xattr -dr com.apple.quarantine /Applications/HiddenToggle.app`, then open the app.
   - **System Settings:** open the app and click **Done** on the warning. Then go to System Settings → Privacy & Security, scroll down, click **Open Anyway** next to the HiddenToggle message, and confirm.
4. Click the eye icon in the menu bar. macOS asks for Accessibility permission. Turn on **HiddenToggle** in System Settings → Privacy & Security → Accessibility, then quit and reopen the app.

### Updating

Quit the app, replace it in Applications, and repeat step 3. Each new version is a different unsigned build, so macOS also forgets the Accessibility permission. Remove the old **HiddenToggle** entry from the Accessibility list, then allow the new one.

### Build from source

Requires Xcode or the Xcode Command Line Tools.

```sh
git clone https://github.com/salihmarangoz/hidden_toggle_finder_app.git
cd hidden_toggle_finder_app
make install
```

This builds the app, copies it to `/Applications`, and launches it. Apps you build yourself aren't blocked by macOS, so skip step 3. Step 4 applies after every rebuild.

To publish a release, push a tag like `v1.0.0`. GitHub Actions builds the app and attaches `HiddenToggle.zip` to a new release.

## Uninstall

1. Right-click the icon and uncheck **Open at Login**.
2. Run `make uninstall`.
3. Remove **HiddenToggle** from the Accessibility list in System Settings.

## How it works

The whole app is [`main.swift`](main.swift). It has two ways to toggle hidden files.

**Without restarting Finder (default):** the app brings Finder to the front and presses Finder's own ⌘⇧. shortcut. Some keyboard layouts break that shortcut. On Turkish Q, for example, macOS remaps ⌘⇧. to "make icons bigger". So the app switches to the built-in ABC layout for about half a second while it presses the shortcut, then switches back. The ABC layout is turned on only for that moment. The app also saves Finder's `AppleShowAllFiles` setting, so the state survives Finder restarts. Then it returns you to the app you were using.

**Restarting Finder:** the app flips the `AppleShowAllFiles` setting and relaunches Finder, which is equivalent to running:

```sh
defaults write com.apple.finder AppleShowAllFiles -bool true
killall Finder
```

Launch at login uses `SMAppService`.

## License

[MIT](LICENSE)
