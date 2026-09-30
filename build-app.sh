#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/WorkPet" && pwd)"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)/build"
APP_NAME="WorkPet"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Building WorkPet..."
cd "$PROJECT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "==> Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 复制可执行文件
cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 复制 Info.plist (在 AppBundle 目录，不在 SPM Resources 里)
cp AppBundle/Info.plist "$APP_BUNDLE/Contents/Info.plist"

# 复制 source-rules.json
cp Sources/WorkPet/Resources/source-rules.json "$APP_BUNDLE/Contents/Resources/source-rules.json"

# 复制 SwiftPM 资源 bundle。WorkPet 的宠物包和 Bundle.module 资源在这里。
find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -type d -exec cp -R {} "$APP_BUNDLE/Contents/Resources/" \;

# 确保图片宠物包目录结构完整保留，避免 SwiftPM 资源缓存导致目录被拍平。
RESOURCE_BUNDLE="$APP_BUNDLE/Contents/Resources/WorkPet_WorkPet.bundle"
mkdir -p "$RESOURCE_BUNDLE"
rm -rf "$RESOURCE_BUNDLE/PetPacks"
cp -R Sources/WorkPet/Resources/PetPacks "$RESOURCE_BUNDLE/PetPacks"

SIGN_IDENTITY="${WORKPET_SIGN_IDENTITY:-}"
if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "==> Signing app bundle with $SIGN_IDENTITY..."
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
  echo "==> Signing app bundle with ad-hoc signature..."
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "==> App bundle created: $APP_BUNDLE"
echo "==> You can copy it to /Applications or double-click to run."
echo ""
echo "    open $APP_BUNDLE"
echo ""
echo "Note: On first launch, macOS may block the app."
echo "      Go to System Settings > Privacy & Security to allow it."
echo "      You also need to grant Calendar access and Full Disk Access"
echo "      for notification monitoring to work."
