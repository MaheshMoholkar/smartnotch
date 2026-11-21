import AppKit

let artwork = URL(fileURLWithPath: CommandLine.arguments[1])
let folder = URL(fileURLWithPath: CommandLine.arguments[2])
guard let logo = NSImage(contentsOf: artwork) else {
    throw CocoaError(.fileReadCorruptFile, userInfo: [NSURLErrorKey: artwork])
}
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        context.imageInterpolation = .high
        NSGraphicsContext.current = context
        // Keep the standard inset around the tile at every macOS icon size.
        let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        let inset = CGFloat(pixels) / 16
        context.cgContext.clear(bounds)
        logo.draw(in: bounds.insetBy(dx: inset, dy: inset), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let suffix = scale == 2 ? "@2x" : ""
        let output = folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: output)
    }
}
