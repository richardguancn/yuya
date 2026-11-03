import Foundation

/// Product-authored labels and explanations in Simplified Chinese and Native English.
enum AppCopy {
    /// Override language for rendering previews/screenshots or tests.
    nonisolated(unsafe) static var languageOverride: String? = nil

    /// Determines whether the active preferred language is English.
    static var isEnglish: Bool {
        if let override = languageOverride {
            return override.hasPrefix("en")
        }
        if let preferred = Locale.preferredLanguages.first {
            return preferred.hasPrefix("en") || !preferred.hasPrefix("zh")
        }
        return false
    }

    private static func localized(zh: String, en: String) -> String {
        isEnglish ? en : zh
    }

    static func itemsAdded(_ count: Int) -> String {
        isEnglish ? (count == 1 ? "1 item added" : "\(count) items added") : "已添加 \(count) 项"
    }

    static func extractionFinished(_ count: Int) -> String {
        isEnglish ? "Extraction Complete · \(count) \(count == 1 ? "archive" : "archives")" : "解压完成 · \(count) 个压缩包"
    }

    static func foldersSummary(_ count: Int) -> String {
        isEnglish ? "\(count) folders · Size computed during processing" : "\(count) 个文件夹 · 大小在处理时统计"
    }

    static func itemsSummary(count: Int, size: String, hasFolders: Bool) -> String {
        if isEnglish {
            return "\(count) items · \(size)\(hasFolders ? " (excluding folders)" : "")"
        } else {
            return "\(count) 项 · \(size)\(hasFolders ? "（文件夹另计）" : "")"
        }
    }

    enum Label {
        static var compress: String { localized(zh: "压缩文件", en: "Compress") }
        static var extract: String { localized(zh: "解压文件", en: "Extract") }
        static var history: String { localized(zh: "最近记录", en: "Recents") }
        static var tools: String { localized(zh: "文件工具", en: "Tools") }
        static var privacy: String { localized(zh: "隐私说明", en: "Privacy") }
        static var add: String { localized(zh: "添加文件", en: "Add Files…") }
        static var choose: String { localized(zh: "选择文件", en: "Choose…") }
        static var select: String { localized(zh: "添加", en: "Add") }
        static var start: String { localized(zh: "开始处理", en: "Start") }
        static var startCompress: String { localized(zh: "开始压缩", en: "Compress") }
        static var startExtract: String { localized(zh: "开始解压", en: "Extract") }
        static var remove: String { localized(zh: "移除文件", en: "Remove") }
        static var clear: String { localized(zh: "清空列表", en: "Clear List") }
        static var clearHistory: String { localized(zh: "清空记录", en: "Clear Recents") }
        static var preview: String { localized(zh: "查看内容", en: "Preview") }
        static var location: String { localized(zh: "打开位置", en: "Show in Finder") }
        static var details: String { localized(zh: "查看原因", en: "View Details") }
        static var errorTitle: String { localized(zh: "失败原因", en: "Operation Failed") }
        static var close: String { localized(zh: "关闭", en: "Close") }
        static var search: String { localized(zh: "查找文件", en: "Search") }
        static var waiting: String { localized(zh: "文件列表", en: "Files") }
        static var drop: String { localized(zh: "拖入文件", en: "Drop Files") }
        static var name: String { localized(zh: "名称", en: "Name") }
        static var size: String { localized(zh: "大小", en: "Size") }
        static var folder: String { localized(zh: "文件夹", en: "Folder") }
        static var unknown: String { localized(zh: "未知", en: "Unknown") }
        static var compressOptions: String { localized(zh: "压缩设置", en: "Compression") }
        static var extractOptions: String { localized(zh: "解压说明", en: "Extraction") }
        static var format: String { localized(zh: "文件格式", en: "Archive Format") }
        static var common: String { localized(zh: "通用", en: "Standard ZIP") }
        static var preference: String { localized(zh: "压缩方式", en: "Compression Level") }
        static var fast: String { localized(zh: "更快", en: "Fastest") }
        static var balanced: String { localized(zh: "均衡", en: "Normal") }
        static var small: String { localized(zh: "更小", en: "Smallest Size") }
        static var tidy: String { localized(zh: "减少杂项", en: "Strip Mac Metadata") }
        static var reveal: String { localized(zh: "自动打开", en: "Reveal When Done") }
        static var destination: String { localized(zh: "保存位置", en: "Destination") }
        static var separate: String { localized(zh: "分开保存", en: "Separate Folders") }
        static var keep: String { localized(zh: "保留原件", en: "Keep Originals") }
        static var inspect: String { localized(zh: "查看内容", en: "Quick Look") }
        static var privateFiles: String { localized(zh: "本机处理", en: "On-Device") }
        static var noHistory: String { localized(zh: "暂无记录", en: "No Recent Tasks") }
        static var noResults: String { localized(zh: "没有结果", en: "No Matches Found") }
        static var loading: String { localized(zh: "正在读取", en: "Loading…") }
        static var cannotPreview: String { localized(zh: "无法查看", en: "Cannot Preview") }
        static var ready: String { localized(zh: "等待添加", en: "Ready") }
        static var cancelled: String { localized(zh: "已取消", en: "Canceled") }
        static var cancelling: String { localized(zh: "正在取消", en: "Canceling…") }
        static var cancel: String { localized(zh: "取消处理", en: "Cancel") }
        static var compressing: String { localized(zh: "正在压缩", en: "Compressing…") }
        static var extracting: String { localized(zh: "正在解压", en: "Extracting…") }
        static var compressed: String { localized(zh: "压缩完成", en: "Compression Complete") }
        static var extracted: String { localized(zh: "解压完成", en: "Extraction Complete") }
        static var readFailed: String { localized(zh: "读取失败", en: "Unreadable") }
        static var systemDetails: String { localized(zh: "具体原因", en: "Details") }
        static var previewMore: String { localized(zh: "显示上限", en: "Truncated") }
    }

    enum Description {
        static var purpose: String { localized(zh: "文件压缩与解压", en: "Compress and extract archives locally on your Mac.") }
        static var compress: String { localized(zh: "把多个文件合成一个压缩包", en: "Bundle multiple files into a single ZIP archive.") }
        static var extract: String { localized(zh: "取出压缩包里的文件", en: "Unpack contents from common archive formats.") }
        static var history: String { localized(zh: "查看已完成的压缩和解压记录", en: "Review your last 30 completed tasks.") }
        static var local: String { localized(zh: "文件只在这台电脑上处理", en: "Processed entirely on your Mac. Nothing leaves your device.") }
        static var noUpload: String { localized(zh: "无需上传文件，也不需要网络", en: "No account, no cloud storage, and no network required.") }
        static var dropFiles: String { localized(zh: "拖入文件或文件夹", en: "Drag and drop files or folders here.") }
        static var dropArchives: String { localized(zh: "拖入需要解压的压缩包", en: "Drag and drop archives here to unpack.") }
        static var multiple: String { localized(zh: "可以一次添加多个文件或文件夹", en: "Add multiple files or folders at once.") }
        static var supported: String { localized(zh: "支持多种常见压缩包", en: "Supports ZIP, 7Z, RAR, TAR, GZIP, BZIP2, and XZ.") }
        static var dropHint: String { localized(zh: "拖入即可添加", en: "Drop items here to add them to the queue.") }
        static var removeHint: String { localized(zh: "只从列表移除，不删除原文件", en: "Removes items from the list without deleting original files.") }
        static var common: String { localized(zh: "电脑和手机都能打开", en: "Compatible with Windows, Mac, iPhone, and Android.") }
        static var fast: String { localized(zh: "压缩更快，文件可能稍大", en: "Fastest compression with slightly larger file size.") }
        static var balanced: String { localized(zh: "兼顾速度和文件大小", en: "Best balance between speed and archive size.") }
        static var small: String { localized(zh: "文件尽量小，等待时间更长", en: "Smallest possible file size. Takes longer to compress.") }
        static var tidy: String { localized(zh: "不放入 Mac 自动生成的杂项文件", en: "Excludes hidden files like .DS_Store and __MACOSX.") }
        static var separate: String { localized(zh: "每个压缩包放进单独的文件夹", en: "Extracts each archive into its own separate folder.") }
        static var keep: String { localized(zh: "同名文件夹自动编号，保留原件", en: "Auto-numbers existing folders to prevent overwriting.") }
        static var inspect: String { localized(zh: "双击压缩包，先看里面有什么", en: "Double-click or press Space to peek inside without extracting.") }
        static var compressLocation: String { localized(zh: "开始时选择保存位置", en: "Choose a destination folder before compression starts.") }
        static var extractLocation: String { localized(zh: "开始时选择文件夹，保留原压缩包", en: "Choose an output folder. Existing archives remain untouched.") }
        static var historyEmpty: String { localized(zh: "这里保留最近 30 次完成记录", en: "Your last 30 completed tasks will appear here.") }
        static var ready: String { localized(zh: "添加文件后即可开始", en: "Add files or folders to get started.") }
        static var clearHistory: String { localized(zh: "只清空记录，不删除文件", en: "Clears task history only. Your files remain untouched.") }
        static var clearList: String { localized(zh: "只清空列表，不删除文件", en: "Clears the queue only. Does not delete any files.") }
        static var autoReveal: String { localized(zh: "完成后显示文件所在位置", en: "Automatically shows output in Finder when finished.") }
        static var chooseLocation: String { localized(zh: "点击开始，再选择保存位置", en: "Click Start, then choose a destination folder.") }
        static var invalidArchive: String { localized(zh: "请先移除不能解压的文件", en: "Please remove unsupported files from the list.") }
        static var dropFailed: String { localized(zh: "请点击“添加文件”重新选择", en: "Could not add dragged items. Please click Add Files.") }
        static var pickFiles: String { localized(zh: "选择要压缩的文件或文件夹", en: "Select the files or folders you want to compress.") }
        static var pickArchives: String { localized(zh: "选择压缩包，可一次添加多个", en: "Select one or more archives to unpack.") }
        static var saveArchive: String { localized(zh: "选择压缩包的保存位置", en: "Choose where to save the compressed ZIP archive.") }
        static var saveExtracted: String { localized(zh: "分开保存，同名文件夹自动编号", en: "Each archive extracts to a newly numbered folder.") }
        static var cancelled: String { localized(zh: "未完成内容已清理，原文件保留", en: "Cleaned up temporary output. Original files are untouched.") }
        static var preview: String { localized(zh: "先看内容，无需解压", en: "Inspect files and folder structure without extracting.") }
        static var previewLimit: String { localized(zh: "仅列前 10,000 项，统计包含全部", en: "Listing the first 10,000 items. Full statistics preserved.") }
        static var previewMore: String { localized(zh: "解压后可查看所有文件", en: "Extract the archive to access all remaining files.") }
        static var needsPassword: String { localized(zh: "暂不支持需要密码的压缩包", en: "Password-protected archives are currently unsupported.") }
        static var archiveFailed: String { localized(zh: "无法处理这个压缩包", en: "Could not process this archive.") }
        static var unsupported: String { localized(zh: "压缩包已损坏或暂不支持", en: "The archive is corrupted or in an unsupported format.") }
        static var noSpace: String { localized(zh: "空间不足，请腾出空间后重试", en: "Not enough free disk space. Free up space and try again.") }
        static var noAccess: String { localized(zh: "无法读写文件，请检查访问权限", en: "Cannot access file. Please check folder permissions.") }
        static var unknownFailure: String { localized(zh: "处理失败，请查看具体原因", en: "Operation failed. View details for more information.") }
        static var noSources: String { localized(zh: "请先添加文件或文件夹", en: "Please add at least one file or folder.") }
        static var sameOutput: String { localized(zh: "请勿覆盖源文件或存入所选文件夹", en: "Destination cannot be inside or overwrite the source.") }
        static var duplicates: String { localized(zh: "文件同名，请改名后再压缩", en: "Items have duplicate names. Please rename before compressing.") }
        static var disk: String { localized(zh: "请选择文件夹，不支持整个磁盘", en: "Please select a folder. Entire volumes are not supported.") }
        static var tooManyFolders: String { localized(zh: "同名文件夹过多，请换个保存位置", en: "Too many existing folders with the same name. Choose another location.") }
        static var sourceMissing: String { localized(zh: "找不到文件，请重新添加", en: "File no longer exists. Please add it again.") }
        static var saveFailed: String { localized(zh: "无法保存文件，请查看具体原因", en: "Could not save file. View details for more information.") }
        static var service: String { localized(zh: "请先选中支持解压的压缩包", en: "Please select a supported archive file.") }
    }
}
