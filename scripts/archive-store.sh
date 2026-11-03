#!/bin/zsh
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:-local}"
case "$mode" in
  local|signed) ;;
  *) print -u2 "用法：scripts/archive-store.sh local|signed"; exit 2 ;;
esac
python3 "$project_dir/scripts/check_copy.py"
archive="$project_dir/build/AppStore-$mode/Yuya.xcarchive"
arguments=(-project "$project_dir/Yuya.xcodeproj" -scheme Yuya -configuration AppStore
  -destination 'generic/platform=macOS' -derivedDataPath "$project_dir/build/AppStoreDerived"
  -archivePath "$archive" 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO)
if [[ "$mode" == signed ]]; then
  [[ -n "${YUYA_TEAM_ID:-}" ]] || { print -u2 "请先设置 YUYA_TEAM_ID，选择上架使用的开发者团队。"; exit 2; }
  [[ "$YUYA_TEAM_ID" =~ '^[A-Z0-9]{10}$' ]] || { print -u2 "YUYA_TEAM_ID 应为 10 位开发者团队编号。"; exit 2; }
  # Xcode automatic signing archives with a development identity. The App Store
  # distribution identity is selected later when the archive is exported.
  arguments+=("DEVELOPMENT_TEAM=$YUYA_TEAM_ID" "CODE_SIGN_IDENTITY=${YUYA_SIGN_IDENTITY:-Apple Development}" -allowProvisioningUpdates)
else
  arguments+=(CODE_SIGNING_ALLOWED=NO)
fi
xcodebuild "${arguments[@]}" archive
app="$archive/Products/Applications/Yuya.app"
if [[ "$mode" == local ]]; then
  codesign --force --sign - --options runtime --entitlements "$project_dir/Yuya/Yuya.entitlements" "$app"
fi
python3 "$project_dir/scripts/check_store.py" "$app"
if [[ "$mode" == local ]]; then
  print "本地验收归档已生成（不能上传商店）：$archive"
else
  print "签名归档已生成，请在 Xcode 中校验并分发到 App Store Connect：$archive"
fi
