// Generates Resources/Focusbeam.icns: a black square with a white circle
// in the top-left corner and "focus beam" set in monospace bottom-right.
// Run from the repo root: swift Scripts/make-icon.swift

import AppKit

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(pixels)
    NSColor(calibratedWhite: 0.07, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: s, height: s).fill()

    let r = s * 0.14
    let circle = NSBezierPath(ovalIn: NSRect(x: s * 0.26 - r, y: s * 0.73 - r,
                                             width: 2 * r, height: 2 * r))
    NSColor.white.setFill()
    circle.fill()

    // text is an illegible smear below 64px, leave it off there
    if pixels >= 64 {
        let font = NSFont(name: "Courier", size: s * 0.15)
            ?? NSFont.monospacedSystemFont(ofSize: s * 0.15, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font,
                                                    .foregroundColor: NSColor.white]
        let margin = s * 0.07
        var baseline = s * 0.08
        for line in ["beam", "focus"] {
            let text = NSAttributedString(string: line, attributes: attrs)
            text.draw(at: NSPoint(x: s - margin - text.size().width, y: baseline))
            baseline += font.pointSize * 1.15
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = URL(fileURLWithPath: "Focusbeam.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for (suffix, scale) in [("", 1), ("@2x", 2)] {
        let rep = drawIcon(pixels: base * scale)
        let png = rep.representation(using: .png, properties: [:])!
        try png.write(to: iconset.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/Focusbeam.icns"]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed")
}
try FileManager.default.removeItem(at: iconset)
print("wrote Resources/Focusbeam.icns")
