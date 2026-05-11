#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="${RESOLUTION_WATCHER_APP:-$HOME/Applications/Resolution Watcher.app}"
PLIST="$HOME/Library/LaunchAgents/dev.local.resolution-watcher.plist"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/resolution-watcher"
CONFIG_FILE="${RESOLUTION_WATCHER_CONFIG:-$CONFIG_DIR/config.zsh}"
ICONSET="$APP/Contents/Resources/Icon.iconset"
ICON_RSRC="/tmp/ResolutionWatcherIcon.rsrc"
ICON_STAMP="/tmp/ResolutionWatcherIcon.png"

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs" "$CONFIG_DIR"

cp "$ROOT/src/Resolution Watcher" "$APP/Contents/MacOS/Resolution Watcher"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/assets/ResolutionWatcher.svg" "$APP/Contents/Resources/ResolutionWatcher.svg"
sed \
  -e "s#__APP_EXECUTABLE__#$APP/Contents/MacOS/Resolution Watcher#g" \
  -e "s#__HOME__#$HOME#g" \
  "$ROOT/launchd/dev.local.resolution-watcher.plist.template" > "$PLIST"
chmod +x "$APP/Contents/MacOS/Resolution Watcher"

if [[ -n "${GAME_MODE:-}" || -n "${WORK_MODE:-}" || -n "${WATCHED_BUNDLE_ID:-}" ]]; then
  {
    print "WATCHED_BUNDLE_ID=${(qq)${WATCHED_BUNDLE_ID:-com.blizzard.worldofwarcraft}}"
    print "GAME_MODE=${(qq)${GAME_MODE:-}}"
    print "WORK_MODE=${(qq)${WORK_MODE:-}}"
  } > "$CONFIG_FILE"
elif [[ ! -f "$CONFIG_FILE" ]]; then
  cp "$ROOT/examples/config.example.zsh" "$CONFIG_DIR/config.example.zsh"
  print "Missing config: $CONFIG_FILE"
  print "Created example: $CONFIG_DIR/config.example.zsh"
  print "Copy it to config.zsh, fill displayplacer modes, then rerun install."
  exit 1
fi

for spec in '16 icon_16x16.png' '32 icon_16x16@2x.png' '32 icon_32x32.png' '64 icon_32x32@2x.png' '128 icon_128x128.png' '256 icon_128x128@2x.png' '256 icon_256x256.png' '512 icon_256x256@2x.png' '512 icon_512x512.png' '1024 icon_512x512@2x.png'; do
  size=${spec%% *}
  file=${spec#* }
  magick "$APP/Contents/Resources/ResolutionWatcher.svg" -background none -resize "${size}x${size}" "$ICONSET/$file"
done

iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/ResolutionWatcher.icns"

cp "$ICONSET/icon_512x512@2x.png" "$ICON_STAMP"
sips -i "$ICON_STAMP" >/dev/null
DeRez -only icns "$ICON_STAMP" > "$ICON_RSRC"
Rez -append "$ICON_RSRC" -o "$APP/Contents/MacOS/Resolution Watcher"
SetFile -a C "$APP/Contents/MacOS/Resolution Watcher"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

plutil -lint "$APP/Contents/Info.plist" "$PLIST"
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/dev.local.resolution-watcher"
