import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case compress, extract, history
    var id: Self { self }
    var title: String { switch self { case .compress: AppCopy.Label.compress; case .extract: AppCopy.Label.extract; case .history: AppCopy.Label.history } }
    var symbol: String { switch self { case .compress: "archivebox"; case .extract: "tray.and.arrow.down"; case .history: "clock" } }
}
struct ArchiveItem: Identifiable, Hashable, Sendable {
    var id: URL { url }
    var name: String { url.lastPathComponent }
    let url: URL
    let isDirectory: Bool
    let size: Int64
    var sizeDescription: String { isDirectory ? AppCopy.Label.folder : ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
}
struct TaskRecord: Identifiable, Codable {
    let id: UUID
    let name: String
    let action: String
    let output: URL
    let date: Date
    let duration: Double
    let outputBytes: Int64?
    var bookmark: Data? = nil
}

typealias ExtractionDestinationPicker = @MainActor ([URL], @escaping @MainActor (URL?) -> Void) -> Void

@MainActor
final class ArchiveViewModel: ObservableObject {
    @Published var section: WorkspaceSection = .compress
    @Published private(set) var items: [ArchiveItem] = []
    @Published var selection = Set<URL>()
    @Published var search = ""
    @Published private(set) var isWorking = false
    @Published private(set) var isImporting = false
    @Published private(set) var choosingDestination = false
    @Published private(set) var cancelling = false
    @Published private(set) var statusMessage = AppCopy.Label.ready
    @Published private(set) var statusDetail = AppCopy.Description.local
    @Published private(set) var statusIsError = false
    @Published private(set) var progress: ArchiveProgress?
    @Published private(set) var batchPosition = ""
    @Published private(set) var history: [TaskRecord] = []
    @Published private(set) var lastOutputs: [URL] = []
    @Published var compressionLevel: CompressionLevel = .balanced
    @Published var excludeMetadata = true
    @Published var revealWhenDone = false
    @Published var previewTitle = ""
    @Published var showingPreview = false
    @Published private(set) var previewManifest: ArchiveManifest?
    @Published private(set) var previewError: String?
    @Published private(set) var previewLoading = false
    private let service = ArchiveService()
    private let defaults: UserDefaults
    private let destinationPicker: ExtractionDestinationPicker?
    private var task: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var externalQueue: [URL] = []
    private var activeID = UUID()
    private var terminating = false

    init(defaults: UserDefaults = .standard, destinationPicker: ExtractionDestinationPicker? = nil) {
        self.defaults = defaults
        self.destinationPicker = destinationPicker
        if let raw = defaults.object(forKey: "compressionLevel") as? Int, let value = CompressionLevel(rawValue: raw) { compressionLevel = value }
        if defaults.object(forKey: "excludeMetadata") != nil { excludeMetadata = defaults.bool(forKey: "excludeMetadata") }
        revealWhenDone = defaults.bool(forKey: "revealWhenDone")
        if let data = defaults.data(forKey: "taskHistory"), let records = try? JSONDecoder().decode([TaskRecord].self, from: data) { history = records }
    }
    var busy: Bool { isWorking || isImporting || choosingDestination }
    var archives: [ArchiveItem] { items.filter { !$0.isDirectory && ArchiveService.supports($0.url) } }
    var canRun: Bool { !busy && !items.isEmpty && section != .history && (section != .extract || archives.count == items.count) }
    var filteredItems: [ArchiveItem] {
        search.isEmpty ? items : items.filter { $0.url.lastPathComponent.localizedStandardContains(search) || $0.url.deletingLastPathComponent().path.localizedStandardContains(search) }
    }
    var inputSummary: String {
        let bytes = items.reduce(Int64(0)) { $0 + $1.size }
        let folders = items.filter(\.isDirectory).count
        if folders == items.count && folders > 0 { return AppCopy.foldersSummary(folders) }
        return AppCopy.itemsSummary(count: items.count, size: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file), hasFolders: folders > 0)
    }

    func addURLs(_ urls: [URL]) {
        guard !busy, !urls.isEmpty else { return }
        isImporting = true
        Task {
            let access = FileAccess(urls)
            defer { withExtendedLifetime(access) {} }
            let newItems = await Task.detached(priority: .userInitiated) {
                urls.filter(\.isFileURL).compactMap { url -> ArchiveItem? in
                    guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) else { return nil }
                    return ArchiveItem(url: url, isDirectory: values.isDirectory == true, size: Int64(values.fileSize ?? 0))
                }
            }.value
            var known = Set(items.map { $0.url.standardizedFileURL })
            items.append(contentsOf: newItems.filter { known.insert($0.url.standardizedFileURL).inserted })
            if section == .history { section = .compress }
            selection.formIntersection(Set(items.map(\.url)))
            isImporting = false; lastOutputs = []
            statusIsError = newItems.count < urls.count
            statusMessage = statusIsError ? AppCopy.Label.readFailed : AppCopy.itemsAdded(items.count)
            statusDetail = section == .extract && archives.count != items.count ? AppCopy.Description.invalidArchive : AppCopy.Description.chooseLocation
            drainExternalQueue()
        }
    }
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !busy else { return false }
        let supported = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !supported.isEmpty else { return false }
        isImporting = true
        Task {
            var urls: [URL] = []
            for provider in supported {
                let url: URL? = await withCheckedContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        let url: URL?
                        if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                        else { url = item as? URL }
                        continuation.resume(returning: url)
                    }
                }
                if let url { urls.append(url) }
            }
            isImporting = false
            if urls.isEmpty {
                statusIsError = true; statusMessage = AppCopy.Label.readFailed; statusDetail = AppCopy.Description.dropFailed
                drainExternalQueue()
            } else { addURLs(urls) }
        }
        return true
    }
    func pickFiles() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.title = AppCopy.Label.add
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = section != .extract
        panel.canChooseFiles = true
        panel.prompt = AppCopy.Label.select
        panel.message = section == .extract ? AppCopy.Description.pickArchives : AppCopy.Description.pickFiles
        if section == .extract { panel.allowedContentTypes = ArchiveService.extensions.compactMap { UTType(filenameExtension: $0) } }
        choosingDestination = true
        present(panel) { [weak self] response in
            guard let self else { return }
            self.choosingDestination = false
            if response == .OK { self.addURLs(panel.urls) }
            else { self.drainExternalQueue() }
        }
    }
    func removeSelection() {
        guard !busy else { return }
        items.removeAll { selection.contains($0.url) }; selection = []; resetStatus()
    }
    func clear() {
        guard !busy else { return }
        items = []; selection = []; search = ""; lastOutputs = []; resetStatus()
    }
    func resetStatus() {
        statusMessage = items.isEmpty ? AppCopy.Label.ready : AppCopy.itemsAdded(items.count)
        statusDetail = AppCopy.Description.local; statusIsError = false
    }
    func reveal(_ urls: [URL]) { NSWorkspace.shared.activateFileViewerSelecting(urls) }
    func revealResult() { reveal(lastOutputs) }
    func revealRecord(_ record: TaskRecord) {
        let url: URL
        do { url = try record.bookmark.map(FileAccess.resolve) ?? record.output }
        catch { statusIsError = true; statusMessage = AppCopy.Label.readFailed; statusDetail = AppCopy.Description.sourceMissing; return }
        let access = FileAccess([url])
        defer { withExtendedLifetime(access) {} }
        guard FileManager.default.fileExists(atPath: url.path) else {
            statusIsError = true; statusMessage = AppCopy.Label.readFailed; statusDetail = AppCopy.Description.sourceMissing
            return
        }
        if let index = history.firstIndex(where: { $0.id == record.id }) {
            history[index].bookmark = FileAccess.bookmark(for: url)
            saveHistory()
        }
        reveal([url])
    }

    func run() {
        guard canRun else { return }
        let sources = items.map(\.url), compressing = section == .compress
        choosingDestination = true
        if compressing {
            let panel = NSSavePanel()
            panel.title = AppCopy.Label.compress
            panel.allowedContentTypes = [.zip]
            panel.nameFieldStringValue = sources.count == 1 ? "\(ArchiveService.outputName(for: sources[0])).zip" : "压缩文件.zip"
            panel.directoryURL = sources.first?.deletingLastPathComponent()
            panel.message = AppCopy.Description.saveArchive
            present(panel) { [weak self] response in
                guard let self else { return }
                self.choosingDestination = false
                if response == .OK, let destination = panel.url { self.start(sources: sources, destination: destination, compressing: true) }
                else { self.drainExternalQueue() }
            }
        } else {
            chooseExtractionDestination(sources)
        }
    }
    private func chooseExtractionDestination(_ sources: [URL]) {
        choosingDestination = true
        let completion: @MainActor (URL?) -> Void = { [weak self] destination in
            guard let self else { return }
            self.choosingDestination = false
            guard !self.terminating else { return }
            if let destination { self.start(sources: sources, destination: destination, compressing: false) }
            else { self.drainExternalQueue() }
        }
        if let destinationPicker { destinationPicker(sources, completion); return }
        let panel = NSOpenPanel()
        panel.title = AppCopy.Label.destination
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.directoryURL = sources.first?.deletingLastPathComponent()
        panel.prompt = AppCopy.Label.startExtract; panel.message = AppCopy.Description.saveExtracted
        present(panel) { response in completion(response == .OK ? panel.url : nil) }
    }
    private func present(_ panel: NSSavePanel, completion: @escaping @MainActor (NSApplication.ModalResponse) -> Void) {
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
    private func start(sources: [URL], destination: URL, compressing: Bool) {
        guard !isWorking else { return }
        isWorking = true; cancelling = false; statusIsError = false; lastOutputs = []; progress = nil
        let jobID = UUID(); activeID = jobID
        let level = compressionLevel, exclude = excludeMetadata
        defaults.set(level.rawValue, forKey: "compressionLevel")
        defaults.set(exclude, forKey: "excludeMetadata"); defaults.set(revealWhenDone, forKey: "revealWhenDone")
        statusMessage = compressing ? AppCopy.Label.compressing : AppCopy.Label.extracting
        let callback: @Sendable (ArchiveProgress) -> Void = { [weak self] progress in
            Task { @MainActor in
                guard let self, self.isWorking, self.activeID == jobID, !self.cancelling else { return }
                self.progress = progress; self.statusDetail = progress.path
            }
        }
        task = Task {
            var failures: [String] = [], wasCancelled = false
            if compressing {
                let started = Date()
                do {
                    try await service.compress(sources: sources, to: destination, level: level, excludeMetadata: exclude, progress: callback)
                    record(output: destination, action: "压缩", started: started)
                } catch is CancellationError { wasCancelled = true }
                catch { failures.append(error.localizedDescription) }
            } else {
                for (index, source) in sources.enumerated() {
                    if Task.isCancelled { wasCancelled = true; break }
                    batchPosition = "\(index + 1) / \(sources.count)"; progress = nil
                    let started = Date()
                    do {
                        let output = try await service.extract(archive: source, to: destination, progress: callback)
                        record(output: output, action: "解压", started: started)
                    } catch is CancellationError { wasCancelled = true; break }
                    catch { failures.append("\(source.lastPathComponent)：\(error.localizedDescription)") }
                }
            }
            isWorking = false; cancelling = false; progress = nil; batchPosition = ""; task = nil
            statusIsError = !failures.isEmpty
            if !failures.isEmpty {
                statusMessage = "\(lastOutputs.count) 项完成，\(failures.count) 项失败"; statusDetail = failures.joined(separator: "\n")
            } else if wasCancelled {
                statusMessage = "已取消\(lastOutputs.isEmpty ? "" : "，已完成 \(lastOutputs.count) 项")"
                statusDetail = AppCopy.Description.cancelled
            } else {
                statusMessage = compressing ? AppCopy.Label.compressed : AppCopy.extractionFinished(lastOutputs.count)
                statusDetail = lastOutputs.first?.path ?? "处理完成"
                if revealWhenDone { revealResult() }
            }
            drainExternalQueue()
        }
    }
    func cancel() {
        guard isWorking, !cancelling else { return }
        cancelling = true; statusMessage = AppCopy.Label.cancelling; task?.cancel()
    }
    private func record(output: URL, action: String, started: Date) {
        lastOutputs.append(output)
        let bytes = (try? output.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])).flatMap { $0.isDirectory == true ? nil : $0.fileSize }
        history.insert(TaskRecord(id: UUID(), name: output.lastPathComponent, action: action, output: output,
                                  date: Date(), duration: Date().timeIntervalSince(started), outputBytes: bytes.map(Int64.init),
                                  bookmark: FileAccess.bookmark(for: output)), at: 0)
        history = Array(history.prefix(30))
        saveHistory()
    }
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) { defaults.set(data, forKey: "taskHistory") }
    }
    func clearHistory() { history = []; defaults.removeObject(forKey: "taskHistory") }
    func openExternally(_ urls: [URL]) { guard !terminating else { return }; externalQueue.append(contentsOf: urls.filter(\.isFileURL)); drainExternalQueue() }
    private func drainExternalQueue() {
        guard !terminating, !busy, !externalQueue.isEmpty else { return }
        var known = Set<URL>()
        let urls = externalQueue.filter { known.insert($0).inserted }; externalQueue = []
        let archives = urls.filter { ArchiveService.supports($0) }, other = urls.filter { !ArchiveService.supports($0) }
        if !archives.isEmpty {
            if !other.isEmpty { externalQueue.append(contentsOf: other) }
            section = .extract; chooseExtractionDestination(archives)
        } else { section = .compress; addURLs(other) }
    }
    func preview(_ item: ArchiveItem) {
        guard ArchiveService.supports(item.url), !item.isDirectory else { return }
        previewTask?.cancel(); previewTitle = item.url.lastPathComponent; previewManifest = nil; previewError = nil
        previewLoading = true; showingPreview = true
        previewTask = Task {
            do {
                let manifest = try await service.inspect(item.url)
                guard !Task.isCancelled else { return }
                previewManifest = manifest
            } catch is CancellationError { return }
            catch { previewError = error.localizedDescription }
            previewLoading = false
        }
    }
    func closePreview() { previewTask?.cancel(); showingPreview = false }
    func finishBeforeTermination() async {
        terminating = true; externalQueue = []; previewTask?.cancel()
        cancel()
        await task?.value
    }
}
