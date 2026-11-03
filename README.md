# Yuya

面向 macOS 14 及以上版本的本地压缩工具。创建 ZIP，浏览和解压 ZIP、7Z、RAR、TAR、GZIP、BZIP2、XZ；不需要上传文件或安装命令行压缩软件。

## 使用

1. 在“压缩文件”或“解压文件”中拖入文件，也可以按 ⌘O 选择。
2. 在文件列表中搜索、按名称或大小排序；选中项目后可移除，也可通过右键菜单在访达中定位。
3. 解压前双击压缩包，或选中后按空格，查看包内目录。预览最多显示前 10,000 项，并保留完整数量统计；单个压缩文件无法提前确定大小时会显示“未知”。
4. 按 ⌘↵ 选择保存位置并开始处理。处理过程中可取消；完成后可以直接显示结果。
5. 在“最近记录”中找回最近 30 次完成的结果。清除记录不会删除文件。

每个压缩包解压到独立的新文件夹。遇到同名目录会自动编号；取消或失败会清理尚未完成的临时结果。通过访达“打开方式”或“解压文件”服务打开时，先选择保存位置，多个请求按顺序处理。应用仅访问用户选择的文件；最近记录保留必要的文件访问凭据，供重启后定位结果。

压缩偏好提供“更快、均衡、更小”。默认忽略 `.DS_Store`、`._` 文件和 `__MACOSX` 目录；可以关闭此选项。压缩不会删除源文件。

## 范围与限制

- 当前仅创建 ZIP，不创建 7Z 或 RAR。
- 不支持密码、分卷压缩包或包内文件的单独提取、修改。不能把本次改进理解为与成熟商业工具完全等同。
- 预览只读取目录，不代表压缩包通过完整性检查；实际解压会读取并检查文件数据。
- 为防止文件写到目标目录之外，拒绝绝对路径、向上越界的路径和链接、特殊设备文件；也拒绝带反斜线的路径。指向压缩包内部的普通相对链接可以保留。
- ZIP 用于文件共享，不作为完整 Mac 备份格式；不保证保留所有访达标签、资源叉或访问控制信息。
- 可处理的具体压缩变体取决于所用 macOS 提供的 libarchive；测试覆盖记录见 [验证记录](VERIFICATION.md)。

## 打包

在项目目录运行以下命令之一：

```sh
# ZIP 压缩包
./scripts/package.sh

# DMG 安装包
./scripts/package-dmg.sh
```

两个脚本都会构建应用，并将带版本和适用芯片名称的成品放入 `dist/`。`apple-silicon` 适用于 Apple 芯片，`intel` 适用于 Intel 芯片，`universal` 适用于两者。

ZIP 会实际解开检查。DMG 会实际挂载检查，其中包含 `Yuya.app` 和“应用程序”入口；双击 DMG 后将 Yuya 拖入“应用程序”即可安装。两种方式都会核对应用完整性和小丑鱼图标。

这是本机临时签名的应用包，尚未进行对外分发签名和公证。

## Mac App Store

商店版准备为 1.3（6），应用已加入文件访问限制及隐私声明。商店介绍、隐私草稿、真实验收记录和签名归档步骤见 [上架说明](distribution/app-store/上架说明.md)。本地验收可运行：

```sh
./scripts/archive-store.sh local
```

生成 `build/AppStore-local/Yuya.xcarchive`，同时包含 Apple 和 Intel 芯片版本，仅用于本地检查，不能直接上传。正式归档、商店记录和最终提交仍需开发者账号授权及完整的商店资料。

## 构建与验证

本地安装 Xcode 后，在项目目录运行：

```sh
./scripts/build.sh
./scripts/test.sh
python3 scripts/benchmark.py
python3 scripts/check_copy.py
```

应用输出为 `build/Build/Products/Release/Yuya.app`，采用本机临时签名，尚未进行对外分发签名和公证。

Xcode 与 Swift Package Manager 共用 `Yuya/` 下的界面与业务代码，`Sources/CArchive/` 提供流式文件处理。正式 Mac 应用启用 App Sandbox；直接运行 Swift Package 不具备应用包权限环境，不能代替沙盒实测。压缩使用系统提供的同卷替换目录，只在完整写入后替换目标文件，解压通过私有临时目录和不覆盖方式发布结果。处理不占用主界面线程，进度反馈最多约每秒 10 次，文件图标采用有上限的缓存。中文文件名转换仅影响当前处理线程，不改变界面或并行任务的语言环境。

`gen_project.rb` 用于同步 Xcode 的源文件与资源引用，需要 Ruby 的 `xcodeproj` 库；普通构建不需要执行它。正式应用的分层图标为 `assets/YuyaIcon.icon`，透明小丑鱼前景为 `assets/YuyaForeground.png`；由 Xcode 编译，并由系统生成外框与显示效果。`Yuya/Resources/YuyaClownfish.icns` 用于 Swift Package 运行。重新生成和检查方法见 [图标说明](assets/ICON_DESIGN.md)。界面名称和说明统一维护在 `Yuya/AppCopy.swift`，完整清单见 [文案说明](COPY_GUIDE.md)。

公开声明文件及测试样本的来源与许可见 [第三方说明](THIRD_PARTY_NOTICES.md)。
