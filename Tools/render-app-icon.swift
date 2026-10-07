// Génère l'icône de l'app (1024 × 1024) : chouette géométrique sur fond vin, un dé sur le ventre.
// ⚠︎ ICÔNE PROVISOIRE (voir ASSETS.md) — usage : swift Tools/render-app-icon.swift sortie.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
// Repère avec l'origine en haut à gauche.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

// Fond : dégradé radial vin.
let bg = CGGradient(colorsSpace: cs, colors: [color(0xA8342B), color(0x5E1712)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(bg, startCenter: CGPoint(x: 512, y: 420), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 512), endRadius: 760, options: [.drawsAfterEndLocation])

let parchment = color(0xF3E4C4), gold = color(0xE2B653), ink = color(0x2B1D12)

// Corps : ovale parchemin.
ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 40, color: color(0x000000, 0.45))
ctx.setFillColor(parchment)
ctx.fillEllipse(in: CGRect(x: 262, y: 300, width: 500, height: 600))
ctx.setShadow(offset: .zero, blur: 0)

// Aigrettes (oreilles).
for flip in [CGFloat(1), -1] {
    let cx: CGFloat = 512 + flip * 175
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx - flip * 95, y: 360))
    ctx.addLine(to: CGPoint(x: cx + flip * 40, y: 170))
    ctx.addLine(to: CGPoint(x: cx + flip * 70, y: 380))
    ctx.closePath()
    ctx.setFillColor(parchment)
    ctx.fillPath()
}

// Yeux : anneaux d'or, pupilles d'encre, reflet.
for cx in [CGFloat(400), 624] {
    ctx.setFillColor(gold)
    ctx.fillEllipse(in: CGRect(x: cx - 95, y: 345, width: 190, height: 190))
    ctx.setFillColor(ink)
    ctx.fillEllipse(in: CGRect(x: cx - 60, y: 380, width: 120, height: 120))
    ctx.setFillColor(color(0xFFFFFF, 0.9))
    ctx.fillEllipse(in: CGRect(x: cx - 30, y: 400, width: 34, height: 34))
}

// Bec.
ctx.beginPath()
ctx.move(to: CGPoint(x: 472, y: 520))
ctx.addLine(to: CGPoint(x: 552, y: 520))
ctx.addLine(to: CGPoint(x: 512, y: 600))
ctx.closePath()
ctx.setFillColor(gold)
ctx.fillPath()

// Dé (face 5) sur le ventre, légèrement incliné.
ctx.saveGState()
ctx.translateBy(x: 512, y: 735)
ctx.rotate(by: -0.12)
let die = CGRect(x: -105, y: -105, width: 210, height: 210)
ctx.setShadow(offset: CGSize(width: 0, height: 8), blur: 16, color: color(0x000000, 0.35))
ctx.addPath(CGPath(roundedRect: die, cornerWidth: 40, cornerHeight: 40, transform: nil))
ctx.setFillColor(color(0xFFFBF0))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0)
ctx.setFillColor(ink)
for (x, y) in [(-1.0, -1.0), (1, -1), (0, 0), (-1, 1), (1, 1)] {
    ctx.fillEllipse(in: CGRect(x: x * 56 - 21, y: y * 56 - 21, width: 42, height: 42))
}
ctx.restoreGState()

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
