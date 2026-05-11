# Resolution Watcher

Tiny macOS LaunchAgent app that switches the main display to 1920x1080 HiDPI when World of Warcraft launches, then restores 2560x1440 HiDPI when it exits.

It uses macOS Launch Services events through `lsappinfo`, so it does not poll process state in a loop.

## Requirements

- macOS
- [`displayplacer`](https://github.com/jakehilborn/displayplacer)
- ImageMagick for building the icon during install
- Xcode Command Line Tools for `Rez`, `SetFile`, and `iconutil`

## Install

Install dependencies:

```zsh
brew install displayplacer imagemagick
xcode-select --install
```

Find your display mode strings:

```zsh
displayplacer list
```

Create config:

```zsh
mkdir -p ~/.config/resolution-watcher
cp examples/config.example.zsh ~/.config/resolution-watcher/config.zsh
$EDITOR ~/.config/resolution-watcher/config.zsh
```

Install:

```zsh
./scripts/install.zsh
```

Runtime install paths:

- `~/Applications/Resolution Watcher.app`
- `~/Library/LaunchAgents/dev.local.resolution-watcher.plist`
- `~/.config/resolution-watcher/config.zsh`

## Config

`~/.config/resolution-watcher/config.zsh`:

```zsh
WATCHED_BUNDLE_ID="com.blizzard.worldofwarcraft"
GAME_MODE='id:YOUR_DISPLAY_ID res:1920x1080 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0'
WORK_MODE='id:YOUR_DISPLAY_ID res:2560x1440 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0'
```

## Uninstall

```zsh
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/dev.local.resolution-watcher.plist
rm -f ~/Library/LaunchAgents/dev.local.resolution-watcher.plist
rm -rf ~/Applications/Resolution\ Watcher.app
```

## Signing

The installed app is local-only and unsigned. macOS may show it as an unidentified developer. Removing that warning requires Apple Developer ID signing and notarization.
