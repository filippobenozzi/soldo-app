// Renders the Soldo app icon (1024x1024 PNG) with CoreGraphics.
// Usage: swift Tools/MakeIcon.swift <output.png>

import AppKit
import CoreGraphics
import Foundation

let size = 1024.0
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else { fatalError("Unable to create bitmap context") }

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// Background: diagonal gradient, deep green to emerald.
let backgroundGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [rgb(16, 92, 60), rgb(39, 174, 96), rgb(72, 199, 116)] as CFArray,
    locations: [0.0, 0.6, 1.0]
)!
ctx.drawLinearGradient(
    backgroundGradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: []
)

// Soft highlight in the upper-left corner.
let highlight = CGGradient(
    colorsSpace: colorSpace,
    colors: [rgb(255, 255, 255, 0.22), rgb(255, 255, 255, 0.0)] as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawRadialGradient(
    highlight,
    startCenter: CGPoint(x: size * 0.26, y: size * 0.80), startRadius: 0,
    endCenter: CGPoint(x: size * 0.26, y: size * 0.80), endRadius: size * 0.62,
    options: []
)

// The coin.
let coinCenter = CGPoint(x: size / 2, y: size / 2)
let coinRadius = size * 0.305

// Drop shadow under the coin.
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -size * 0.018),
    blur: size * 0.06,
    color: rgb(0, 40, 20, 0.45)
)
ctx.setFillColor(rgb(255, 255, 255))
ctx.addArc(center: coinCenter, radius: coinRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.fillPath()
ctx.restoreGState()

// Inner rim.
ctx.setStrokeColor(rgb(39, 174, 96, 0.30))
ctx.setLineWidth(size * 0.020)
ctx.addArc(center: coinCenter, radius: coinRadius * 0.865, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

// Euro glyph, drawn as a text layer so it stays crisp.
let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsContext

let glyph = "€"
let font = NSFont.systemFont(ofSize: size * 0.40, weight: .bold)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(srgbRed: 16 / 255, green: 92 / 255, blue: 60 / 255, alpha: 1),
]
let attributed = NSAttributedString(string: glyph, attributes: attributes)
let glyphSize = attributed.size()
attributed.draw(
    at: CGPoint(
        x: coinCenter.x - glyphSize.width / 2,
        y: coinCenter.y - glyphSize.height / 2 + size * 0.012
    )
)

NSGraphicsContext.restoreGraphicsState()

guard let image = ctx.makeImage() else { fatalError("Unable to render image") }
let rep = NSBitmapImageRep(cgImage: image)
rep.size = NSSize(width: size, height: size)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
try data.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath) (\(data.count) bytes)")
