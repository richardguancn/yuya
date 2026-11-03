import XCTest
import AppKit
@testable import Yuya

@MainActor
final class AppIconTests: XCTestCase {
    private func bundle(iconName: String, includeIcon: Bool) throws -> Bundle {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("yuya-icon-\(UUID().uuidString).app")
        let resources = folder.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let plist: [String: Any] = ["CFBundleIdentifier": "com.gdy.yuya.icon-test.\(UUID().uuidString)",
                                     "CFBundlePackageType": "APPL", "CFBundleIconFile": iconName]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: folder.appendingPathComponent("Contents/Info.plist"))
        if includeIcon {
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("Yuya/Resources/YuyaClownfish.icns")
            try FileManager.default.copyItem(at: source, to: resources.appendingPathComponent("YuyaClownfish.icns"))
        }
        return try XCTUnwrap(Bundle(url: folder))
    }

    func testDeclaredIconLoadsWithExplicitExtension() throws {
        let image = try XCTUnwrap(AppIcon.load(from: try bundle(iconName: "YuyaClownfish.icns", includeIcon: true)))
        XCTAssertTrue(image.isValid)
        XCTAssertGreaterThanOrEqual(image.size.width, 512)
        XCTAssertFalse(image.representations.isEmpty)
    }

    func testDeclaredIconLoadsWithoutExtension() throws {
        XCTAssertNotNil(AppIcon.load(from: try bundle(iconName: "YuyaClownfish", includeIcon: true)))
    }

    func testMissingIconIsDetected() throws {
        XCTAssertNil(AppIcon.load(from: try bundle(iconName: "YuyaClownfish.icns", includeIcon: false)))
    }
    func testSwiftPackageCarriesAUsableIcon() throws {
        let image = try XCTUnwrap(AppIcon.image)
        XCTAssertTrue(image.isValid)
        XCTAssertGreaterThanOrEqual(image.size.width, 512)
    }

}
