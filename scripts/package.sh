#!/bin/zsh
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build.sh"
app_dir="$project_dir/build/Build/Products/Release/Yuya.app"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_dir/Contents/Info.plist")"
architectures="$(lipo -archs "$app_dir/Contents/MacOS/Yuya")"
case "$architectures" in
  *arm64*x86_64*|*x86_64*arm64*) platform="universal" ;;
  arm64) platform="apple-silicon" ;;
  x86_64) platform="intel" ;;
  *) print -u2 "Unknown architecture: $architectures"; exit 1 ;;
esac
output_dir="$project_dir/dist"
mkdir -p "$output_dir"
output="$output_dir/Yuya-$version-mac-$platform.zip"
temporary="$output_dir/.Yuya-package-$$.zip"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/yuya-package.XXXXXX")"
trap 'rm -f "$temporary"; rm -rf "$check_dir"' EXIT
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$temporary"
/usr/bin/unzip -tqq "$temporary"
/usr/bin/ditto -x -k "$temporary" "$check_dir"
/usr/bin/codesign --verify --deep --strict "$check_dir/Yuya.app"
icon_file="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIconFile' "$check_dir/Yuya.app/Contents/Info.plist")"
[[ "$icon_file" == *.icns ]] || icon_file="$icon_file.icns"
cmp "$app_dir/Contents/Resources/$icon_file" "$check_dir/Yuya.app/Contents/Resources/$icon_file"
cmp "$app_dir/Contents/Resources/Assets.car" "$check_dir/Yuya.app/Contents/Resources/Assets.car"
mv -f "$temporary" "$output"
print "打包完成：$output"
