#!/bin/zsh
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
runner="$project_dir/build/StoreScreenshots/Renderer.app"
output="$project_dir/dist/mac-app-store/screenshots"
sample="$project_dir/build/StoreScreenshots/示例文件"
app="$project_dir/build/AppStore-local/Yuya.xcarchive/Products/Applications/Yuya.app"
[[ -d "$app" ]] || { print -u2 "请先运行 scripts/archive-store.sh local"; exit 1; }
mkdir -p "$runner/Contents/MacOS" "$runner/Contents/Resources" "$output" "$sample"
cp "$app/Contents/Info.plist" "$runner/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleIdentifier com.gdy.yuya.screenshot-renderer' "$runner/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleExecutable Renderer' "$runner/Contents/Info.plist"
cp "$app/Contents/Resources/Assets.car" "$app/Contents/Resources/YuyaIcon.icns" "$runner/Contents/Resources/"
xcrun clang -c "$project_dir/Sources/CArchive/CArchive.c" -I "$project_dir/Sources/CArchive/include" -o "$project_dir/build/StoreScreenshots/CArchive.o"
xcrun swiftc -parse-as-library -swift-version 6 -I "$project_dir/Sources/CArchive/include" \
  "$project_dir/scripts/store_screenshots.swift" "$project_dir/Yuya/AppCopy.swift" "$project_dir/Yuya/AppIcon.swift" \
  "$project_dir/Yuya/FileAccess.swift" "$project_dir/Yuya/ArchiveService.swift" \
  "$project_dir/Yuya/ArchiveViewModel.swift" "$project_dir/Yuya/ContentView.swift" \
  "$project_dir/build/StoreScreenshots/CArchive.o" -larchive -o "$runner/Contents/MacOS/Renderer"
"$runner/Contents/MacOS/Renderer" "$sample" "$output"
for file in "$output"/*.png; do sips -g pixelWidth -g pixelHeight "$file"; done
