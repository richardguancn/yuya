import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: swift scripts/inspect_icon.swift /path/Yuya.app /path/icon.png\n", stderr)
    exit(1)
}

// Ask IconServices for the image Finder uses, rather than opening the source artwork.
// Use a freshly extracted application path to avoid a cached icon from an earlier build.
let icon = NSWorkspace.shared.icon(forFile: CommandLine.arguments[1])
let pixels = 512
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
