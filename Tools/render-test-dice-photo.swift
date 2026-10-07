// Génère une photo de synthèse de dés pour tester la reconnaissance sur simulateur :
//   swift Tools/render-test-dice-photo.swift des.jpg && xcrun simctl addmedia booted des.jpg

import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let W = 1500, H = 1100
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Fond bois : dégradé + veines.
let grad = CGGradient(colorsSpace: cs, colors: [CGColor(red: 0.36, green: 0.22, blue: 0.12, alpha: 1),
                                                CGColor(red: 0.24, green: 0.14, blue: 0.08, alpha: 1)] as CFArray, locations: nil)!
ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: W, y: H), options: [])
srand48(7)
for _ in 0..<120 {
    let y0 = drand48() * Double(H)
    ctx.setStrokeColor(CGColor(red: 0.18, green: 0.1, blue: 0.05, alpha: 0.25 + 0.2 * drand48()))
    ctx.setLineWidth(1 + 3 * drand48())
    ctx.move(to: CGPoint(x: 0, y: y0))
    for x in stride(from: 0.0, through: Double(W), by: 20) {
        ctx.addLine(to: CGPoint(x: x, y: y0 + 8 * sin(x * 0.01 + y0)))
    }
    ctx.strokePath()
}
let layouts: [Int: [(Double, Double)]] = [
    1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)],
    4: [(-1, -1), (1, -1), (-1, 1), (1, 1)], 5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
    6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)],
]
func die(_ value: Int, x: Double, y: Double, size s: Double, angle: Double) {
    ctx.saveGState()
    ctx.translateBy(x: x, y: y)
    ctx.rotate(by: angle)
    let rect = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
    ctx.setShadow(offset: CGSize(width: 14, height: -14), blur: 25, color: CGColor(gray: 0, alpha: 0.6))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: s * 0.16, cornerHeight: s * 0.16, transform: nil))
    ctx.setFillColor(CGColor(red: 0.95, green: 0.92, blue: 0.84, alpha: 1))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0)
    for (px, py) in layouts[value]! {
        let r = s * (value == 1 ? 0.12 : 0.085)
        ctx.setFillColor(value == 1 ? CGColor(red: 0.6, green: 0.1, blue: 0.08, alpha: 1) : CGColor(gray: 0.08, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: px * s * 0.27 - r, y: py * s * 0.27 - r, width: 2 * r, height: 2 * r))
    }
    ctx.restoreGState()
}
die(5, x: 330, y: 560, size: 230, angle: 0.35)
die(2, x: 760, y: 480, size: 225, angle: -0.5)
die(6, x: 1180, y: 620, size: 235, angle: 0.15)
let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
CGImageDestinationFinalize(dest)
print("ok")
