// Renders the 1024x1024 App Store icon: a white heart inside a speech bubble on the
// app's violet → pink gradient, with a sparkle. No alpha channel, as App Store Connect
// requires. Run: swift scripts/render-icon.swift Flirty/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon1024.png")
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Flip so y grows downward like a design tool.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: cs,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, a,
        ])!
}
func gradient(_ a: CGColor, _ b: CGColor) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: [a, b] as CFArray, locations: [0, 1])!
}

// Background: AppTheme.primaryGradient (violet #a78bfa → pink #ec4899), deepened a
// little so the white bubble reads at small sizes, plus a soft highlight top-left.
ctx.drawLinearGradient(
    gradient(rgb(0x8B6CF6), rgb(0xE0338A)), start: .zero, end: CGPoint(x: size, y: size), options: [])
ctx.drawRadialGradient(
    gradient(rgb(0xFFFFFF, 0.20), rgb(0xFFFFFF, 0)), startCenter: CGPoint(x: 220, y: 180), startRadius: 0,
    endCenter: CGPoint(x: 220, y: 180), endRadius: 900, options: [])

// Speech bubble with a tail at the bottom-left, drawn in one transparency layer so the
// shadow wraps bubble and tail together.
let bubble = CGRect(x: 152, y: 208, width: 720, height: 560)
let tail = CGMutablePath()
tail.move(to: CGPoint(x: bubble.minX + 120, y: bubble.maxY - 40))
tail.addQuadCurve(
    to: CGPoint(x: bubble.minX + 60, y: bubble.maxY + 120),
    control: CGPoint(x: bubble.minX + 110, y: bubble.maxY + 60))
tail.addQuadCurve(
    to: CGPoint(x: bubble.minX + 350, y: bubble.maxY - 40),
    control: CGPoint(x: bubble.minX + 230, y: bubble.maxY + 40))
tail.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0x3B1060, 0.35))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.setFillColor(rgb(0xFFFFFF))
ctx.addPath(CGPath(roundedRect: bubble, cornerWidth: 140, cornerHeight: 140, transform: nil))
ctx.fillPath()
ctx.addPath(tail)
ctx.fillPath()
ctx.endTransparencyLayer()
ctx.restoreGState()

// Heart centred in the bubble, filled with the background gradient.
func heart(center c: CGPoint, width w: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let h = w * 0.9
    let top = c.y - h * 0.35
    let bottom = c.y + h * 0.55
    p.move(to: CGPoint(x: c.x, y: bottom))
    p.addCurve(
        to: CGPoint(x: c.x - w / 2, y: top + h * 0.1),
        control1: CGPoint(x: c.x - w * 0.55, y: c.y + h * 0.15),
        control2: CGPoint(x: c.x - w / 2, y: c.y - h * 0.05))
    p.addArc(
        center: CGPoint(x: c.x - w / 4, y: top + h * 0.1), radius: w / 4, startAngle: .pi, endAngle: 0,
        clockwise: false)
    p.addArc(
        center: CGPoint(x: c.x + w / 4, y: top + h * 0.1), radius: w / 4, startAngle: .pi, endAngle: 0,
        clockwise: false)
    p.addCurve(
        to: CGPoint(x: c.x, y: bottom),
        control1: CGPoint(x: c.x + w / 2, y: c.y - h * 0.05),
        control2: CGPoint(x: c.x + w * 0.55, y: c.y + h * 0.15))
    p.closeSubpath()
    return p
}
ctx.saveGState()
ctx.addPath(heart(center: CGPoint(x: bubble.midX, y: bubble.midY - 10), width: 400))
ctx.clip()
ctx.drawLinearGradient(
    gradient(rgb(0xA78BFA), rgb(0xEC4899)), start: CGPoint(x: bubble.minX, y: bubble.minY),
    end: CGPoint(x: bubble.maxX, y: bubble.maxY), options: [])
ctx.restoreGState()

// Four-point sparkle.
func sparkle(center c: CGPoint, radius R: CGFloat, pinch: CGFloat = 0.22) -> CGPath {
    let p = CGMutablePath()
    let r = R * pinch
    let tips = (0..<4).map { i -> CGPoint in
        let a = CGFloat(i) * .pi / 2 - .pi / 2
        return CGPoint(x: c.x + R * cos(a), y: c.y + R * sin(a))
    }
    let dips = (0..<4).map { i -> CGPoint in
        let a = CGFloat(i) * .pi / 2 - .pi / 4
        return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
    }
    p.move(to: tips[0])
    for i in 0..<4 {
        p.addQuadCurve(to: tips[(i + 1) % 4], control: dips[i])
    }
    p.closeSubpath()
    return p
}
func drawSparkle(center: CGPoint, radius: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 24, color: rgb(0xFFB020, 0.55))
    ctx.addPath(sparkle(center: center, radius: radius))
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(rgb(0xFFE27A), rgb(0xFF9F1C)), start: CGPoint(x: center.x - radius, y: center.y - radius),
        end: CGPoint(x: center.x + radius, y: center.y + radius), options: [])
    ctx.restoreGState()
}
drawSparkle(center: CGPoint(x: 820, y: 220), radius: 140)
drawSparkle(center: CGPoint(x: 660, y: 150), radius: 48)
drawSparkle(center: CGPoint(x: 930, y: 410), radius: 44)

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write failed") }
print("wrote \(out.path)")
