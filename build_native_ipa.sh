#!/usr/bin/env bash
# 在 macOS + Xcode 上一键编译「纯 SwiftUI 原生」DaysNote IPA（含 WidgetKit 系统小组件）
# 这是真正的原生 App，不依赖 WebView / WKWebView / 任何 Web 界面。
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
OUT="${1:-$ROOT/DaysNote-native-unsigned.ipa}"
TEAM="${TEAM_ID:-}"
DEV_TEAM="${DEVELOPMENT_TEAM:-}"

echo "==> 1/5 检查环境"
xcodebuild -version

echo "==> 2/5 列出 scheme"
xcodebuild -list -project DaysNote.xcodeproj

echo "==> 3/5 编译（未签名，arm64 真机）"
DERIVED="$ROOT/.native-build"
rm -rf "$DERIVED"
BUILD_ARGS=(
  -project DaysNote.xcodeproj
  -scheme DaysNote
  -configuration Release
  -sdk iphoneos
  -derivedDataPath "$DERIVED"
  -archivePath "$ROOT/DaysNote.xcarchive"
  CODE_SIGNING_ALLOWED=NO
)
if [ -n "$DEV_TEAM" ]; then BUILD_ARGS+=("DEVELOPMENT_TEAM=$DEV_TEAM"); fi
xcodebuild archive "${BUILD_ARGS[@]}"

echo "==> 4/5 导出未签名 IPA"
APP="$ROOT/DaysNote.xcarchive/Products/Applications/DaysNote.app"
IPA_ROOT="$ROOT/.ipa-stage/Payload"
rm -rf "$ROOT/.ipa-stage"
mkdir -p "$IPA_ROOT"
cp -R "$APP" "$IPA_ROOT/DaysNote.app"
# 移除签名（未签名包，需用户自行重签）
rm -rf "$IPA_ROOT/DaysNote.app/_CodeSignature" "$IPA_ROOT/DaysNote.app/embedded.mobileprovision"
find "$IPA_ROOT/DaysNote.app/PlugIns" -type d -name _CodeSignature -exec rm -rf {} + 2>/dev/null || true
(cd "$ROOT/.ipa-stage" && zip -qry "$OUT" Payload)

echo "==> 5/5 校验"
ls -lh "$OUT"
unzip -l "$OUT" | grep -E "DaysNote.app/DaysNote$|PlugIns/DaysNoteWidget.appex" | head -5
echo "完成：$OUT"
