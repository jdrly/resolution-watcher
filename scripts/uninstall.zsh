#!/bin/zsh
set -euo pipefail

APP="${RESOLUTION_WATCHER_APP:-$HOME/Applications/Resolution Watcher.app}"
APP_EXECUTABLE="$APP/Contents/MacOS/Resolution Watcher"
LEGACY_PLISTS=(
  "$HOME/Library/LaunchAgents/com.jd.resolution-watcher.plist"
  "$HOME/Library/LaunchAgents/dev.local.resolution-watcher.plist"
)

if [[ -x "$APP_EXECUTABLE" ]]; then
  "$APP_EXECUTABLE" --uninstall-helper 2>/dev/null || true
fi

for plist in "${LEGACY_PLISTS[@]}"; do
  launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
  rm -f "$plist"
done

pkill -f "$APP/Contents/Library/LoginItems/Resolution Watcher Helper.app/Contents/MacOS/Resolution Watcher Helper" 2>/dev/null || true
rm -rf "$APP"

print "Removed Resolution Watcher"
