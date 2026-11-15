#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "==> 1. Сборка бинарного файла для Apple Silicon (ARM64 Release)..."
swift build -c release --arch arm64

BIN_PATH="$PROJECT_DIR/.build/arm64-apple-macosx/release/StatePulse"
APP_DIR="$PROJECT_DIR/build/StatePulse.app"

echo "==> 2. Формирование бандла macOS (.app)..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/StatePulse"
chmod +x "$APP_DIR/Contents/MacOS/StatePulse"

cp "$PROJECT_DIR/Assets/Info.plist" "$APP_DIR/Contents/Info.plist"

if [ -f "$PROJECT_DIR/Assets/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

echo "==> 3. Подписание бандла (Ad-hoc codesign)..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> Сборка завершена успешно!"
echo "Готовое приложение: $APP_DIR"
