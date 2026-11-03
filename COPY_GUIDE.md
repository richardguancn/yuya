# 界面文案与多语言设计指南

本次范围覆盖 Yuya 当前所有自写菜单、按钮、选项、空白页、状态和错误提示。
遵循 **《Don't Make Me Think》** 与 **《写给大家看的设计书》**，并严格对齐 **《Apple Style Guide》** 的原生规范（macOS Native HIG）：
- **中文规范**：名称严格控制在 **2–4 字**，说明不超过 **20 字**；避免晦涩术语，直击用户直觉。
- **英文规范**：采用最纯正地道、克制精准的 **Apple Native English**（动词短语、祈使句、短语习惯对齐 macOS 系统应用）。

---

## 一、 核心导航与功能模块

| Key | 中文文案 (2–4字) | Apple Native English | 设计说明 |
|---|---|---|---|
| `compress` | 压缩文件 | **Compress** | 苹果 Finder 官方右键原生用词 |
| `extract` | 解压文件 | **Extract** | 经典 macOS 归档工具标准用词 |
| `history` | 最近记录 | **Recents** | 对齐 Finder 侧边栏原词 Recents |
| `tools` | 文件工具 | **Tools** | 极简侧边栏分类 |
| `privacy` | 隐私说明 | **Privacy** | 苹果全系统标准隐私规范 |
| `preview` | 查看内容 | **Preview** | 经典 macOS 原生动词 |
| `location` | 打开位置 | **Show in Finder** | macOS 呼叫访达的标准系统短语 |
| `details` | 查看原因 | **View Details** | 错误与详情查看标准词 |
| `errorTitle` | 失败原因 | **Operation Failed** | 错误弹窗标题 |
| `close` | 关闭 | **Close** | 窗口与 Sheet 关闭按钮 |
| `search` | 查找文件 | **Search** | 快捷键 ⌘F 工具栏过滤 |
| `waiting` | 文件列表 | **Files** | 待处理队列 |
| `drop` | 拖入文件 | **Drop Files** | 空白状态引导 |

---

## 二、 交互动作与按钮

| Key | 中文文案 (2–4字) | Apple Native English | 设计说明 |
|---|---|---|---|
| `add` | 添加文件 | **Add Files…** | 唤起系统面板标准带省略号 |
| `choose` | 选择文件 | **Choose…** | 系统的通用文件选择按钮 |
| `select` | 添加 | **Add** | 确认动作 |
| `start` | 开始处理 | **Start** | 极简 |
| `startCompress` | 开始压缩 | **Compress** | 强调当前专属操作 |
| `startExtract` | 开始解压 | **Extract** | 强调当前专属操作 |
| `remove` | 移除文件 | **Remove** | 区分于彻底删除（Delete） |
| `clear` | 清空列表 | **Clear List** | 明确操作对象为列表 |
| `clearHistory` | 清空记录 | **Clear Recents** | 清空本地完成历史 |
| `cancel` | 取消处理 | **Cancel** | macOS 统一取消动作 |

---

## 三、 设置选项与参数

| Key | 中文文案 (2–4字) | Apple Native English | 设计说明 |
|---|---|---|---|
| `compressOptions` | 压缩设置 | **Compression** | 压缩面板标题 |
| `extractOptions` | 解压说明 | **Extraction** | 解压说明面板标题 |
| `format` | 文件格式 | **Archive Format** | 标准格式 |
| `common` | 通用 | **Standard ZIP** | 全平台通用格式 |
| `preference` | 压缩方式 | **Compression Level** | 业界标准级别名称 |
| `fast` | 更快 | **Fastest** | 最高速度 |
| `balanced` | 均衡 | **Normal** | 系统推荐默认模式 |
| `small` | 更小 | **Smallest Size** | 极限高压缩比 |
| `tidy` | 减少杂项 | **Strip Mac Metadata** | 专业地道表达（剔除 .DS_Store / __MACOSX） |
| `reveal` | 自动打开 | **Reveal When Done** | 系统级完成时自动展示的标准短语 |
| `destination` | 保存位置 | **Destination** | 输出路径标准词 |
| `separate` | 分开保存 | **Separate Folders** | 独立文件夹模式 |
| `keep` | 保留原件 | **Keep Originals** | 绝不覆盖原件 |
| `inspect` | 查看内容 | **Quick Look** | macOS 原生空格预览能力 |
| `privateFiles` | 本机处理 | **On-Device** | 苹果官方描述“纯本地不联网”标准用词 |

---

## 四、 状态反馈与实时进度

| Key | 中文文案 (2–4字) | Apple Native English |
|---|---|---|
| `ready` | 等待添加 | **Ready** |
| `loading` | 正在读取 | **Loading…** |
| `compressing` | 正在压缩 | **Compressing…** |
| `extracting` | 正在解压 | **Extracting…** |
| `compressed` | 压缩完成 | **Compression Complete** |
| `extracted` | 解压完成 | **Extraction Complete** |
| `cancelling` | 正在取消 | **Canceling…** |
| `cancelled` | 已取消 | **Canceled** |
| `readFailed` | 读取失败 | **Unreadable** |
| `systemDetails` | 具体原因 | **Details** |
| `noHistory` | 暂无记录 | **No Recent Tasks** |
| `noResults` | 没有结果 | **No Matches Found** |
| `cannotPreview` | 无法查看 | **Cannot Preview** |
| `previewMore` | 显示上限 | **Truncated** |

---

## 五、 说明描述（≤20字）

| Key | 中文说明 (≤20字) | Apple Native English |
|---|---|---|
| `purpose` | 文件压缩与解压 | **Compress and extract archives locally on your Mac.** |
| `compress` | 把多个文件合成一个压缩包 | **Bundle multiple files into a single ZIP archive.** |
| `extract` | 取出压缩包里的文件 | **Unpack contents from common archive formats.** |
| `history` | 查看已完成的压缩和解压记录 | **Review your last 30 completed tasks.** |
| `local` | 文件只在这台电脑上处理 | **Processed entirely on your Mac. Nothing leaves your device.** |
| `noUpload` | 无需上传文件，也不需要网络 | **No account, no cloud storage, and no network required.** |
| `dropFiles` | 拖入文件或文件夹 | **Drag and drop files or folders here.** |
| `dropArchives` | 拖入需要解压的压缩包 | **Drag and drop archives here to unpack.** |
| `multiple` | 可以一次添加多个文件或文件夹 | **Add multiple files or folders at once.** |
| `supported` | 支持多种常见压缩包 | **Supports ZIP, 7Z, RAR, TAR, GZIP, BZIP2, and XZ.** |
| `dropHint` | 拖入即可添加 | **Drop items here to add them to the queue.** |
| `removeHint` | 只从列表移除，不删除原文件 | **Removes items from the list without deleting original files.** |
| `common` | 电脑和手机都能打开 | **Compatible with Windows, Mac, iPhone, and Android.** |
| `fast` | 压缩更快，文件可能稍大 | **Fastest compression with slightly larger file size.** |
| `balanced` | 兼顾速度和文件大小 | **Best balance between speed and archive size.** |
| `small` | 文件尽量小，等待时间更长 | **Smallest possible file size. Takes longer to compress.** |
| `tidy` | 不放入 Mac 自动生成的杂项文件 | **Excludes hidden files like .DS_Store and __MACOSX.** |
| `separate` | 每个压缩包放进单独的文件夹 | **Extracts each archive into its own separate folder.** |
| `keep` | 同名文件夹自动编号，保留原件 | **Auto-numbers existing folders to prevent overwriting.** |
| `inspect` | 双击压缩包，先看里面有什么 | **Double-click or press Space to peek inside without extracting.** |
| `compressLocation` | 开始时选择保存位置 | **Choose a destination folder before compression starts.** |
| `extractLocation` | 开始时选择文件夹，保留原压缩包 | **Choose an output folder. Existing archives remain untouched.** |
| `historyEmpty` | 这里保留最近 30 次完成记录 | **Your last 30 completed tasks will appear here.** |
| `ready` | 添加文件后即可开始 | **Add files or folders to get started.** |
| `clearHistory` | 只清空记录，不删除文件 | **Clears task history only. Your files remain untouched.** |
| `clearList` | 只清空列表，不删除文件 | **Clears the queue only. Does not delete any files.** |
| `autoReveal` | 完成后显示文件所在位置 | **Automatically shows output in Finder when finished.** |
| `chooseLocation` | 点击开始，再选择保存位置 | **Click Start, then choose a destination folder.** |
| `invalidArchive` | 请先移除不能解压的文件 | **Please remove unsupported files from the list.** |
| `dropFailed` | 请点击“添加文件”重新选择 | **Could not add dragged items. Please click Add Files.** |
| `pickFiles` | 选择要压缩的文件或文件夹 | **Select the files or folders you want to compress.** |
| `pickArchives` | 选择压缩包，可一次添加多个 | **Select one or more archives to unpack.** |
| `saveArchive` | 选择压缩包的保存位置 | **Choose where to save the compressed ZIP archive.** |
| `saveExtracted` | 分开保存，同名文件夹自动编号 | **Each archive extracts to a newly numbered folder.** |
| `cancelled` | 未完成内容已清理，原文件保留 | **Cleaned up temporary output. Original files are untouched.** |
| `preview` | 先看内容，无需解压 | **Inspect files and folder structure without extracting.** |
| `previewLimit` | 仅列前 10,000 项，统计包含全部 | **Listing the first 10,000 items. Full statistics preserved.** |
| `previewMore` | 解压后可查看所有文件 | **Extract the archive to access all remaining files.** |
| `needsPassword` | 暂不支持需要密码的压缩包 | **Password-protected archives are currently unsupported.** |
| `archiveFailed` | 无法处理这个压缩包 | **Could not process this archive.** |
| `unsupported` | 压缩包已损坏或暂不支持 | **The archive is corrupted or in an unsupported format.** |
| `noSpace` | 空间不足，请腾出空间后重试 | **Not enough free disk space. Free up space and try again.** |
| `noAccess` | 无法读写文件，请检查访问权限 | **Cannot access file. Please check folder permissions.** |
| `unknownFailure` | 处理失败，请查看具体原因 | **Operation failed. View details for more information.** |
| `noSources` | 请先添加文件或文件夹 | **Please add at least one file or folder.** |
| `sameOutput` | 请勿覆盖源文件或存入所选文件夹 | **Destination cannot be inside or overwrite the source.** |
| `duplicates` | 文件同名，请改名后再压缩 | **Items have duplicate names. Please rename before compressing.** |
| `disk` | 请选择文件夹，不支持整个磁盘 | **Please select a folder. Entire volumes are not supported.** |
| `tooManyFolders` | 同名文件夹过多，请换个保存位置 | **Too many existing folders with the same name. Choose another location.** |
| `sourceMissing` | 找不到文件，请重新添加 | **File no longer exists. Please add it again.** |
| `saveFailed` | 无法保存文件，请查看具体原因 | **Could not save file. View details for more information.** |
| `service` | 请先选中支持解压的压缩包 | **Please select a supported archive file.** |
