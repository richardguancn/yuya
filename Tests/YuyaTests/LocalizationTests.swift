import XCTest
@testable import Yuya

final class LocalizationTests: XCTestCase {
    func testLabelsAndDescriptionsAreNonEmpty() {
        XCTAssertFalse(AppCopy.Label.compress.isEmpty)
        XCTAssertFalse(AppCopy.Label.extract.isEmpty)
        XCTAssertFalse(AppCopy.Label.history.isEmpty)
        XCTAssertFalse(AppCopy.Label.startCompress.isEmpty)
        XCTAssertFalse(AppCopy.Label.startExtract.isEmpty)
        XCTAssertFalse(AppCopy.Label.location.isEmpty)
        XCTAssertFalse(AppCopy.Label.preview.isEmpty)
        XCTAssertFalse(AppCopy.Description.purpose.isEmpty)
        XCTAssertFalse(AppCopy.Description.local.isEmpty)
        XCTAssertFalse(AppCopy.Description.noUpload.isEmpty)
    }

    func testDynamicSummaries() {
        let addedSingle = AppCopy.itemsAdded(1)
        let addedMultiple = AppCopy.itemsAdded(3)
        XCTAssertFalse(addedSingle.isEmpty)
        XCTAssertFalse(addedMultiple.isEmpty)

        let finishSingle = AppCopy.extractionFinished(1)
        let finishMultiple = AppCopy.extractionFinished(2)
        XCTAssertFalse(finishSingle.isEmpty)
        XCTAssertFalse(finishMultiple.isEmpty)

        let folders = AppCopy.foldersSummary(2)
        XCTAssertFalse(folders.isEmpty)

        let items = AppCopy.itemsSummary(count: 5, size: "12 MB", hasFolders: true)
        XCTAssertFalse(items.isEmpty)
    }
}
