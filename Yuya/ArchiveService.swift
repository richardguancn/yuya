import Foundation
import CArchive
import Darwin

enum ArchiveError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}

enum CompressionLevel: Int, CaseIterable, Identifiable, Sendable {
    case fast = 1, balanced = 6, small = 9
    var id: Int { rawValue }
    var title: String {
        switch self { case .fast: AppCopy.Label.fast; case .balanced: AppCopy.Label.balanced; case .small: AppCopy.Label.small }
    }
    var detail: String {
        switch self {
        case .fast: AppCopy.Description.fast
        case .balanced: AppCopy.Description.balanced
        case .small: AppCopy.Description.small
        }
    }
}

struct ArchiveEntry: Identifiable, Sendable {
    let id: Int64
    let path: String
    let size: Int64
    let isDirectory: Bool
}
struct ArchiveManifest: Sendable {
    let entries: [ArchiveEntry]
    let count: Int64
    let totalBytes: Int64?
    var isTruncated: Bool { count > entries.count }
}
struct ArchiveProgress: Sendable {
    let path: String
    let bytes: Int64
    let count: Int64
}

private final class ArchiveContext: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var entries: [ArchiveEntry] = []
    var count: Int64 = 0
    var totalBytes: Int64 = 0
    var unknownSize = false
    var lastUpdate = Date.distantPast
    let collecting: Bool
    let progress: @Sendable (ArchiveProgress) -> Void
    init(collecting: Bool = false, progress: @escaping @Sendable (ArchiveProgress) -> Void = { _ in }) {
        self.collecting = collecting
        self.progress = progress
    }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func update(path: String, bytes: Int64, count: Int64, directory: Bool) -> Int32 {
        if isCancelled { return 1 }
        if collecting {
            self.count = count
            if bytes < 0 { unknownSize = true } else { totalBytes += bytes }
            if entries.count < 10000 { entries.append(ArchiveEntry(id: count, path: path, size: bytes, isDirectory: directory)) }
        } else if Date().timeIntervalSince(lastUpdate) >= 0.1 {
            lastUpdate = Date()
            progress(ArchiveProgress(path: path, bytes: bytes, count: count))
        }
        return 0
    }
}

private let archiveCallback: yuya_callback = { raw, path, bytes, count, directory in
    guard let raw else { return 1 }
    let context = Unmanaged<ArchiveContext>.fromOpaque(raw).takeUnretainedValue()
    return context.update(path: path.map { String(cString: $0) } ?? "", bytes: bytes, count: count, directory: directory != 0)
}

struct ArchiveService: Sendable {
    static let extensions = ["zip", "7z", "rar", "tar", "tgz", "tbz", "tbz2", "txz", "gz", "bz2", "xz"]
    static func supports(_ url: URL) -> Bool { extensions.contains(url.pathExtension.lowercased()) }
    static func outputName(for url: URL) -> String {
        var name = url.deletingPathExtension().lastPathComponent
        if ["gz", "bz2", "xz"].contains(url.pathExtension.lowercased()), name.lowercased().hasSuffix(".tar") {
            name = String(name.dropLast(4))
        }
        return name.isEmpty ? "解压文件" : name
    }

    func inspect(_ url: URL) async throws -> ArchiveManifest {
        let access = FileAccess([url])
        defer { withExtendedLifetime(access) {} }
        let context = ArchiveContext(collecting: true)
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                var error = [CChar](repeating: 0, count: 4096)
                let result = yuya_inspect(url.path, archiveCallback, Unmanaged.passUnretained(context).toOpaque(), &error, error.count)
                try check(result, error: error, context: context)
                return ArchiveManifest(entries: context.entries, count: context.count, totalBytes: context.unknownSize ? nil : context.totalBytes)
            }.value
        } onCancel: { context.cancel() }
    }

    func compress(sources: [URL], to destination: URL, level: CompressionLevel = .balanced,
                  excludeMetadata: Bool = true, progress: @escaping @Sendable (ArchiveProgress) -> Void = { _ in }) async throws {
        let access = FileAccess(sources + [destination])
        defer { withExtendedLifetime(access) {} }
        let context = ArchiveContext(progress: progress)
        try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                let sources = try normalizedSources(sources, destination: destination)
                // NSSavePanel grants the chosen file, not arbitrary siblings in its folder.
                // Foundation provides a writable staging directory on the destination volume.
                let staging = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                         appropriateFor: destination, create: true)
                defer { try? fm.removeItem(at: staging) }
                try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: staging.path)
                let temporary = staging.appendingPathComponent("archive.zip")
                var error = [CChar](repeating: 0, count: 4096)
                let strings = sources.map { strdup($0.path) }
                defer { strings.forEach { free($0) } }
                let pointers = strings.map { UnsafePointer<CChar>($0) }
                let result = pointers.withUnsafeBufferPointer {
                    yuya_compress($0.baseAddress, $0.count, temporary.path, Int32(level.rawValue), excludeMetadata ? 1 : 0,
                                  archiveCallback, Unmanaged.passUnretained(context).toOpaque(), &error, error.count)
                }
                try check(result, error: error, context: context)
                // POSIX rename replaces the destination atomically only after a complete archive exists.
                guard Darwin.rename(temporary.path, destination.path) == 0 else {
                    throw ArchiveError.message("\(AppCopy.Description.saveFailed)\n\(String(cString: strerror(errno)))")
                }
            }.value
        } onCancel: { context.cancel() }
    }

    /// Always publish a new folder. Existing output and partially extracted data are never merged.
    func extract(archive: URL, to parent: URL,
                 progress: @escaping @Sendable (ArchiveProgress) -> Void = { _ in }) async throws -> URL {
        let access = FileAccess([archive, parent])
        defer { withExtendedLifetime(access) {} }
        let context = ArchiveContext(progress: progress)
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                let staging = parent.appendingPathComponent(".yuya-\(UUID().uuidString)", isDirectory: true)
                try fm.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                defer { try? fm.removeItem(at: staging) }
                var error = [CChar](repeating: 0, count: 4096)
                let result = yuya_extract(archive.path, staging.resolvingSymlinksInPath().path, archiveCallback,
                                          Unmanaged.passUnretained(context).toOpaque(), &error, error.count)
                try check(result, error: error, context: context)
                let base = Self.outputName(for: archive)
                for suffix in 0..<10000 {
                    let name = suffix == 0 ? base : "\(base) \(suffix + 1)"
                    let target = parent.appendingPathComponent(name, isDirectory: true)
                    // RENAME_EXCL closes the race between checking a name and publishing the folder.
                    if renamex_np(staging.path, target.path, UInt32(RENAME_EXCL)) == 0 { return target }
                    guard errno == EEXIST else {
                        throw ArchiveError.message("\(AppCopy.Description.saveFailed)\n\(String(cString: strerror(errno)))")
                    }
                }
                throw ArchiveError.message(AppCopy.Description.tooManyFolders)
            }.value
        } onCancel: { context.cancel() }
    }

    private func check(_ result: Int32, error: [CChar], context: ArchiveContext) throws {
        if result == 1 || context.isCancelled { throw CancellationError() }
        if result != 0 {
            let detail = error.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
            if detail.localizedCaseInsensitiveContains("passphrase") || detail.localizedCaseInsensitiveContains("encrypted") {
                throw ArchiveError.message(AppCopy.Description.needsPassword)
            }
            if detail.isEmpty { throw ArchiveError.message(AppCopy.Description.archiveFailed) }
            if detail.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) }) {
                throw ArchiveError.message(detail)
            }
            let explanation: String
            if detail.localizedCaseInsensitiveContains("space") { explanation = AppCopy.Description.noSpace }
            else if ["permission", "read-only", "denied"].contains(where: { detail.localizedCaseInsensitiveContains($0) }) { explanation = AppCopy.Description.noAccess }
            else if ["format", "truncated", "damaged", "crc", "corrupt"].contains(where: { detail.localizedCaseInsensitiveContains($0) }) { explanation = AppCopy.Description.unsupported }
            else { explanation = AppCopy.Description.unknownFailure }
            throw ArchiveError.message("\(explanation)\n\(detail)")
        }
    }

    private func normalizedSources(_ sources: [URL], destination: URL) throws -> [URL] {
        guard !sources.isEmpty else { throw ArchiveError.message(AppCopy.Description.noSources) }
        let fm = FileManager.default
        let unique = Array(Set(sources.map { $0.standardizedFileURL })).sorted { $0.path < $1.path }
        let resolvedDestination = destination.resolvingSymlinksInPath().standardizedFileURL.path
        var roots: [URL] = []
        var names = Set<String>()
        for source in unique {
            guard fm.fileExists(atPath: source.path) else { throw ArchiveError.message("\(AppCopy.Description.sourceMissing)\n\(source.lastPathComponent)") }
            let resolved = source.resolvingSymlinksInPath().standardizedFileURL.path
            let isDirectory = (try source.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true
            guard resolved != resolvedDestination && !(isDirectory && resolvedDestination.hasPrefix(resolved + "/")) else {
                throw ArchiveError.message(AppCopy.Description.sameOutput)
            }
            if roots.contains(where: { source.path.hasPrefix($0.path + "/") }) { continue }
            let key = source.lastPathComponent.precomposedStringWithCanonicalMapping.lowercased()
            guard names.insert(key).inserted else { throw ArchiveError.message("\(AppCopy.Description.duplicates)\n\(source.lastPathComponent)") }
            guard source.path != "/" else { throw ArchiveError.message(AppCopy.Description.disk) }
            roots.append(source)
        }
        return roots
    }
}
