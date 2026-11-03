import XCTest
@testable import Yuya

@MainActor
final class ArchiveViewModelTests: XCTestCase {
    private func model() -> ArchiveViewModel {
        let suite = "YuyaTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return ArchiveViewModel(defaults: defaults, destinationPicker: { sources, completion in
            completion(sources.first?.deletingLastPathComponent())
        })
    }
    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("yuya-model-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }
    private func waitUntilIdle(_ vm: ArchiveViewModel) async throws {
        for _ in 0..<1000 {
            if !vm.busy { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Task did not finish")
    }
    func testImportsDeduplicateAndInvalidExtractionCannotStart() async throws {
        let vm = model(), root = try folder(), input = root.appendingPathComponent("中文文件.txt")
        try Data("hello".utf8).write(to: input)
        vm.addURLs([input, input])
        try await waitUntilIdle(vm)
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertTrue(vm.canRun)
        vm.section = .extract
        XCTAssertFalse(vm.canRun)
        vm.selection = [input]
        vm.removeSelection()
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertTrue(vm.selection.isEmpty)
    }
    func testExternalRequestsWhileBusyAreQueuedAndHistoryIsSaved() async throws {
        let vm = model(), root = try folder(), input = root.appendingPathComponent("input.txt")
        try Data("hello".utf8).write(to: input)
        let first = root.appendingPathComponent("first.zip"), second = root.appendingPathComponent("second.zip")
        let service = ArchiveService()
        try await service.compress(sources: [input], to: first)
        try await service.compress(sources: [input], to: second)
        vm.openExternally([first])
        XCTAssertTrue(vm.isWorking)
        vm.openExternally([second])
        try await waitUntilIdle(vm)
        XCTAssertEqual(vm.history.count, 2)
        XCTAssertFalse(vm.statusIsError)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("first/input.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("second/input.txt").path))
    }
    func testFailedArchiveDoesNotPreventOtherArchivesFromCompleting() async throws {
        let vm = model(), root = try folder(), input = root.appendingPathComponent("input.txt")
        try Data("hello".utf8).write(to: input)
        let good = root.appendingPathComponent("good.zip"), bad = root.appendingPathComponent("bad.zip")
        try await ArchiveService().compress(sources: [input], to: good)
        try Data("broken".utf8).write(to: bad)
        vm.openExternally([bad, good])
        try await waitUntilIdle(vm)
        XCTAssertTrue(vm.statusIsError)
        XCTAssertEqual(vm.history.count, 1)
        XCTAssertEqual(vm.lastOutputs.count, 1)
        XCTAssertTrue(vm.statusMessage.contains("1 项失败"))
    }
    func testOpenRequestDeliveryCanDrainDuringNotification() {
        let center = OpenRequestCenter()
        let one = URL(fileURLWithPath: "/tmp/one.zip"), two = URL(fileURLWithPath: "/tmp/two.zip")
        var delivered: [URL] = []
        let subscription = center.$revision.dropFirst().sink { _ in
            delivered.append(contentsOf: center.takePending())
        }
        center.enqueue([one])
        center.enqueue([two])
        XCTAssertEqual(delivered, [one, two])
        XCTAssertTrue(center.takePending().isEmpty)
        withExtendedLifetime(subscription) { }
    }

    func testExternalOpenWaitsForDestinationAndCancelWritesNothing() async throws {
        let root = try folder(), input = root.appendingPathComponent("input.txt")
        try Data("hello".utf8).write(to: input)
        let zip = root.appendingPathComponent("source.zip")
        try await ArchiveService().compress(sources: [input], to: zip)
        var finishPicking: (@MainActor (URL?) -> Void)?
        let vm = ArchiveViewModel(defaults: UserDefaults(suiteName: "YuyaTests.cancel.\(UUID())")!,
                                  destinationPicker: { _, completion in finishPicking = completion })
        vm.openExternally([zip])
        XCTAssertTrue(vm.choosingDestination)
        XCTAssertFalse(vm.isWorking)
        XCTAssertTrue(vm.history.isEmpty)
        finishPicking?(nil)
        try await waitUntilIdle(vm)
        XCTAssertTrue(vm.history.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("source").path))
    }

    func testOldHistoryWithoutBookmarksStillLoads() throws {
        let record = TaskRecord(id: UUID(), name: "old.zip", action: "压缩", output: URL(fileURLWithPath: "/tmp/old.zip"),
                                date: Date(), duration: 1, outputBytes: 10)
        let decoded = try JSONDecoder().decode(TaskRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded.output, record.output)
        XCTAssertNil(decoded.bookmark)
    }

}
