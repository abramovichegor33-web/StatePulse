import AppKit

func createIconImage(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.224 // macOS standard squircle radius

    // Background squircle: Dark Charcoal #18181A
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1.0).setFill()
    bgPath.fill()

    // Inner subtle border
    let borderPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.015, dy: size * 0.015), xRadius: cornerRadius * 0.98, yRadius: cornerRadius * 0.98)
    NSColor(white: 1.0, alpha: 0.08).setStroke()
    borderPath.lineWidth = size * 0.015
    borderPath.stroke()

    // Pulse Wave Graphic in center
    let wavePath = NSBezierPath()
    let midY = size * 0.5
    let w = size

    wavePath.move(to: NSPoint(x: w * 0.18, y: midY))
    wavePath.line(to: NSPoint(x: w * 0.35, y: midY))
    wavePath.line(to: NSPoint(x: w * 0.42, y: midY + size * 0.22))
    wavePath.line(to: NSPoint(x: w * 0.52, y: midY - size * 0.22))
    wavePath.line(to: NSPoint(x: w * 0.60, y: midY + size * 0.12))
    wavePath.line(to: NSPoint(x: w * 0.66, y: midY))
    wavePath.line(to: NSPoint(x: w * 0.82, y: midY))

    wavePath.lineCapStyle = .round
    wavePath.lineJoinStyle = .round
    wavePath.lineWidth = max(1.5, size * 0.055)

    // Soft white glow
    NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 0.95).setStroke()
    wavePath.stroke()

    img.unlockFocus()
    return img
}

let iconsetDir = "Assets/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in sizes {
    let img = createIconImage(size: size)
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: "\(iconsetDir)/\(filename)")
        try? png.write(to: url)
    }
}
print("Iconset created successfully.")
