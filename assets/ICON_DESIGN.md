# 小丑鱼图标

工具：内置 imagegen。图中为原创卡通小丑鱼与收紧的拉链袋，使用橙白色与深青色对比；不含文字。

## 1.2.2：移除重复底板

正式图标为 `assets/YuyaIcon.icon`。`assets/YuyaForeground.png` 是去除旧青色方板后的透明前景，尺寸转换后保存在 `assets/YuyaIcon.icon/Assets/Clownfish.png`。小丑鱼和收紧的拉链袋保留，背景、遮罩和显示效果交给系统处理。Xcode 将 `.icon` 编译成 `Assets.car` 和兼容用的 `YuyaIcon.icns`。正式应用不再手动覆盖 Dock 的原生图标。

`Yuya/Resources/YuyaClownfish.icns` 是 Swift Package 运行时的兼容资源，使用新图标预览重新封装。`assets/YuyaClownfish.png` 为历史原图，带旧底板，不能继续拿来生成正式图标。

使用 Xcode 27.1 附带的工具重新生成预览及兼容资源：

```sh
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" \
  assets/YuyaIcon.icon --export-image --output-file verification/icons/native-default.png \
  --platform macOS --rendition Default --width 1024 --height 1024 --scale 1 --design-generation 27
swift scripts/make_icon.swift verification/icons/native-default.png assets/Yuya.iconset
iconutil -c icns assets/Yuya.iconset -o Yuya/Resources/YuyaClownfish.icns
```

构建与打包仍执行 `scripts/package.sh` 或 `scripts/package-dmg.sh`。从压缩包解到新目录后，可导出系统实际显示的图标：

```sh
swift scripts/inspect_icon.swift /绝对路径/Yuya.app /绝对路径/icon.png
```

旧构建路径可能沿用图标缓存。此次新包实际导出的结果为 `verification/icons/system-after.png`，旧版为 `verification/icons/system-before.png`；新包不再出现灰色外框。窗口已从新包实际启动检查。未直接读取 Dock 画面，也未在 macOS 14 或 Intel Mac 验证。

设计依据：[Apple Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)、[Apple 应用图标设计](https://developer.apple.com/design/human-interface-guidelines/app-icons)。

本次去除底板的完整生成说明：

```text
Use case: background-extraction.
Image 1 is the EDIT TARGET, the existing Yuya app icon.
Change only the background: completely remove the large teal rounded-square app tile/backplate behind the clownfish and zippered compression pouch. Remove the tile's outer shadow and all floating stray pixels with it. Preserve the ENTIRE clownfish AND the smaller teal fabric zippered pouch wrapping its body: same friendly face, eye, orange-and-white bands, orange fan tail, fins, pose, zipper teeth, large ivory zipper pull, teal fabric texture, colors, shading, and proportions. The smaller pinched fabric pouch is part of the foreground and MUST stay. Do not add, redesign, or simplify the fish or the pouch.
Output a clean, carefully edged cutout of the fish in its pouch on a genuinely transparent background. No rounded-square tile, no rectangular or circular background, no opaque matte, no text, no border, no extra shadows outside the subject. Keep all parts of the fish, pouch, and zipper intact. Center the full subject on a square transparent canvas with a modest safety margin around every edge. This will be a foreground layer on a separately supplied native Mac icon background.
```

## 历史原图生成说明

```text
Use case: logo-brand.
Asset type: final macOS application icon for Yuya, a file compression app.
Create one polished original friendly cartoon clownfish combined with a file-compression metaphor. A plump bright orange clownfish with three broad cream-white bands edged in dark orange, one big expressive eye and a cheerful calm face, is snugly packed inside a small deep-teal zippered compression pouch. Its recognizable head and orange fan tail peek out at opposite ends. The pouch has visibly cinched-in sides and one large simple ivory zipper pull at its front: the squeezing and zipper must read as "make files smaller", while the fish remains happy and unharmed. The fish is the dominant recognizable shape, not a tiny decoration.
Style: premium playful macOS icon illustration, soft rounded sculpted cartoon, clean bold silhouettes, gentle depth and simple broad highlights, restrained detail, legible at 32 and 64 pixels. An original character, not Nemo or a reproduction of any copyrighted movie character.
Composition: exactly one centered icon. Deep ocean teal rounded-square app tile occupies about 82% of the square canvas, with a small soft shadow and generous fully transparent space around the tile. Fish and pouch occupy most of the tile, with high orange/cream versus teal contrast. Everything stays within the tile. No text, letters, watermarks, extra fish, coral, underwater scene, scattered bubbles, arrows, border frames, or separate panels. Genuine alpha transparency outside the rounded tile. Square 1024x1024 or larger.
```
