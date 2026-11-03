import AppKit

@MainActor
enum AppIcon {
    static let image: NSImage? = {
        if usesSystemRendering(in: .main) {
            return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        }
        if let image = load(from: .main) { return image }
        #if SWIFT_PACKAGE
        // `swift run` has no application Info.plist. Its resource bundle still carries the icon.
        if let url = Bundle.module.url(forResource: "YuyaClownfish", withExtension: "icns"),
           let image = NSImage(contentsOf: url), image.isValid { return image }
        #endif
        return nil
    }()

    /// Use the same declared resource for the Dock and the in-window artwork.
    static func load(from bundle: Bundle) -> NSImage? {
        guard let filename = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
              !filename.isEmpty else { return nil }
        let path = filename as NSString
        let name = path.pathExtension.isEmpty ? filename : path.deletingPathExtension
        let ext = path.pathExtension.isEmpty ? "icns" : path.pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext),
              let image = NSImage(contentsOf: url), image.isValid else { return nil }
        return image
    }

    static func usesSystemRendering(in bundle: Bundle) -> Bool {
        bundle.object(forInfoDictionaryKey: "CFBundleIconName") is String &&
            bundle.url(forResource: "Assets", withExtension: "car") != nil
    }

    static func apply(to application: NSApplication) {
        // Native icon compositions must be rendered by IconServices. Replacing them with
        // a pre-rendered image makes newer macOS wrap that image in another tile.
        if usesSystemRendering(in: .main) { return }
        guard let image else { return }
        application.applicationIconImage = image
        application.dockTile.display()
    }
}
