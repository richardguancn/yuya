import AppKit
import SwiftUI

// Render the actual SwiftUI product view off screen, using only sample files.
// This avoids including macOS's screen-sharing indicator or real user paths.
@main
struct StoreScreenshots {
    @MainActor
    static func main() async throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let document = root.appendingPathComponent("旅行计划.txt")
        let folder = root.appendingPathComponent("项目资料", isDirectory: true)
        try Data("整理行程和资料\n".utf8).write(to: document)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("示例文档\n".utf8).write(to: folder.appendingPathComponent("项目说明.txt"))
        let suite = "Yuya.StoreScreenshot.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = ArchiveViewModel(defaults: defaults)
        vm.addURLs([document, folder])
        while vm.busy { try await Task.sleep(for: .milliseconds(20)) }
        try save(vm, to: output.appendingPathComponent("01-compress.png"))
        let zip = root.appendingPathComponent("旅行资料.zip")
        if !FileManager.default.fileExists(atPath: zip.path) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            proc.arguments = ["-q", "-j", zip.path, document.path]
            try proc.run()
            proc.waitUntilExit()
        }
        vm.clear()
        vm.section = .extract
        vm.addURLs([zip])
        while vm.busy { try await Task.sleep(for: .milliseconds(20)) }
        try save(vm, to: output.appendingPathComponent("02-extract.png"))

        let sampleRecords = [
            TaskRecord(id: UUID(), name: "旅行资料.zip", action: "压缩", output: zip, date: Date().addingTimeInterval(-180), duration: 0.45, outputBytes: 15420, bookmark: nil),
            TaskRecord(id: UUID(), name: "设计稿归档.7z", action: "解压", output: folder, date: Date().addingTimeInterval(-1440), duration: 1.28, outputBytes: 2458000, bookmark: nil)
        ]
        let recordData = try JSONEncoder().encode(sampleRecords)
        defaults.set(recordData, forKey: "taskHistory")
        let historyVM = ArchiveViewModel(defaults: defaults)
        historyVM.section = .history
        try save(historyVM, to: output.appendingPathComponent("03-history.png"))
    }

    @MainActor
    static func save(_ vm: ArchiveViewModel, to url: URL) throws {
        let bounds = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let window = NSWindow(contentRect: bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: ContentView(vm: vm).frame(width: bounds.width, height: bounds.height))
        host.frame = bounds
        host.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: bounds) else { throw CocoaError(.fileWriteUnknown) }
        host.cacheDisplay(in: bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url)
        window.orderOut(nil)
    }
}
