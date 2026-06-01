#!/bin/bash
set -e

PROJECT="MyTV.xcodeproj"
SCHEME="MyTV"
CONFIG="Release"
BUILD_DIR="build"
APP_NAME="MyTV"

cd "$(dirname "$0")/.."

if [ -f ".env.local" ]; then
    set -a
    . ".env.local"
    set +a
fi

if [ -z "${TRAKT_CLIENT_ID:-}" ]; then
    echo "错误: 请先设置 TRAKT_CLIENT_ID 环境变量"
    echo "示例: TRAKT_CLIENT_ID=your_client_id bash scripts/build.sh"
    echo "也可以在 .env.local 中配置 TRAKT_CLIENT_ID=your_client_id"
    exit 1
fi

echo "=== 生成 Xcode 项目 ==="
if ! command -v xcodegen &> /dev/null; then
    echo "xcodegen 未安装，正在安装..."
    brew install xcodegen
fi
xcodegen generate

echo "=== 清理旧构建 ==="
rm -rf "$BUILD_DIR"

echo "=== 构建 Release 版本 ==="
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'platform=macOS' \
    TRAKT_CLIENT_ID="$TRAKT_CLIENT_ID" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME-macOS.dmg"
ZIP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME-macOS.zip"

echo "=== 创建 DMG ==="
rm -f "$DMG_PATH"
DMG_STAGING=$(mktemp -d)
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"
echo "DMG: $DMG_PATH"

echo "=== 创建 ZIP ==="
cd "$BUILD_DIR/Build/Products/Release"
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$APP_NAME-macOS.zip"
echo "ZIP: $ZIP_PATH"

echo ""
echo "=== 构建完成 ==="
echo "App: $APP_PATH"
echo "DMG: $DMG_PATH"
echo "ZIP: $ZIP_PATH"
echo ""
echo "直接运行: open $APP_PATH"
echo "安装: 双击 DMG 拖入 Applications 文件夹"
