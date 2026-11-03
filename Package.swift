// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Yuya",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CArchive", path: "Sources/CArchive", publicHeadersPath: "include", linkerSettings: [.linkedLibrary("archive")]),
        .executableTarget(name: "Yuya", dependencies: ["CArchive"], path: "Yuya", exclude: ["Info.plist", "Yuya.entitlements"], resources: [.copy("Resources/YuyaClownfish.icns"), .copy("PrivacyInfo.xcprivacy")]),
        .testTarget(name: "YuyaTests", dependencies: ["Yuya"], path: "Tests/YuyaTests")
    ]
)
