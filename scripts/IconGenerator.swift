// Burp2Magisk original icon generator.
//
// Draws the app artwork with AppKit vector primitives — a folded certificate
// whose corner peels toward a small package — and exports:
//   - <out>/Burp2Magisk.png       1024x1024 full icon (squircle + motif)
//   - <out>/Burp2MagiskGlyph.png  1024x1024 motif-only, for template tinting
//   - <cwd>/work/Burp2Magisk.iconset  (converted to .icns by iconutil afterwards)
//
// Usage: IconGenerator [output-directory]   (default: Resources)

import AppKit
import Foundation

// MARK: - Palette

struct Palette {
    var sheet: NSColor      // certificate paper
    var fold: NSColor       // folded corner underside
    var line: NSColor       // content bars on the certificate
    var seal: NSColor       // trust seal disc
    var sealCheck: NSColor? // checkmark stroke; nil knocks the shape out
    var boxFront: NSColor   // package front face
    var boxTop: NSColor     // package top face
    var boxSide: NSColor    // package side face
    var strap: NSColor      // package strap band
}

let colorPalette = Palette(
    sheet: .white,
    fold: NSColor(srgbRed: 0.93, green: 0.90, blue: 0.86, alpha: 1),
    line: NSColor(srgbRed: 0.45, green: 0.83, blue: 0.75, alpha: 1),
    seal: NSColor(srgbRed: 1.00, green: 0.40, blue: 0.20, alpha: 1),
    sealCheck: .white,
    boxFront: NSColor(srgbRed: 0.00, green: 0.78, blue: 0.33, alpha: 1),
    boxTop: NSColor(srgbRed: 0.41, green: 0.94, blue: 0.68, alpha: 1),
    boxSide: NSColor(srgbRed: 0.00, green: 0.55, blue: 0.24, alpha: 1),
    strap: NSColor(srgbRed: 0.88, green: 0.31, blue: 0.10, alpha: 1)
)

let glyphPalette = Palette(
    sheet: .black, fold: .black, line: .black, seal: .black, sealCheck: nil,
    boxFront: .black, boxTop: .black, boxSide: .black, strap: .black
)

// MARK: - Motif

/// Certificate sheet geometry, shared by every render.
private let sheet = NSRect(x: 240, y: 250, width: 500, height: 580)
private let sheetRadius: CGFloat = 34
private let foldSize: CGFloat = 150

func drawMotif(_ palette: Palette, shadow: Bool) {
    let ctx = NSGraphicsContext.current!.cgContext

    func fill(_ path: NSBezierPath, _ color: NSColor) {
        color.setFill(); path.fill()
    }

    // Soft contact shadow behind the motif.
    if shadow {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 26,
                      color: NSColor.black.withAlphaComponent(0.20).cgColor)
        let path = NSBezierPath(roundedRect: sheet, xRadius: sheetRadius, yRadius: sheetRadius)
        NSColor.white.setFill()
        path.fill()
        ctx.restoreGState()
    }

    // Certificate paper.
    let paper = NSBezierPath(roundedRect: sheet, xRadius: sheetRadius, yRadius: sheetRadius)
    fill(paper, palette.sheet)

    // Folded top-right corner: underside triangle + crease.
    let r = sheet.maxX, t = sheet.maxY
    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: r - foldSize, y: t))
    fold.line(to: NSPoint(x: r, y: t))
    fold.line(to: NSPoint(x: r, y: t - foldSize))
    fold.close()
    fill(fold, palette.fold)
    NSColor.black.withAlphaComponent(shadow ? 0.10 : 0.25).setStroke()
    let crease = NSBezierPath()
    crease.move(to: NSPoint(x: r - foldSize, y: t))
    crease.line(to: NSPoint(x: r, y: t - foldSize))
    crease.lineWidth = 3
    crease.stroke()

    // Content bars suggesting certificate fields.
    let bars: [(y: CGFloat, width: CGFloat)] = [(700, 340), (648, 400), (596, 280)]
    for bar in bars {
        let path = NSBezierPath(roundedRect: NSRect(x: sheet.minX + 70, y: bar.y,
                                                    width: bar.width, height: 26),
                                xRadius: 13, yRadius: 13)
        fill(path, palette.line)
    }

    // Trust seal: Burp-orange disc with a checkmark.
    let sealCenter = NSPoint(x: sheet.minX + 130, y: sheet.minY + 150)
    let sealRadius: CGFloat = 74
    let seal = NSBezierPath(ovalIn: NSRect(x: sealCenter.x - sealRadius, y: sealCenter.y - sealRadius,
                                           width: sealRadius * 2, height: sealRadius * 2))
    fill(seal, palette.seal)
    let check = NSBezierPath()
    check.move(to: NSPoint(x: sealCenter.x - 32, y: sealCenter.y + 2))
    check.line(to: NSPoint(x: sealCenter.x - 8, y: sealCenter.y - 24))
    check.line(to: NSPoint(x: sealCenter.x + 36, y: sealCenter.y + 28))
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.lineWidth = 22
    if let checkColor = palette.sealCheck {
        checkColor.setStroke()
        check.stroke()
    } else {
        // Glyph mode: punch the checkmark out of the disc.
        ctx.saveGState()
        ctx.setBlendMode(.destinationOut)
        NSColor.black.setStroke()
        check.stroke()
        ctx.restoreGState()
    }

    // Small package overlapping the certificate's bottom-right corner:
    // front face, top and side facets, strap band.
    let front = NSRect(x: 560, y: 210, width: 250, height: 190)
    let skew: CGFloat = 48
    let top = NSBezierPath()
    top.move(to: NSPoint(x: front.minX, y: front.maxY))
    top.line(to: NSPoint(x: front.minX + skew, y: front.maxY + skew))
    top.line(to: NSPoint(x: front.maxX + skew, y: front.maxY + skew))
    top.line(to: NSPoint(x: front.maxX, y: front.maxY))
    top.close()
    fill(top, palette.boxTop)
    let side = NSBezierPath()
    side.move(to: NSPoint(x: front.maxX, y: front.maxY))
    side.line(to: NSPoint(x: front.maxX + skew, y: front.maxY + skew))
    side.line(to: NSPoint(x: front.maxX + skew, y: front.minY + skew))
    side.line(to: NSPoint(x: front.maxX, y: front.minY))
    side.close()
    fill(side, palette.boxSide)
    let frontPath = NSBezierPath(roundedRect: front, xRadius: 22, yRadius: 22)
    fill(frontPath, palette.boxFront)
    // Strap running over the top and down the front.
    let strapW: CGFloat = 34
    let strapX = front.midX - strapW / 2
    let strapTop = NSBezierPath()
    strapTop.move(to: NSPoint(x: strapX, y: front.maxY))
    strapTop.line(to: NSPoint(x: strapX + strapW, y: front.maxY))
    strapTop.line(to: NSPoint(x: strapX + strapW + skew, y: front.maxY + skew))
    strapTop.line(to: NSPoint(x: strapX + skew, y: front.maxY + skew))
    strapTop.close()
    fill(strapTop, palette.strap)
    let strapFront = NSBezierPath(roundedRect: NSRect(x: strapX, y: front.minY - 2,
                                                      width: strapW, height: front.height + 2),
                                  xRadius: 12, yRadius: 12)
    fill(strapFront, palette.strap)
}

// MARK: - Full icon

func drawIconBackground() {
    let ctx = NSGraphicsContext.current!.cgContext
    let squircle = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024),
                                xRadius: 229, yRadius: 229)
    squircle.addClip()
    let colors = [NSColor(srgbRed: 0.06, green: 0.39, blue: 0.29, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.02, green: 0.14, blue: 0.10, alpha: 1).cgColor]
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0),
                           options: [])
    // Gentle top sheen.
    NSColor.white.withAlphaComponent(0.10).setFill()
    let sheen = NSBezierPath(ovalIn: NSRect(x: 112, y: 640, width: 800, height: 560))
    sheen.fill()
}

// MARK: - Rendering helpers

func render(size: NSSize, _ draw: @escaping () -> Void) -> NSImage {
    NSImage(size: size, flipped: false) { _ in
        NSGraphicsContext.current?.imageInterpolation = .high
        draw()
        return true
    }
}

func pngData(_ image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

func resized(_ image: NSImage, to size: NSSize) -> NSImage {
    render(size: size) {
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)
    }
}

// MARK: - Main

let arguments = CommandLine.arguments
let outDir = arguments.count > 1 ? arguments[1] : "Resources"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let canvas = NSSize(width: 1024, height: 1024)

let fullIcon = render(size: canvas) {
    drawIconBackground()
    drawMotif(colorPalette, shadow: true)
}
let glyph = render(size: canvas) {
    drawMotif(glyphPalette, shadow: false)
}

guard let fullPNG = pngData(fullIcon), let glyphPNG = pngData(glyph) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try fullPNG.write(to: URL(fileURLWithPath: "\(outDir)/Burp2Magisk.png"))
try glyphPNG.write(to: URL(fileURLWithPath: "\(outDir)/Burp2MagiskGlyph.png"))

// iconset for iconutil.
let iconset = "work/Burp2Magisk.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let image = resized(fullIcon, to: NSSize(width: px, height: px))
        guard let data = pngData(image) else { exit(1) }
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try data.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
    }
}

print("Wrote \(outDir)/Burp2Magisk.png, \(outDir)/Burp2MagiskGlyph.png, \(iconset)")
