import Foundation
import Testing
@testable import ChouetteRules

/// Dessine des dés de synthèse : faces carrées tournées, points ronds, bruit de fond.
private struct DiceImageSynthesizer {
    var width = 480
    var height = 320
    var background: UInt8 = 70
    var faceColor: UInt8 = 225
    var pipColor: UInt8 = 25
    var noise = 18

    struct Die {
        var value: Int
        var centerX: Double, centerY: Double
        var size: Double
        var angle: Double
    }

    private static let layouts: [Int: [(Double, Double)]] = [
        1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)],
        4: [(-1, -1), (1, -1), (-1, 1), (1, 1)], 5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
        6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)],
    ]

    func render(_ dice: [Die], using rng: inout SeededGenerator) -> GrayImage {
        var image = GrayImage(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                var value = Int(background)
                for die in dice {
                    let dx = Double(x) - die.centerX, dy = Double(y) - die.centerY
                    let u = dx * cos(-die.angle) - dy * sin(-die.angle)
                    let v = dx * sin(-die.angle) + dy * cos(-die.angle)
                    guard abs(u) <= die.size / 2, abs(v) <= die.size / 2 else { continue }
                    value = Int(faceColor)
                    let radius = die.size * (die.value == 1 ? 0.12 : 0.085)
                    for (px, py) in Self.layouts[die.value]! {
                        let cu = px * die.size * 0.27, cv = py * die.size * 0.27
                        if (u - cu) * (u - cu) + (v - cv) * (v - cv) <= radius * radius { value = Int(pipColor) }
                    }
                }
                value += Int.random(in: -noise...noise, using: &rng)
                image[x, y] = UInt8(min(max(value, 0), 255))
            }
        }
        return image
    }
}

@Suite("Reconnaissance des dés sur photo")
struct DiceRecognizerTests {

    @Test("Trois dés droits, toutes les valeurs")
    func straightDice() {
        var rng = SeededGenerator(seed: 1)
        let synth = DiceImageSynthesizer()
        for values in [[1, 2, 3], [4, 5, 6], [6, 6, 6], [1, 1, 2]] {
            let image = synth.render(values.enumerated().map { i, v in
                .init(value: v, centerX: 90 + Double(i) * 150, centerY: 160, size: 80, angle: 0)
            }, using: &rng)
            #expect(DiceRecognizer.detect(in: image).map(\.value) == values, "Lancer \(values)")
        }
    }

    @Test("Dés tournés, tailles et positions aléatoires")
    func randomScenes() {
        var rng = SeededGenerator(seed: 42)
        let synth = DiceImageSynthesizer()
        var successes = 0
        let trials = 30
        for _ in 0..<trials {
            let values = (0..<3).map { _ in Int.random(in: 1...6, using: &rng) }
            let size = Double.random(in: 55...90, using: &rng)
            let dice = values.enumerated().map { i, v in
                DiceImageSynthesizer.Die(value: v,
                                         centerX: 85 + Double(i) * 155 + .random(in: -15...15, using: &rng),
                                         centerY: 160 + .random(in: -60...60, using: &rng),
                                         size: size, angle: .random(in: 0...(.pi / 2), using: &rng))
            }
            if DiceRecognizer.detect(in: synth.render(dice, using: &rng)).map(\.value) == values { successes += 1 }
        }
        // Les images de synthèse sont propres : on exige un taux de réussite élevé.
        #expect(successes >= trials * 95 / 100, "\(successes)/\(trials) scènes reconnues")
    }

    @Test("Dés sombres à points clairs (passe inversée)")
    func darkDice() {
        var rng = SeededGenerator(seed: 3)
        var synth = DiceImageSynthesizer()
        synth.background = 200
        synth.faceColor = 40
        synth.pipColor = 235
        let image = synth.render([.init(value: 5, centerX: 100, centerY: 150, size: 80, angle: 0.3),
                                  .init(value: 2, centerX: 250, centerY: 160, size: 80, angle: 0.8),
                                  .init(value: 4, centerX: 390, centerY: 150, size: 80, angle: 0.1)], using: &rng)
        #expect(DiceRecognizer.detect(in: image).map(\.value) == [5, 2, 4])
    }

    @Test("Un seul dé attendu (sirotage)")
    func singleDie() {
        var rng = SeededGenerator(seed: 4)
        let image = DiceImageSynthesizer().render([.init(value: 3, centerX: 240, centerY: 160, size: 100, angle: 0.5)], using: &rng)
        let dice = DiceRecognizer.detect(in: image, expected: 1)
        #expect(dice.map(\.value) == [3])
        #expect(dice[0].minX < 0.5 && dice[0].maxX > 0.5)
    }

    @Test("Image sans dé : aucun résultat")
    func emptyImage() {
        var rng = SeededGenerator(seed: 5)
        #expect(DiceRecognizer.detect(in: DiceImageSynthesizer().render([], using: &rng)).isEmpty)
    }

    @Test("Grande image : réduction avant analyse")
    func largeImage() {
        var rng = SeededGenerator(seed: 6)
        var synth = DiceImageSynthesizer()
        synth.width = 1600
        synth.height = 1000
        let image = synth.render([.init(value: 6, centerX: 300, centerY: 500, size: 260, angle: 0.2),
                                  .init(value: 1, centerX: 800, centerY: 500, size: 260, angle: 0.6),
                                  .init(value: 3, centerX: 1300, centerY: 500, size: 260, angle: 1.1)], using: &rng)
        #expect(DiceRecognizer.detect(in: image).map(\.value) == [6, 1, 3])
    }

    @Test func otsu() {
        var image = GrayImage(width: 10, height: 10, fill: 30)
        for i in 0..<50 { image.pixels[i] = 220 }
        let t = DiceRecognizer.otsuThreshold(image)
        #expect(t >= 30 && t < 220)
    }
}
