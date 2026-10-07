// DiceRecognizer.swift
// Reconnaissance de dés sur une photo, par analyse d'image classique (sans modèle entraîné) :
//   1. seuil automatique (Otsu) pour séparer les faces des dés du fond ;
//   2. composantes connexes claires = dés candidats ;
//   3. « trous » sombres entièrement entourés par un dé = points ;
//   4. filtres de taille et de forme, puis comptage.
// Une seconde passe sur l'image inversée gère les dés sombres à points clairs.
//
// Limites connues : dés qui se touchent (vus comme un seul), photo très en biais
// (les points des faces latérales sont comptés), fond aussi clair que les dés.
// L'interface propose toujours une correction manuelle.

/// Image en niveaux de gris, 1 octet par pixel, ligne par ligne.
public struct GrayImage: Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "Taille de l'image incohérente")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public init(width: Int, height: Int, fill: UInt8 = 0) {
        self.init(width: width, height: height, pixels: Array(repeating: fill, count: width * height))
    }

    public subscript(x: Int, y: Int) -> UInt8 {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }

    /// Réduction par moyenne de blocs : accélère l'analyse et atténue le bruit.
    public func downscaled(maxSide: Int) -> GrayImage {
        let factor = max(1, Int((Double(max(width, height)) / Double(maxSide)).rounded(.up)))
        guard factor > 1 else { return self }
        let w = width / factor, h = height / factor
        var out = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                var sum = 0
                for dy in 0..<factor {
                    let row = (y * factor + dy) * width + x * factor
                    for dx in 0..<factor { sum += Int(pixels[row + dx]) }
                }
                out[y * w + x] = UInt8(sum / (factor * factor))
            }
        }
        return GrayImage(width: w, height: h, pixels: out)
    }

    public var inverted: GrayImage {
        GrayImage(width: width, height: height, pixels: pixels.map { 255 - $0 })
    }
}

/// Un dé reconnu.
public struct DetectedDie: Hashable, Sendable {
    public let value: Int
    /// Rectangle englobant, en fraction de l'image (0…1).
    public let minX: Double, minY: Double, maxX: Double, maxY: Double
    /// Confiance 0…1 (régularité des points).
    public let confidence: Double

    public var face: DieFace? { DieFace(value) }
}

public enum DiceRecognizer {

    /// Détecte jusqu'à `expected` dés, triés de gauche à droite.
    public static func detect(in image: GrayImage, expected: Int = 3) -> [DetectedDie] {
        let small = image.downscaled(maxSide: 360)
        let normal = analyze(small)
        let inverted = analyze(small.inverted)
        // On garde la passe qui trouve le plus de dés plausibles (à égalité : la plus confiante).
        func score(_ dice: [DetectedDie]) -> (Int, Double) {
            (min(dice.count, expected) * 10 - max(0, dice.count - expected),
             dice.map(\.confidence).reduce(0, +))
        }
        let best = score(inverted) > score(normal) ? inverted : normal
        return Array(best.sorted { $0.confidence > $1.confidence }.prefix(expected))
            .sorted { ($0.minX + $0.maxX) < ($1.minX + $1.maxX) }
    }

    // MARK: - Analyse d'une image (dés clairs, points sombres)

    private struct Component {
        var area = 0
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        var touchesBorder = false
        /// Composantes claires voisines (pour les composantes sombres).
        var neighbors: Set<Int> = []
        var width: Int { maxX - minX + 1 }
        var height: Int { maxY - minY + 1 }
    }

    static func analyze(_ image: GrayImage) -> [DetectedDie] {
        let w = image.width, h = image.height
        guard w > 8, h > 8 else { return [] }
        let (threshold, separation) = otsu(image)
        // Pas assez de contraste entre zones claires et sombres : rien à reconnaître.
        guard separation >= 60 else { return [] }
        let bright = image.pixels.map { $0 > threshold }

        // Étiquetage des zones claires puis sombres (connexité 4).
        var labels = [Int](repeating: -1, count: w * h)
        var brightComponents: [Component] = []
        var darkComponents: [Component] = []
        var stack: [Int] = []
        stack.reserveCapacity(w * h / 4)

        for start in 0..<(w * h) where labels[start] < 0 {
            let isBright = bright[start]
            let label = isBright ? brightComponents.count : -2 - darkComponents.count
            var component = Component()
            labels[start] = label
            stack.append(start)
            while let index = stack.popLast() {
                let x = index % w, y = index / w
                component.area += 1
                component.minX = min(component.minX, x); component.maxX = max(component.maxX, x)
                component.minY = min(component.minY, y); component.maxY = max(component.maxY, y)
                if x == 0 || y == 0 || x == w - 1 || y == h - 1 { component.touchesBorder = true }
                for neighbor in [x > 0 ? index - 1 : -1, x < w - 1 ? index + 1 : -1,
                                 y > 0 ? index - w : -1, y < h - 1 ? index + w : -1] where neighbor >= 0 {
                    if bright[neighbor] == isBright {
                        if labels[neighbor] == -1 {
                            labels[neighbor] = label
                            stack.append(neighbor)
                        }
                    } else if !isBright, labels[neighbor] >= 0 {
                        component.neighbors.insert(labels[neighbor])
                    }
                }
            }
            if isBright { brightComponents.append(component) } else { darkComponents.append(component) }
        }
        // Les voisins clairs d'une zone sombre étiquetés après elle : seconde passe rapide.
        for index in 0..<(w * h) where labels[index] <= -2 {
            let x = index % w, y = index / w
            for neighbor in [x > 0 ? index - 1 : -1, x < w - 1 ? index + 1 : -1,
                             y > 0 ? index - w : -1, y < h - 1 ? index + w : -1] where neighbor >= 0 && labels[neighbor] >= 0 {
                darkComponents[-2 - labels[index]].neighbors.insert(labels[neighbor])
            }
        }

        // Points : zones sombres fermées, entourées par un seul dé.
        var holes: [Int: [Component]] = [:]
        for dark in darkComponents where !dark.touchesBorder && dark.neighbors.count == 1 {
            holes[dark.neighbors.first!, default: []].append(dark)
        }

        let imageArea = Double(w * h)
        var dice: [DetectedDie] = []
        for (label, die) in brightComponents.enumerated() {
            let pips = holes[label] ?? []
            let fullArea = Double(die.area + pips.reduce(0) { $0 + $1.area })
            let boxArea = Double(die.width * die.height)
            let aspect = Double(die.width) / Double(die.height)
            // Dé plausible : assez grand, à peu près carré, bien rempli (≥ 0,5 même tourné à 45°).
            guard fullArea > imageArea * 0.0025, fullArea < imageArea * 0.5,
                  (0.55...1.8).contains(aspect), fullArea / boxArea > 0.42 else { continue }

            // Points plausibles : taille relative au dé et forme ronde.
            let validPips = pips.filter { pip in
                let relative = Double(pip.area) / fullArea
                let roundness = Double(pip.area) / Double(pip.width * pip.height)
                let pipAspect = Double(pip.width) / Double(pip.height)
                return (0.004...0.09).contains(relative) && roundness > 0.45 && (0.5...2).contains(pipAspect)
            }
            guard (1...6).contains(validPips.count) else { continue }

            // Confiance : points de tailles semblables (le 1 est souvent plus gros : toléré).
            let areas = validPips.map { Double($0.area) }
            let mean = areas.reduce(0, +) / Double(areas.count)
            let spread = areas.map { abs($0 - mean) / mean }.max() ?? 0
            let confidence = max(0.1, min(1, 1 - spread * 0.6)) * (pips.count == validPips.count ? 1 : 0.8)

            dice.append(DetectedDie(value: validPips.count,
                                    minX: Double(die.minX) / Double(w), minY: Double(die.minY) / Double(h),
                                    maxX: Double(die.maxX + 1) / Double(w), maxY: Double(die.maxY + 1) / Double(h),
                                    confidence: confidence))
        }
        return dice
    }

    /// Seuil d'Otsu : maximise la variance entre les deux classes de pixels.
    static func otsuThreshold(_ image: GrayImage) -> UInt8 { otsu(image).threshold }

    /// Seuil d'Otsu et écart entre les moyennes des deux classes (mesure du contraste).
    static func otsu(_ image: GrayImage) -> (threshold: UInt8, separation: Double) {
        var histogram = [Int](repeating: 0, count: 256)
        for p in image.pixels { histogram[Int(p)] += 1 }
        let total = Double(image.pixels.count)
        let sumAll = histogram.enumerated().reduce(0.0) { $0 + Double($1.offset * $1.element) }
        var sumBackground = 0.0, weightBackground = 0.0
        var best = (threshold: 127, variance: -1.0, separation: 0.0)
        for t in 0..<256 {
            weightBackground += Double(histogram[t])
            guard weightBackground > 0 else { continue }
            let weightForeground = total - weightBackground
            guard weightForeground > 0 else { break }
            sumBackground += Double(t * histogram[t])
            let meanB = sumBackground / weightBackground
            let meanF = (sumAll - sumBackground) / weightForeground
            let variance = weightBackground * weightForeground * (meanB - meanF) * (meanB - meanF)
            if variance > best.variance { best = (t, variance, meanF - meanB) }
        }
        return (UInt8(best.threshold), best.separation)
    }
}
