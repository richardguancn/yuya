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
output="$output_dir/Yuya-$version-mac-$platform.dmg"
temporary="$output_dir/.Yuya-dmg-$$.dmg"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/yuya-dmg.XXXXXX")"
mount_dir="$work_dir/mounted"
attached=0
cleanup() {
  if (( attached )); then
    /usr/bin/hdiutil detach "$mount_dir" -quiet || return
  fi
  rm -f "$temporary"
  rm -rf "$work_dir"
}
trap cleanup EXIT
mkdir -p "$work_dir/staging" "$mount_dir"
/usr/bin/ditto "$app_dir" "$work_dir/staging/Yuya.app"
ln -s /Applications "$work_dir/staging/Applications"
/usr/bin/hdiutil create -volname "Yuya $version" -srcfolder "$work_dir/staging" \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 "$temporary"
/usr/bin/hdiutil verify "$temporary"
/usr/bin/hdiutil attach "$temporary" -readonly -nobrowse -mountpoint "$mount_dir"
attached=1
[[ -d "$mount_dir/Yuya.app" ]]
[[ "$(readlink "$mount_dir/Applications")" == "/Applications" ]]
/usr/bin/codesign --verify --deep --strict "$mount_dir/Yuya.app"
cmp "$app_dir/Contents/MacOS/Yuya" "$mount_dir/Yuya.app/Contents/MacOS/Yuya"
icon_file="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIconFile' "$mount_dir/Yuya.app/Contents/Info.plist")"
[[ "$icon_file" == *.icns ]] || icon_file="$icon_file.icns"
cmp "$app_dir/Contents/Resources/$icon_file" "$mount_dir/Yuya.app/Contents/Resources/$icon_file"
cmp "$app_dir/Contents/Resources/Assets.car" "$mount_dir/Yuya.app/Contents/Resources/Assets.car"
/usr/bin/hdiutil detach "$mount_dir" -quiet
attached=0
mv -f "$temporary" "$output"
print "打包完成：$output"
