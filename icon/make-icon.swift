// Draws the app icon. Usage: swift make-icon.swift <iconset dir> <preview png>
// Run via `make icon`, which also turns the iconset into AppIcon.icns.
import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// Draws in a 1024×1024 space, following Apple's macOS icon grid (824pt rounded square).
func drawIcon() {
    let background = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0x2A62E8).setFill()
    background.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0x5FA4FF), ending: color(0x1D4FD1))!.draw(in: background, angle: -90)

    // Almond-shaped eye: two quadratic curves between the corners, converted to cubic.
    let left = NSPoint(x: 232, y: 512), right = NSPoint(x: 792, y: 512)
    let eye = NSBezierPath()
    eye.move(to: left)
    for controlY in [812.0, 212.0] {
        let (from, to) = controlY > 512 ? (left, right) : (right, left)
        let control = NSPoint(x: 512, y: controlY)
        eye.curve(to: to,
                  controlPoint1: NSPoint(x: from.x + 2 / 3 * (control.x - from.x), y: from.y + 2 / 3 * (control.y - from.y)),
                  controlPoint2: NSPoint(x: to.x + 2 / 3 * (control.x - to.x), y: to.y + 2 / 3 * (control.y - to.y)))
    }
    eye.close()
    NSColor.white.setFill()
    eye.fill()

    let iris = NSBezierPath(ovalIn: NSRect(x: 512 - 135, y: 512 - 135, width: 270, height: 270))
    NSGradient(starting: color(0x3B7BFF), ending: color(0x0B2E8A))!.draw(in: iris, angle: -90)
    color(0x0A1330).setFill()
    NSBezierPath(ovalIn: NSRect(x: 512 - 60, y: 512 - 60, width: 120, height: 120)).fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 552 - 26, y: 552 - 26, width: 52, height: 52)).fill()
}

func writePNG(size: Int, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let iconset = CommandLine.arguments[1]
for size in [16, 32, 128, 256, 512] {
    writePNG(size: size, to: "\(iconset)/icon_\(size)x\(size).png")
    writePNG(size: size * 2, to: "\(iconset)/icon_\(size)x\(size)@2x.png")
}
writePNG(size: 256, to: CommandLine.arguments[2])
