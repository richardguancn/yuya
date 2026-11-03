#!/usr/bin/env python3
"""Validate a real archived application; does not claim Apple's server validation passed."""
import plistlib
from pathlib import Path
import subprocess
import sys

if len(sys.argv) != 2:
    raise SystemExit("用法：python3 scripts/check_store.py /path/Yuya.app")
app = Path(sys.argv[1]).resolve()
contents = app / "Contents"
info = plistlib.loads((contents / "Info.plist").read_bytes())
assert info["CFBundlePackageType"] == "APPL", "不是完整应用"
assert info["CFBundleIdentifier"] == "com.gdy.yuya", "应用编号不匹配"
assert info["LSApplicationCategoryType"] == "public.app-category.utilities", "缺少工具分类"
assert info.get("ITSAppUsesNonExemptEncryption") is False, "缺少加密声明"
assert info.get("CFBundleIconName") == "YuyaIcon", "原生图标配置不匹配"
for resource in ("Assets.car", "YuyaIcon.icns", "PrivacyInfo.xcprivacy"):
    assert (contents / "Resources" / resource).stat().st_size > 0, f"缺少资源：{resource}"
privacy = plistlib.loads((contents / "Resources/PrivacyInfo.xcprivacy").read_bytes())
assert privacy["NSPrivacyTracking"] is False
assert privacy["NSPrivacyCollectedDataTypes"] == []
reasons = {item["NSPrivacyAccessedAPIType"]: set(item["NSPrivacyAccessedAPITypeReasons"])
           for item in privacy["NSPrivacyAccessedAPITypes"]}
assert "CA92.1" in reasons.get("NSPrivacyAccessedAPICategoryUserDefaults", set())
assert {"3B52.1", "C617.1"} <= reasons.get("NSPrivacyAccessedAPICategoryFileTimestamp", set())
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
entitlements = plistlib.loads(subprocess.check_output(["codesign", "-d", "--entitlements", ":-", str(app)], stderr=subprocess.DEVNULL))
required = {"com.apple.security.app-sandbox", "com.apple.security.files.user-selected.read-write",
            "com.apple.security.files.bookmarks.app-scope", "com.apple.security.files.user-selected.executable"}
assert all(entitlements.get(key) is True for key in required), "签名缺少文件访问限制"
assert not entitlements.get("com.apple.security.get-task-allow"), "商店版不应允许调试附加"
assert not any(key.startswith("com.apple.security.temporary-exception") for key in entitlements), "不应使用临时权限例外"
assert not entitlements.get("com.apple.security.network.client"), "本地工具不需要网络权限"
binary = contents / "MacOS" / info["CFBundleExecutable"]
architectures = set(subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split())
assert architectures == {"arm64", "x86_64"}, f"缺少适用芯片：{architectures}"
print(f"通过：Yuya {info['CFBundleShortVersionString']}（{info['CFBundleVersion']}），Apple 与 Intel 芯片，文件访问限制、隐私声明、图标、签名完整。")
print("此检查仅针对本地归档，不代表已上传或通过苹果审核。")
