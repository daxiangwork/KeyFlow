#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/KeyFlow.app"

cd "$ROOT"
swift build -c release --product KeyFlow
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/KeyFlow" "$APP/Contents/MacOS/KeyFlow"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/Brand/AppIcon.png" "$APP/Contents/Resources/AppIcon.png"
cp "$ROOT/Resources/Images/"*.png "$APP/Contents/Resources/"
cp "$ROOT/Resources/ThirdPartyNotices.txt" "$APP/Contents/Resources/ThirdPartyNotices.txt"
if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    codesign --force --sign "$CODE_SIGN_IDENTITY" "$APP"
elif [[ "$(security find-identity -v -p codesigning)" == *"KeyFlow Local Development"* ]]; then
    codesign --force --sign "KeyFlow Local Development" "$APP"
else
    codesign --force --sign - "$APP"
fi
echo "$APP"
