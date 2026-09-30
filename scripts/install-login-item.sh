#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/build/WorkPet.app"
PLIST_PATH="$HOME/Library/LaunchAgents/dev.workpet.app.plist"

if [[ "${1:-}" == "uninstall" ]]; then
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"
  echo "WorkPet login item removed."
  exit 0
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "WorkPet.app not found, building first..."
  "$ROOT_DIR/build-app.sh"
fi

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>dev.workpet.app</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>$APP_BUNDLE</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/WorkPet.launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/WorkPet.launchd.err.log</string>
</dict>
</plist>
PLIST

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "WorkPet login item installed."
echo "Plist: $PLIST_PATH"
echo "App:   $APP_BUNDLE"

