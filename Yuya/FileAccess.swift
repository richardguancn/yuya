import Foundation

/// Keeps explicit file access alive across detached work and balances every grant.
final class FileAccess: @unchecked Sendable {
    private let urls: [URL]
    init(_ urls: [URL]) {
        self.urls = urls.filter { $0.startAccessingSecurityScopedResource() }
    }
    deinit { urls.forEach { $0.stopAccessingSecurityScopedResource() } }

    static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolve(_ data: Data) throws -> URL {
        var stale = false
        return try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                       relativeTo: nil, bookmarkDataIsStale: &stale)
    }
}
