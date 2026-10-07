// Figures.swift
// Reconnaissance des combinaisons (« figures ») d'un lancer et calcul des points.

/// Catégorie de figure, sans valeur. Sert aux paris (civet, grelottine) et à l'affichage.
public enum FigureKind: String, Hashable, Sendable, Codable, CaseIterable {
    case culDeChouette
    case chouetteVelute
    case chouette
    case velute
    case suite
    case neant
}

/// Une figure reconnue dans un lancer, avec les valeurs utiles au calcul.
public enum Figure: Hashable, Sendable, Codable {
    /// Trois dés identiques.
    case culDeChouette(value: Int)
    /// Deux dés identiques dont la somme égale le troisième (1-1-2, 2-2-4, 3-3-6).
    case chouetteVelute(pairValue: Int, veluteValue: Int)
    /// Deux dés identiques.
    case chouette(value: Int)
    /// La somme de deux dés égale le troisième ; `value` est le grand dé.
    case velute(value: Int)
    /// Trois valeurs consécutives ; `lowest` est la plus petite.
    case suite(lowest: Int)
    /// Aucune combinaison.
    case neant

    public var kind: FigureKind {
        switch self {
        case .culDeChouette: .culDeChouette
        case .chouetteVelute: .chouetteVelute
        case .chouette: .chouette
        case .velute: .velute
        case .suite: .suite
        case .neant: .neant
        }
    }
}

/// Résultat de l'analyse d'un lancer.
public struct RollAnalysis: Hashable, Sendable, Codable {
    public let roll: Roll
    /// Figures dans leur ordre de résolution. Jamais vide (au minimum `.neant`).
    /// Ne contient deux éléments que pour 1-2-3 avec `OneTwoThreeRule.veluteAndSuite`.
    public let figures: [Figure]

    public var kinds: Set<FigureKind> { Set(figures.map(\.kind)) }
    public func contains(_ kind: FigureKind) -> Bool { figures.contains { $0.kind == kind } }
}

/// Fonctions pures de reconnaissance et de calcul. Aucun état.
public enum RollAnalyzer {

    /// Analyse un lancer selon les règles données.
    public static func analyze(_ roll: Roll, rules: RuleSet = .standard) -> RollAnalysis {
        let v = roll.sortedValues          // v[0] ≤ v[1] ≤ v[2]
        let (a, b, c) = (v[0], v[1], v[2])

        // Trois identiques.
        if a == c {
            return RollAnalysis(roll: roll, figures: [.culDeChouette(value: a)])
        }

        // Une paire : soit a == b (paire basse), soit b == c (paire haute).
        if a == b || b == c {
            let pair = b                    // la valeur centrale fait toujours partie de la paire
            let odd = a == b ? c : a
            // Chouette-velute : la paire est forcément la plus petite valeur (x + x = 2x).
            if a == b, pair + pair == odd {
                return RollAnalysis(roll: roll, figures: [.chouetteVelute(pairValue: pair, veluteValue: odd)])
            }
            return RollAnalysis(roll: roll, figures: [.chouette(value: pair)])
        }

        // Trois valeurs distinctes.
        let isVelute = a + b == c
        let isSuite = b == a + 1 && c == b + 1

        switch (isVelute, isSuite) {
        case (true, true):  // uniquement 1-2-3
            switch rules.oneTwoThree {
            case .veluteAndSuite: return RollAnalysis(roll: roll, figures: [.velute(value: c), .suite(lowest: a)])
            case .veluteOnly: return RollAnalysis(roll: roll, figures: [.velute(value: c)])
            case .suiteOnly: return RollAnalysis(roll: roll, figures: [.suite(lowest: a)])
            }
        case (true, false): return RollAnalysis(roll: roll, figures: [.velute(value: c)])
        case (false, true): return RollAnalysis(roll: roll, figures: [.suite(lowest: a)])
        case (false, false): return RollAnalysis(roll: roll, figures: [.neant])
        }
    }

    // MARK: Barème

    public static func chouettePoints(_ value: Int, rules: RuleSet = .standard) -> Int {
        rules.chouetteMultiplier * value * value
    }

    public static func velutePoints(_ value: Int, rules: RuleSet = .standard) -> Int {
        rules.veluteMultiplier * value * value
    }

    public static func culDeChouettePoints(_ value: Int, rules: RuleSet = .standard) -> Int {
        rules.culDeChouetteBase + rules.culDeChouetteStep * value
    }

    /// Points marqués *directement par le lanceur* pour une figure, hors mini-jeux.
    /// La suite (pénalité aux autres) et la chouette-velute (gagnée au réflexe) valent 0 ici.
    public static func rollerPoints(for figure: Figure, rules: RuleSet = .standard) -> Int {
        switch figure {
        case .culDeChouette(let v): culDeChouettePoints(v, rules: rules)
        case .chouette(let v): chouettePoints(v, rules: rules)
        case .velute(let v): velutePoints(v, rules: rules)
        case .chouetteVelute(let pair, _):
            rules.chouetteVeluteRollerKeepsChouette ? chouettePoints(pair, rules: rules) : 0
        case .suite, .neant: 0
        }
    }
}
