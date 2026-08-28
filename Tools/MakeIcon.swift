// Renders the Soldo app icon (1024x1024 PNG) with CoreGraphics.
// Monochrome, matching the app's ink-on-paper palette: a tilted coin bearing a euro sign.
// Usage: swift Tools/MakeIcon.swift <output.png>

import AppKit
import CoreGraphics
import Foundation

let size = 1024.0
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else { fatalError("Unable to create bitmap context") }

func grey(_ value: Double, _ alpha: Double = 1) -> CGColor {
    CGColor(srgbRed: value, green: value, blue: value, alpha: alpha)
}

// Paper background.
ctx.setFillColor(grey(0.984))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Coin geometry: a circle seen at an angle, so the face is a tall ellipse.
let centre = CGPoint(x: size * 0.485, y: size * 0.5)
let radiusX = size * 0.230
let radiusY = size * 0.370
let depth = size * 0.150

let faceCentre = CGPoint(x: centre.x - depth / 2, y: centre.y)
let backCentre = CGPoint(x: centre.x + depth / 2, y: centre.y)

func ellipseRect(at point: CGPoint) -> CGRect {
    CGRect(x: point.x - radiusX, y: point.y - radiusY, width: radiusX * 2, height: radiusY * 2)
}

// The coin's thickness: the far ellipse plus the band joining it to the face.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.05, color: grey(0, 0.28))

let body = CGMutablePath()
body.addEllipse(in: ellipseRect(at: backCentre))
body.addRect(CGRect(
    x: faceCentre.x, y: centre.y - radiusY,
    width: backCentre.x - faceCentre.x, height: radiusY * 2
))
ctx.addPath(body)
ctx.clip()

let bodyGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [grey(0.10), grey(0.28), grey(0.13)] as CFArray,
    locations: [0.0, 0.55, 1.0]
)!
ctx.drawLinearGradient(
    bodyGradient,
    start: CGPoint(x: faceCentre.x, y: 0),
    end: CGPoint(x: backCentre.x + radiusX, y: 0),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)
ctx.restoreGState()

// The face: white, with a thick dark rim.
let rim = size * 0.060
ctx.setFillColor(grey(0.99))
ctx.fillEllipse(in: ellipseRect(at: faceCentre))
ctx.setStrokeColor(grey(0.12))
ctx.setLineWidth(rim)
ctx.strokeEllipse(in: ellipseRect(at: faceCentre).insetBy(dx: rim / 2, dy: rim / 2))

// Euro sign on the face, squeezed horizontally to sit on the tilted surface.
let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsContext

let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: size * 0.36, weight: .semibold),
    .foregroundColor: NSColor(white: 0.16, alpha: 1),
]
let glyph = NSAttributedString(string: "€", attributes: attributes)
let glyphSize = glyph.size()

ctx.saveGState()
ctx.translateBy(x: faceCentre.x, y: faceCentre.y)
ctx.scaleBy(x: 0.72, y: 1.0)
glyph.draw(at: CGPoint(x: -glyphSize.width / 2, y: -glyphSize.height / 2 + size * 0.008))
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()

guard let image = ctx.makeImage() else { fatalError("Unable to render image") }
let rep = NSBitmapImageRep(cgImage: image)
rep.size = NSSize(width: size, height: size)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("Unable to encode PNG") }
try data.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath) (\(data.count) bytes)")
