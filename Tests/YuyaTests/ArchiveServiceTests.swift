import XCTest
@testable import Yuya

final class ArchiveServiceTests: XCTestCase, @unchecked Sendable {
    let service = ArchiveService()
    func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("yuya-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    func file(_ name: String, in folder: URL, content: String = "你好，Yuya。\n") throws -> URL {
        let url = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
        return url
    }
    func command(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
    func python(_ code: String, _ arguments: [String]) throws { try command("/usr/bin/python3", ["-c", code] + arguments) }
    func assertNoStaging(_ folder: URL) throws {
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: folder.path).contains { $0.hasPrefix(".yuya-") })
    }

    func testRoundTripUnicodeSpacesEmptyDirectoriesAndMultipleParents() async throws {
        let root = try temporary()
        let one = try file("甲/中文 文件.txt", in: root)
        let two = try file("乙/-report.txt", in: root, content: "report")
        let empty = root.appendingPathComponent("空文件夹")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        let zip = root.appendingPathComponent("包.zip")
        try await service.compress(sources: [one, two, empty], to: zip)
        let manifest = try await service.inspect(zip)
        XCTAssertEqual(manifest.count, 3)
        XCTAssertEqual(Set(manifest.entries.map(\.path)), Set(["中文 文件.txt", "-report.txt", "空文件夹/"]))
        let output = try await service.extract(archive: zip, to: root)
        XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent("中文 文件.txt")), try Data(contentsOf: one))
        XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent("-report.txt")), try Data(contentsOf: two))
        try command("/usr/bin/unzip", ["-t", zip.path])
        try assertNoStaging(root)
    }
    func testFolderAndNestedSelectionAreNotDuplicated() async throws {
        let root = try temporary()
        let child = try file("folder/deep/file.txt", in: root)
        let zip = root.appendingPathComponent("archive.zip")
        try await service.compress(sources: [child, root.appendingPathComponent("folder"), child], to: zip)
        let manifest = try await service.inspect(zip)
        XCTAssertEqual(manifest.entries.filter { $0.path.hasSuffix("file.txt") }.count, 1)
        _ = try await service.extract(archive: zip, to: root)
    }
    func testDuplicateNamesRejectAndPreserveExistingArchive() async throws {
        let root = try temporary()
        let one = try file("a/file.txt", in: root), two = try file("b/FILE.txt", in: root)
        let zip = try file("original.zip", in: root, content: "KEEP")
        do { try await service.compress(sources: [one, two], to: zip); XCTFail("Expected duplicate rejection") }
        catch { XCTAssertTrue(error.localizedDescription.contains("同名")) }
        XCTAssertEqual(try String(contentsOf: zip, encoding: .utf8), "KEEP")
        try assertNoStaging(root)
    }
    func testOutputInsideSourceAndSameAsSourceAreRejected() async throws {
        let root = try temporary()
        let source = try file("folder/input.txt", in: root)
        for destination in [source, root.appendingPathComponent("folder/output.zip")] {
            do { try await service.compress(sources: [root.appendingPathComponent("folder")], to: destination); XCTFail("Expected rejection") }
            catch { XCTAssertTrue(error.localizedDescription.contains("源文件")) }
        }
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "你好，Yuya。\n")
    }
    func testMetadataPreference() async throws {
        let root = try temporary()
        _ = try file("folder/.DS_Store", in: root)
        _ = try file("folder/._secret", in: root)
        _ = try file("folder/__MACOSX/metadata", in: root)
        _ = try file("folder/normal.txt", in: root)
        let source = root.appendingPathComponent("folder")
        for exclude in [true, false] {
            let zip = root.appendingPathComponent("\(exclude).zip")
            try await service.compress(sources: [source], to: zip, excludeMetadata: exclude)
            let manifest = try await service.inspect(zip)
            XCTAssertEqual(manifest.entries.contains { $0.path.contains(".DS_Store") }, !exclude)
            XCTAssertEqual(manifest.entries.contains { $0.path.contains("metadata") }, !exclude)
        }
    }
    func testExtractionNeverOverwritesExistingFolder() async throws {
        let root = try temporary()
        let source = try file("source.txt", in: root, content: "NEW")
        let zip = root.appendingPathComponent("output.zip")
        try await service.compress(sources: [source], to: zip)
        let original = try file("output/source.txt", in: root, content: "OLD")
        let result = try await service.extract(archive: zip, to: root)
        XCTAssertEqual(result.lastPathComponent, "output 2")
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "OLD")
        XCTAssertEqual(try String(contentsOf: result.appendingPathComponent("source.txt"), encoding: .utf8), "NEW")
    }
    func testCorruptArchiveLeavesNoOutput() async throws {
        let root = try temporary()
        let archive = try file("broken.zip", in: root, content: "not a zip")
        do { _ = try await service.extract(archive: archive, to: root); XCTFail("Expected failure") } catch { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("broken").path))
        try assertNoStaging(root)
    }
    func testTraversalAndAbsolutePathsAreRejected() async throws {
        let root = try temporary()
        for (index, path) in ["../escaped.txt", "/tmp/yuya-escaped.txt", "C:\\escaped.txt", "folder/../../escaped.txt"].enumerated() {
            let zip = root.appendingPathComponent("bad\(index).zip")
            try python("import zipfile,sys; z=zipfile.ZipFile(sys.argv[1],'w'); z.writestr(sys.argv[2],b'bad'); z.close()", [zip.path, path])
            do { _ = try await service.extract(archive: zip, to: root); XCTFail("Expected unsafe path rejection") }
            catch { XCTAssertTrue(error.localizedDescription.contains("不安全")) }
        }
        try assertNoStaging(root)
    }
    func testSymlinkEscapeIsRejectedAndInternalLinkRoundTrips() async throws {
        let root = try temporary()
        _ = try file("folder/file.txt", in: root)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("folder/sub"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: root.appendingPathComponent("folder/sub/link").path, withDestinationPath: "../file.txt")
        let zip = root.appendingPathComponent("links.zip")
        try await service.compress(sources: [root.appendingPathComponent("folder")], to: zip)
        let output = try await service.extract(archive: zip, to: root)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: output.appendingPathComponent("folder/sub/link").path), "../file.txt")
        let bad = root.appendingPathComponent("bad.tar")
        try python("import tarfile,sys; t=tarfile.open(sys.argv[1],'w'); e=tarfile.TarInfo('escape'); e.type=tarfile.SYMTYPE; e.linkname='../outside'; t.addfile(e); t.close()", [bad.path])
        do { _ = try await service.extract(archive: bad, to: root); XCTFail("Expected link rejection") } catch { }
        try assertNoStaging(root)
    }
    func testCancellationPreservesPreviousOutputAndCleansTemporaryFiles() async throws {
        let root = try temporary()
        let source = root.appendingPathComponent("large.bin")
        // Incompressible input keeps the worker active long enough to cancel deterministically.
        try python("import os,sys; f=open(sys.argv[1],'wb'); [f.write(os.urandom(1024*1024)) for _ in range(32)]; f.close()", [source.path])
        let destination = try file("existing.zip", in: root, content: "ORIGINAL")
        let job = Task { try await service.compress(sources: [source], to: destination, level: .small) }
        try await Task.sleep(for: .milliseconds(30))
        job.cancel()
        do { try await job.value; XCTFail("Expected cancellation") } catch is CancellationError { }
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "ORIGINAL")
        try assertNoStaging(root)
    }
    func testTarGzipBzipAndXZ() async throws {
        let root = try temporary()
        try python("import tarfile,io,sys; p=sys.argv[1]; data=b'hello'; [(lambda t: (t.addfile((lambda e: (setattr(e,'size',len(data)),e)[1])(tarfile.TarInfo('file.txt')),io.BytesIO(data)),t.close()))(tarfile.open(p+'/bundle.'+ext,mode)) for ext,mode in [('tar','w'),('tgz','w:gz'),('tbz2','w:bz2'),('txz','w:xz')]]", [root.path])
        for ext in ["tar", "tgz", "tbz2", "txz"] {
            let archive = root.appendingPathComponent("bundle.\(ext)")
            let manifest = try await service.inspect(archive)
            XCTAssertEqual(manifest.count, 1)
            let result = try await service.extract(archive: archive, to: root)
            XCTAssertEqual(try String(contentsOf: result.appendingPathComponent("file.txt"), encoding: .utf8), "hello")
        }
    }
    func testStandaloneCompressedFilesKeepTheirName() async throws {
        let root = try temporary()
        try python("import gzip,bz2,lzma,sys; [(lambda f: (f.write(b'hello'),f.close()))(mod.open(sys.argv[1]+'/note.txt.'+ext,'wb')) for ext,mod in [('gz',gzip),('bz2',bz2),('xz',lzma)]]", [root.path])
        for ext in ["gz", "bz2", "xz"] {
            let archive = root.appendingPathComponent("note.txt.\(ext)")
            let result = try await service.extract(archive: archive, to: root)
            XCTAssertEqual(try String(contentsOf: result.appendingPathComponent("note.txt"), encoding: .utf8), "hello")
        }
    }
    func testPreviewLimitStillCountsAllEntries() async throws {
        let root = try temporary(), zip = root.appendingPathComponent("many.zip")
        try python("import zipfile,sys; z=zipfile.ZipFile(sys.argv[1],'w'); [z.writestr(str(i)+'.txt',b'x') for i in range(10005)]; z.close()", [zip.path])
        let manifest = try await service.inspect(zip)
        XCTAssertEqual(manifest.entries.count, 10000)
        XCTAssertEqual(manifest.count, 10005)
        XCTAssertEqual(manifest.totalBytes, 10005)
        XCTAssertTrue(manifest.isTruncated)
    }
    func testMissingSourceAndEmptySelectionPreserveOutput() async throws {
        let root = try temporary(), output = try file("original.zip", in: root, content: "KEEP")
        for sources in [[], [root.appendingPathComponent("missing")]] {
            do { try await service.compress(sources: sources, to: output); XCTFail("Expected input rejection") } catch { }
        }
        XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "KEEP")
    }
    func testRARAnd7ZipFixtures() async throws {
        let root = try temporary()
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")
        let rar = fixtures.appendingPathComponent("rar.rar"), seven = fixtures.appendingPathComponent("7zip.7z")
        let rarManifest = try await service.inspect(rar)
        XCTAssertEqual(rarManifest.count, 5)
        let rarOutput = try await service.extract(archive: rar, to: root)
        XCTAssertEqual(try String(contentsOf: rarOutput.appendingPathComponent("test.txt"), encoding: .utf8), "test text document\r\n")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: rarOutput.appendingPathComponent("testlink").path), "test.txt")
        let manifest = try await service.inspect(seven)
        XCTAssertEqual(manifest.count, 1)
        let sevenOutput = try await service.extract(archive: seven, to: root)
        XCTAssertEqual(try Data(contentsOf: sevenOutput.appendingPathComponent("file1")).count, 60)
    }
    func testCancelExtractionCleansUpAndKeepsExistingFiles() async throws {
        let root = try temporary(), zip = root.appendingPathComponent("large.zip")
        try python("import zipfile,sys; z=zipfile.ZipFile(sys.argv[1],'w'); z.writestr('large.bin', b'x'*(64*1024*1024)); z.close()", [zip.path])
        let original = try file("large/original.txt", in: root, content: "KEEP")
        let job = Task { try await service.extract(archive: zip, to: root) }
        job.cancel()
        do { _ = try await job.value; XCTFail("Expected cancellation") } catch is CancellationError { }
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "KEEP")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("large 2").path))
        try assertNoStaging(root)
    }
    func testEmptyZipAndSafeHardlink() async throws {
        let root = try temporary(), zip = root.appendingPathComponent("empty.zip"), tar = root.appendingPathComponent("hardlink.tar")
        try python("import zipfile,sys; zipfile.ZipFile(sys.argv[1],'w').close()", [zip.path])
        let manifest = try await service.inspect(zip)
        XCTAssertEqual(manifest.count, 0)
        let empty = try await service.extract(archive: zip, to: root)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: empty.path).isEmpty)
        try python("import tarfile,io,sys; t=tarfile.open(sys.argv[1],'w'); e=tarfile.TarInfo('file.txt'); e.size=5; t.addfile(e,io.BytesIO(b'hello')); e=tarfile.TarInfo('link.txt'); e.type=tarfile.LNKTYPE; e.linkname='file.txt'; t.addfile(e); t.close()", [tar.path])
        let output = try await service.extract(archive: tar, to: root)
        XCTAssertEqual(try String(contentsOf: output.appendingPathComponent("link.txt"), encoding: .utf8), "hello")
    }

    func testSymlinkCannotEscapeUsingRedundantPathComponents() async throws {
        let root = try temporary(), archive = root.appendingPathComponent("redundant.tar")
        try python("import tarfile,sys; t=tarfile.open(sys.argv[1],'w'); e=tarfile.TarInfo('safe//./link'); e.type=tarfile.SYMTYPE; e.linkname='../../outside'; t.addfile(e); t.close()", [archive.path])
        do { _ = try await service.extract(archive: archive, to: root); XCTFail("Expected unsafe link rejection") }
        catch { XCTAssertTrue(error.localizedDescription.contains("不安全")) }
        try assertNoStaging(root)
    }

}
