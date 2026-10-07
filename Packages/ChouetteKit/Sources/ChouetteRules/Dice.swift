// Dice.swift
// Types de base : une face de dé et un lancer de trois dés.

/// Valeur d'un dé à six faces (1…6). Impossible à construire hors de cet intervalle.
public struct DieFace: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let value: Int

    /// Retourne `nil` si `value` n'est pas comprise entre 1 et 6.
    public init?(_ value: Int) {
        guard (1...6).contains(value) else { return nil }
        self.value = value
    }

    public static let all: [DieFace] = (1...6).map { DieFace($0)! }

    /// Nom d'oiseau traditionnellement associé à la valeur (utilisé pour le sirotage).
    public var birdName: String {
        switch value {
        case 1: "Linotte"
        case 2: "Alouette"
        case 3: "Fauvette"
        case 4: "Mouette"
        case 5: "Bergeronnette"
        default: "Chouette"
        }
    }

    public static func < (lhs: DieFace, rhs: DieFace) -> Bool { lhs.value < rhs.value }
    public var description: String { String(value) }

    // Codable sous forme d'entier simple, avec validation.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Int.self)
        guard let face = DieFace(raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Face de dé invalide : \(raw)"))
        }
        self = face
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// Un lancer de trois dés. L'ordre d'origine est conservé (utile pour l'affichage),
/// mais l'analyse ne dépend que des valeurs.
public struct Roll: Hashable, Sendable, Codable, CustomStringConvertible {
    public let dice: [DieFace]

    public init(_ a: DieFace, _ b: DieFace, _ c: DieFace) {
        dice = [a, b, c]
    }

    /// Construit un lancer à partir d'entiers ; `nil` si une valeur est invalide
    /// ou s'il n'y a pas exactement trois dés.
    public init?(_ values: [Int]) {
        let faces = values.compactMap(DieFace.init)
        guard values.count == 3, faces.count == 3 else { return nil }
        dice = faces
    }

    /// Raccourci pratique : `Roll(2, 2, 4)`. Plante si une valeur est invalide —
    /// réservé aux littéraux (tests, tutoriel).
    public init(_ a: Int, _ b: Int, _ c: Int) {
        guard let roll = Roll([a, b, c]) else { preconditionFailure("Lancer invalide : \(a)-\(b)-\(c)") }
        self = roll
    }

    /// Valeurs triées par ordre croissant.
    public var sortedValues: [Int] { dice.map(\.value).sorted() }

    /// Les 216 lancers possibles (6³), dans l'ordre.
    public static let allRolls: [Roll] = DieFace.all.flatMap { a in
        DieFace.all.flatMap { b in DieFace.all.map { c in Roll(a, b, c) } }
    }

    public var description: String { dice.map(\.description).joined(separator: "-") }

    /// Tire un lancer avec le générateur fourni.
    public static func random(using generator: inout some RandomNumberGenerator) -> Roll {
        Roll(DieFace.random(using: &generator), DieFace.random(using: &generator), DieFace.random(using: &generator))
    }
}

public extension DieFace {
    static func random(using generator: inout some RandomNumberGenerator) -> DieFace {
        DieFace(Int.random(in: 1...6, using: &generator))!
    }
}

/// Générateur pseudo-aléatoire déterministe (SplitMix64) : mêmes graines, mêmes lancers.
/// Utilisé par les tests et pour rejouer une partie.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
