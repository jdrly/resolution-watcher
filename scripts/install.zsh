#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="${RESOLUTION_WATCHER_APP:-$HOME/Applications/Resolution Watcher.app}"
CONTENTS="$APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
LOGIN_ITEMS_DIR="$CONTENTS/Library/LoginItems"
APP_EXECUTABLE="$MACOS_DIR/Resolution Watcher"
HELPER_APP="$LOGIN_ITEMS_DIR/Resolution Watcher Helper.app"
HELPER_CONTENTS="$HELPER_APP/Contents"
HELPER_MACOS_DIR="$HELPER_CONTENTS/MacOS"
HELPER_RESOURCES_DIR="$HELPER_CONTENTS/Resources"
HELPER_EXECUTABLE="$HELPER_MACOS_DIR/Resolution Watcher Helper"
HELPER_LABEL="com.jd.resolution-watcher.helper"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/resolution-watcher"
CONFIG_FILE="${RESOLUTION_WATCHER_CONFIG:-$CONFIG_DIR/config.zsh}"
ICONSET="$RESOURCES_DIR/ResolutionWatcher.iconset"
BUILD_VERSION="$(date +%Y%m%d%H%M%S)"
LEGACY_PLISTS=(
  "$HOME/Library/LaunchAgents/com.jd.resolution-watcher.plist"
  "$HOME/Library/LaunchAgents/dev.local.resolution-watcher.plist"
)

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    print -u2 "Missing required command: $1"
    exit 1
  fi
}

remove_legacy_launchagents() {
  for plist in "${LEGACY_PLISTS[@]}"; do
    launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
    rm -f "$plist"
  done
}

remove_app_xattrs() {
  xattr -dr com.apple.provenance "$APP" 2>/dev/null || true
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
}

helper_launch_state() {
  launchctl print "gui/$(id -u)/$HELPER_LABEL" 2>/dev/null || true
}

wait_for_helper_outcome() {
  local state

  for _ in {1..20}; do
    state="$(helper_launch_state)"
    if print -r -- "$state" | grep -q "job state = running"; then
      return 0
    fi
    sleep 1
  done

  return 1
}

render_icon() {
  local filename="$1"
  local size="$2"

  magick "$ROOT/assets/ResolutionWatcher.svg" -background none -resize "${size}x${size}" "$ICONSET/$filename"
}

require_command swiftc
require_command magick
require_command iconutil
require_command codesign
require_command plutil

mkdir -p "$CONFIG_DIR" "$HOME/Library/Logs"

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

remove_legacy_launchagents
pkill -f "$APP/Contents/Library/LoginItems/Resolution Watcher Helper.app/Contents/MacOS/Resolution Watcher Helper" 2>/dev/null || true

rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$HELPER_MACOS_DIR" "$HELPER_RESOURCES_DIR" "$ICONSET"

MACOSX_DEPLOYMENT_TARGET=13.0 swiftc \
  "$ROOT/macos/Sources/ResolutionWatcherApp"/*.swift \
  -o "$APP_EXECUTABLE" \
  -framework AppKit \
  -framework ServiceManagement

MACOSX_DEPLOYMENT_TARGET=13.0 swiftc \
  "$ROOT/macos/Sources/ResolutionWatcherHelper"/*.swift \
  -o "$HELPER_EXECUTABLE" \
  -framework AppKit

sed "s#__BUNDLE_VERSION__#$BUILD_VERSION#g" \
  "$ROOT/macos/plists/ResolutionWatcher.Info.plist" > "$CONTENTS/Info.plist"
sed "s#__BUNDLE_VERSION__#$BUILD_VERSION#g" \
  "$ROOT/macos/plists/ResolutionWatcherHelper.Info.plist" > "$HELPER_CONTENTS/Info.plist"
cp "$ROOT/assets/ResolutionWatcher.svg" "$RESOURCES_DIR/ResolutionWatcher.svg"
cp "$ROOT/assets/ResolutionWatcher.svg" "$HELPER_RESOURCES_DIR/ResolutionWatcher.svg"

render_icon "icon_16x16.png" 16
render_icon "icon_16x16@2x.png" 32
render_icon "icon_32x32.png" 32
render_icon "icon_32x32@2x.png" 64
render_icon "icon_128x128.png" 128
render_icon "icon_128x128@2x.png" 256
render_icon "icon_256x256.png" 256
render_icon "icon_256x256@2x.png" 512
render_icon "icon_512x512.png" 512
render_icon "icon_512x512@2x.png" 1024
iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/ResolutionWatcher.icns"
cp "$RESOURCES_DIR/ResolutionWatcher.icns" "$HELPER_RESOURCES_DIR/ResolutionWatcher.icns"
rm -rf "$ICONSET"

plutil -lint "$CONTENTS/Info.plist" "$HELPER_CONTENTS/Info.plist"
codesign --force --sign - "$HELPER_APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
sleep 5
remove_app_xattrs
"$APP_EXECUTABLE" --install-helper

if ! wait_for_helper_outcome; then
  sleep 3
  remove_app_xattrs
  "$APP_EXECUTABLE" --install-helper
fi

if ! wait_for_helper_outcome; then
  sleep 3
  remove_app_xattrs
  "$APP_EXECUTABLE" --install-helper
fi

if ! wait_for_helper_outcome; then
  print -u2 "Resolution Watcher Helper did not start."
  helper_launch_state >&2
  exit 1
fi

print "$APP"
