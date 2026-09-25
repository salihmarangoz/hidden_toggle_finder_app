# Hidden Toggle

A tiny macOS menu bar app that shows or hides hidden files in Finder with one click.

> [!WARNING]
> This project is completely vibecoded. It was written by AI and hasn't been carefully reviewed. Use it at your own risk.

## Features

- **Click** the eye icon in the menu bar to show or hide hidden files (dotfiles, `~/Library`, and so on).
- The icon shows the current state: an open eye means hidden files are visible, and a crossed-out eye means they're hidden.
- **Right-click** the icon for **Open at Login** and **Quit**.
- Starts automatically at login. It registers itself on first launch.
- No Dock icon and no windows.

Finder restarts after each toggle so it picks up the change. Its windows close and reopen.

## Requirements

- macOS 13 or later
- Xcode or the Xcode Command Line Tools (for `swiftc`)

## Install

```sh
git clone git@github.com:salihmarangoz/hidden_toggle_finder_app.git
cd hidden_toggle_finder_app
make install
```

This builds the app, copies it to `/Applications`, and launches it.

## Uninstall

1. Right-click the icon and uncheck **Open at Login**.
2. Run `make uninstall`.

## How it works

The whole app is [`main.swift`](main.swift). A click flips Finder's `AppleShowAllFiles` preference and relaunches Finder, which is equivalent to running:

```sh
defaults write com.apple.finder AppleShowAllFiles -bool true
killall Finder
```

Launch at login uses `SMAppService`.

## License

[MIT](LICENSE)
