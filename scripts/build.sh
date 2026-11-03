#!/bin/zsh
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$project_dir/scripts/check_copy.py"
app_dir="$project_dir/build/Build/Products/Release/Yuya.app"
# Remove the obsolete generated icon when incrementally rebuilding an older bundle.
rm -f "$app_dir/Contents/Resources/Yuya.icns" "$app_dir/Contents/Resources/YuyaClownfish.icns"
xcodebuild -project "$project_dir/Yuya.xcodeproj" -scheme Yuya -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$project_dir/build" CODE_SIGNING_ALLOWED=NO build
icon_file="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIconFile' "$app_dir/Contents/Info.plist")"
[[ "$icon_file" == *.icns ]] || icon_file="$icon_file.icns"
[[ -s "$app_dir/Contents/Resources/$icon_file" ]] || { print -u2 "应用图标未打包"; exit 1; }
[[ -s "$app_dir/Contents/Resources/Assets.car" ]] || { print -u2 "原生图标未打包"; exit 1; }
codesign --force --sign - --options runtime --entitlements "$project_dir/Yuya/Yuya.entitlements" "$app_dir"
codesign --verify --deep --strict "$app_dir"
