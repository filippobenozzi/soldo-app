// Renders the Schei app icons (1024x1024 PNG) with CoreGraphics.
//
// A struck coin bearing "5" and the legend "SCHEI DE MONA". Three variants are
// produced, matching iOS 18's icon appearances:
//   light   — gold coin on cream
//   dark    — dark coin with a gold rim on near-black
//   tinted  — greyscale on transparency, for the system's tinted mode
//
// Usage: swift Tools/MakeIcon.swift <output-directory>

import AppKit
import CoreGraphics
import Foundation

let size = 1024.0
let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

struct Palette {
    var backgroundTop: CGColor
    var backgroundBottom: CGColor
    var rimLight: CGColor
    var rimMid: CGColor
    var rimDark: CGColor
    var fieldLight: CGColor
    var fieldDark: CGColor
    /// Raised lettering and the numeral.
    var relief: CGColor
    var reliefShadow: CGColor
    /// Drawn around the outer edge when the rim itself is dark, so the coin keeps
    /// a gold outline against a dark field.
    var outerRing: CGColor?
    var opaqueBackground: Bool
}

func srgb(_ hex: UInt32, _ alpha: Double = 1) -> CGColor {
    CGColor(
        srgbRed: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let lightPalette = Palette(
    backgroundTop: srgb(0xF8EDD6),
    backgroundBottom: srgb(0xEBD9B4),
    rimLight: srgb(0xF2DA92),
    rimMid: srgb(0xD8B44F),
    rimDark: srgb(0xA8801F),
    fieldLight: srgb(0xEFD489),
    fieldDark: srgb(0xC69C33),
    relief: srgb(0x8A6412),
    reliefShadow: srgb(0xFAEBB8),
    outerRing: nil,
    opaqueBackground: true
)

// The dark coin keeps a dark rim band so the gold legend reads against it, with a
// gold ring around the edge.
let darkPalette = Palette(
    backgroundTop: srgb(0x30353F),
    backgroundBottom: srgb(0x191C22),
    rimLight: srgb(0x424956),
    rimMid: srgb(0x333945),
    rimDark: srgb(0x23272F),
    fieldLight: srgb(0x2C313B),
    fieldDark: srgb(0x1E222A),
    relief: srgb(0xEBCB6E),
    reliefShadow: srgb(0x121419),
    outerRing: srgb(0xDDB855),
    opaqueBackground: true
)

let tintedPalette = Palette(
    backgroundTop: srgb(0x000000, 0),
    backgroundBottom: srgb(0x000000, 0),
    rimLight: srgb(0xFFFFFF),
    rimMid: srgb(0xC8C8C8),
    rimDark: srgb(0x8A8A8A),
    fieldLight: srgb(0xB4B4B4),
    fieldDark: srgb(0x8E8E8E),
    relief: srgb(0xFFFFFF),
    reliefShadow: srgb(0x5A5A5A),
    outerRing: nil,
    opaqueBackground: false
)

// MARK: - Arc text

/// Lays a string out along a circle. `centreAngle` is where the middle of the
/// string sits, in degrees, measured counter-clockwise from the positive x axis
/// (270° is the bottom of the coin).
func drawArcText(
    _ text: String,
    in ctx: CGContext,
    centre: CGPoint,
    radius: CGFloat,
    centreAngle: Double,
    font: NSFont,
    color: CGColor,
    shadow: CGColor?
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: color) ?? .black,
        .kern: size * 0.004,
    ]

    let widths = text.map { character -> CGFloat in
        NSAttributedString(string: String(character), attributes: attributes).size().width
    }
    let totalWidth = widths.reduce(0, +)
    // Arc length to angle: the whole string subtends totalWidth / radius radians.
    let totalAngle = Double(totalWidth / radius)

    var angle = centreAngle * .pi / 180 - totalAngle / 2

    for (index, character) in text.enumerated() {
        let width = widths[index]
        let step = Double(width / radius)
        let glyphAngle = angle + step / 2

        ctx.saveGState()
        ctx.translateBy(x: centre.x, y: centre.y)
        ctx.rotate(by: CGFloat(glyphAngle))
        ctx.translateBy(x: radius, y: 0)
        // At the bottom of the coin the letter's "up" points at the centre, which
        // is what makes the legend read left to right along the rim.
        ctx.rotate(by: .pi / 2)

        let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        if let shadow {
            var shadowAttributes = attributes
            shadowAttributes[.foregroundColor] = NSColor(cgColor: shadow) ?? .white
            NSAttributedString(string: String(character), attributes: shadowAttributes)
                .draw(at: CGPoint(x: -width / 2, y: -font.pointSize * 0.36 - size * 0.0035))
        }
        NSAttributedString(string: String(character), attributes: attributes)
            .draw(at: CGPoint(x: -width / 2, y: -font.pointSize * 0.36))

        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()

        angle += step
    }
}

// MARK: - Ornament

/// The scrollwork that fills the top of the rim, opposite the legend.
func drawFlourish(in ctx: CGContext, centre: CGPoint, radius: CGFloat, color: CGColor, width: CGFloat) {
    ctx.saveGState()
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)

    let span = 0.30 // radians either side of vertical
    for side in [-1.0, 1.0] {
        let path = CGMutablePath()
        let start = CGPoint(
            x: centre.x + radius * cos(.pi / 2 + side * 0.06),
            y: centre.y + radius * sin(.pi / 2 + side * 0.06)
        )
        let end = CGPoint(
            x: centre.x + radius * cos(.pi / 2 + side * span),
            y: centre.y + radius * sin(.pi / 2 + side * span)
        )
        let control = CGPoint(
            x: centre.x + radius * 1.16 * cos(.pi / 2 + side * span * 0.55),
            y: centre.y + radius * 1.16 * sin(.pi / 2 + side * span * 0.55)
        )
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        ctx.addPath(path)
        ctx.strokePath()

        // A small curl at the outer end of each scroll.
        ctx.addArc(
            center: end,
            radius: radius * 0.055,
            startAngle: 0,
            endAngle: .pi * 1.5,
            clockwise: side < 0
        )
        ctx.strokePath()
    }

    // Three dots crowning the ornament.
    for offset in [-0.075, 0.0, 0.075] {
        let point = CGPoint(
            x: centre.x + radius * 1.0 * cos(.pi / 2 + offset),
            y: centre.y + radius * 1.0 * sin(.pi / 2 + offset)
        )
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(
            x: point.x - width * 0.62, y: point.y - width * 0.62,
            width: width * 1.24, height: width * 1.24
        ))
    }
    ctx.restoreGState()
}

// MARK: - Icon

func renderIcon(palette: Palette, to path: String) throws {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(
            data: nil, width: Int(size), height: Int(size),
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
    else { throw NSError(domain: "icon", code: 1) }

    if palette.opaqueBackground {
        let background = CGGradient(
            colorsSpace: colorSpace,
            colors: [palette.backgroundTop, palette.backgroundBottom] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawLinearGradient(
            background,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size, y: 0),
            options: []
        )
    }

    let centre = CGPoint(x: size / 2, y: size / 2)
    let outerRadius = size * 0.375

    // Coin body, with a soft drop shadow.
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.014),
        blur: size * 0.045,
        color: srgb(0x000000, palette.opaqueBackground ? 0.30 : 0.0)
    )
    ctx.setFillColor(palette.rimMid)
    ctx.fillEllipse(in: CGRect(
        x: centre.x - outerRadius, y: centre.y - outerRadius,
        width: outerRadius * 2, height: outerRadius * 2
    ))
    ctx.restoreGState()

    // Rim: a metallic sweep from the upper left.
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(
        x: centre.x - outerRadius, y: centre.y - outerRadius,
        width: outerRadius * 2, height: outerRadius * 2
    ))
    ctx.clip()
    let rimGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [palette.rimLight, palette.rimMid, palette.rimDark, palette.rimMid] as CFArray,
        locations: [0.0, 0.42, 0.76, 1.0]
    )!
    ctx.drawLinearGradient(
        rimGradient,
        start: CGPoint(x: centre.x - outerRadius, y: centre.y + outerRadius),
        end: CGPoint(x: centre.x + outerRadius, y: centre.y - outerRadius),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    ctx.restoreGState()

    // Inner field, slightly recessed.
    let fieldRadius = outerRadius * 0.775
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(
        x: centre.x - fieldRadius, y: centre.y - fieldRadius,
        width: fieldRadius * 2, height: fieldRadius * 2
    ))
    ctx.clip()
    let fieldGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [palette.fieldLight, palette.fieldDark] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        fieldGradient,
        start: CGPoint(x: centre.x - fieldRadius, y: centre.y + fieldRadius),
        end: CGPoint(x: centre.x + fieldRadius, y: centre.y - fieldRadius),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    ctx.restoreGState()

    // The groove that separates field from rim.
    ctx.setStrokeColor(palette.outerRing ?? palette.rimDark)
    ctx.setLineWidth(size * (palette.outerRing == nil ? 0.008 : 0.012))
    ctx.strokeEllipse(in: CGRect(
        x: centre.x - fieldRadius, y: centre.y - fieldRadius,
        width: fieldRadius * 2, height: fieldRadius * 2
    ))

    // A gold outline holds the coin together when the rim band is dark.
    if let outerRing = palette.outerRing {
        let inset = size * 0.011
        ctx.setStrokeColor(outerRing)
        ctx.setLineWidth(inset * 2)
        ctx.strokeEllipse(in: CGRect(
            x: centre.x - outerRadius + inset, y: centre.y - outerRadius + inset,
            width: (outerRadius - inset) * 2, height: (outerRadius - inset) * 2
        ))
    }

    // Legend and ornament ride on the rim.
    let legendRadius = (outerRadius + fieldRadius) / 2
    let legendFont = NSFont.systemFont(ofSize: size * 0.082, weight: .semibold)
    drawArcText(
        "SCHEI DE MONA",
        in: ctx,
        centre: centre,
        radius: legendRadius,
        centreAngle: 270,
        font: legendFont,
        color: palette.relief,
        shadow: palette.reliefShadow
    )
    drawFlourish(
        in: ctx,
        centre: centre,
        radius: legendRadius,
        color: palette.relief,
        width: size * 0.014
    )

    // The numeral.
    let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsContext

    let numeralFont = NSFont.systemFont(ofSize: size * 0.40, weight: .bold)
    func drawNumeral(color: CGColor, offset: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: numeralFont,
            .foregroundColor: NSColor(cgColor: color) ?? .black,
        ]
        let numeral = NSAttributedString(string: "5", attributes: attributes)
        let numeralSize = numeral.size()
        numeral.draw(at: CGPoint(
            x: centre.x - numeralSize.width / 2,
            y: centre.y - numeralSize.height / 2 + offset
        ))
    }
    drawNumeral(color: palette.reliefShadow, offset: -size * 0.006)
    drawNumeral(color: palette.relief, offset: 0)

    NSGraphicsContext.restoreGraphicsState()

    guard let image = ctx.makeImage() else { throw NSError(domain: "icon", code: 2) }
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: size, height: size)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 3)
    }
    try data.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path) (\(data.count) bytes)")
}

try renderIcon(palette: lightPalette, to: "\(outputDirectory)/AppIcon.png")
try renderIcon(palette: darkPalette, to: "\(outputDirectory)/AppIcon-Dark.png")
try renderIcon(palette: tintedPalette, to: "\(outputDirectory)/AppIcon-Tinted.png")
