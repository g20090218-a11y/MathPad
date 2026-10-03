#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"

mkdir -p "$PROJECT_DIR/.cache/clang" "$PROJECT_DIR/.cache/swiftpm"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.cache/swiftpm"

# A fully installed Xcode is preferred. On machines with only Command Line
# Tools, fall back to the newest compatible SDK present on disk.
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi

swift build --disable-sandbox -c release -debug-info-format none --scratch-path .build-package
BIN_DIR="$(swift build --disable-sandbox -c release -debug-info-format none --scratch-path .build-package --show-bin-path)"
APP_DIR="$PROJECT_DIR/../MathPad.app"

if [[ "${MATHPAD_SKIP_SELF_TEST:-0}" != "1" ]]; then
    "$BIN_DIR/MathPad" --self-test
fi

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/MathPad" "$APP_DIR/Contents/MacOS/MathPad"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
chmod +x "$APP_DIR/Contents/MacOS/MathPad"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
