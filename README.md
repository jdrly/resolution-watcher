# Resolution Watcher

Tiny macOS background app that switches the main display to 1920x1080 HiDPI when World of Warcraft launches, then restores 2560x1440 HiDPI when it exits.

It registers a bundled login-item helper with `SMAppService`, so macOS shows it as a normal Background Activity app instead of a legacy LaunchAgent.

## Requirements

- macOS
- [`displayplacer`](https://github.com/jakehilborn/displayplacer)
- ImageMagick for building the icon during install
- Xcode Command Line Tools for `swiftc` and `iconutil`

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
- `~/.config/resolution-watcher/config.zsh`

Background Activity should show `Resolution Watcher` with `1 item`.

## Config

`~/.config/resolution-watcher/config.zsh`:

```zsh
WATCHED_BUNDLE_ID="com.blizzard.worldofwarcraft"
PRELAUNCH_BUNDLE_IDS="net.battle.bootstrapper"
PRELAUNCH_TIMEOUT_SECONDS=180
GAME_MODE='id:YOUR_DISPLAY_ID res:1920x1080 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0'
WORK_MODE='id:YOUR_DISPLAY_ID res:2560x1440 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0'
```

## Uninstall

```zsh
./scripts/uninstall.zsh
```

## Signing

The installed app is local-only and ad-hoc signed. Developer ID signing and notarization are only needed for normal third-party distribution.
