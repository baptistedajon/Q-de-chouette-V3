// Teaching.swift
// Outils pour le tutoriel et la partie guidée : exemples de lancers par figure
// et détail du calcul des points. Aucun texte ici : la présentation reste dans l'app.

/// Détail d'un calcul de points, pour l'expliquer pas à pas.
public enum PointsBreakdown: Hashable, Sendable {
    /// `multiplier × value²` (chouette : multiplicateur 1, velute : 2).
    case square(value: Int, multiplier: Int, total: Int)
    /// `base + step × value`.
    case culDeChouette(value: Int, base: Int, step: Int, total: Int)
    /// Pénalité infligée au(x) dernier(s) à crier.
    case suitePenalty(points: Int)
    /// Points de la velute, gagnés par le premier à crier.
    case reflexVelute(value: Int, multiplier: Int, total: Int)
    case none

    public var total: Int {
        switch self {
        case .square(_, _, let total), .culDeChouette(_, _, _, let total), .reflexVelute(_, _, let total): total
        case .suitePenalty(let points): -points
        case .none: 0
        }
    }
}

public extension RollAnalyzer {

    /// Détail du calcul pour une figure, selon les règles.
    static func breakdown(for figure: Figure, rules: RuleSet = .standard) -> PointsBreakdown {
        switch figure {
        case .chouette(let v):
            .square(value: v, multiplier: rules.chouetteMultiplier, total: chouettePoints(v, rules: rules))
        case .velute(let v):
            .square(value: v, multiplier: rules.veluteMultiplier, total: velutePoints(v, rules: rules))
        case .culDeChouette(let v):
            .culDeChouette(value: v, base: rules.culDeChouetteBase, step: rules.culDeChouetteStep,
                           total: culDeChouettePoints(v, rules: rules))
        case .chouetteVelute(_, let velute):
            .reflexVelute(value: velute, multiplier: rules.veluteMultiplier, total: velutePoints(velute, rules: rules))
        case .suite:
            .suitePenalty(points: rules.suitePenalty)
        case .neant:
            .none
        }
    }
}

public extension FigureKind {

    /// Lancers d'exemple pour cette figure : une combinaison par ensemble de valeurs,
    /// dés triés par ordre croissant (ex. 2-2-4 et non 4-2-2).
    /// Seuls les lancers dont c'est la figure *principale* sont retenus
    /// (1-2-3 compte comme velute, pas comme exemple de suite, sauf règle « suite seule »).
    func exampleRolls(rules: RuleSet = .standard) -> [Roll] {
        var seen = Set<[Int]>()
        return Roll.allRolls.compactMap { roll in
            let sorted = roll.sortedValues
            guard seen.insert(sorted).inserted,
                  RollAnalyzer.analyze(roll, rules: rules).figures.first?.kind == self else { return nil }
            return Roll(sorted[0], sorted[1], sorted[2])
        }
    }
}
