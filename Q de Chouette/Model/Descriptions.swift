// Descriptions.swift
// Textes localisés décrivant les éléments du moteur de règles.
// Le moteur reste sans texte : toute la présentation est ici.

import Foundation
import ChouetteRules

extension FigureKind {
    var name: String {
        switch self {
        case .culDeChouette: String(localized: "Cul de chouette")
        case .chouetteVelute: String(localized: "Chouette-velute")
        case .chouette: String(localized: "Chouette")
        case .velute: String(localized: "Velute")
        case .suite: String(localized: "Suite")
        case .neant: String(localized: "Néant")
        }
    }

    /// Ordre d'affichage dans les menus de paris.
    static let betOrder: [FigureKind] = [.chouette, .velute, .suite, .neant, .chouetteVelute, .culDeChouette]
}

extension Figure {
    var name: String {
        switch self {
        case .culDeChouette(let v): String(localized: "Cul de chouette de \(v)")
        case .chouetteVelute(_, let velute): String(localized: "Chouette-velute de \(velute)")
        case .chouette(let v): String(localized: "Chouette de \(v)")
        case .velute(let v): String(localized: "Velute de \(v)")
        case .suite(let low): String(localized: "Suite \(low)-\(low + 1)-\(low + 2)")
        case .neant: String(localized: "Néant")
        }
    }
}

extension RollAnalysis {
    /// Ex. « Velute de 3 + Suite 1-2-3 ».
    var name: String { figures.map(\.name).joined(separator: " + ") }
}

extension ReflexKind {
    /// La phrase à crier.
    var phrase: String {
        switch self {
        case .pasMouLeCaillou: String(localized: "Pas mou le caillou !")
        case .grelotteCaPicote: String(localized: "Grelotte ça picote !")
        }
    }

    var instruction: String {
        switch self {
        case .pasMouLeCaillou: String(localized: "Le premier qui tape gagne la velute.")
        case .grelotteCaPicote: String(localized: "Le dernier qui tape perd des points.")
        }
    }
}

extension ScoreReason {
    var label: String {
        switch self {
        case .figure(let figure): figure.name
        case .chouetteVeluteWon: String(localized: "Pas mou le caillou : velute gagnée")
        case .suitePenalty: String(localized: "Grelotte ça picote : trop lent")
        case .sirotageSuccess: String(localized: "Sirotage réussi")
        case .sirotageFailure: String(localized: "Sirotage raté")
        case .sirotageBetWon(let face): String(localized: "Pari gagné sur le \(face)")
        case .bevue: String(localized: "Bévue : faux départ")
        case .civetWon(let kind): String(localized: "Civet gagné (\(kind.name))")
        case .civetLost(let kind): String(localized: "Civet perdu (\(kind.name))")
        case .grelottineWon(let kind): String(localized: "Grelottine gagnée (\(kind.name))")
        case .grelottineLost(let kind): String(localized: "Grelottine perdue (\(kind.name))")
        }
    }
}

extension Int {
    /// « point » ou « points » (en français, 0 et 1 sont au singulier).
    var pointsUnit: String {
        abs(self) <= 1 ? String(localized: "point") : String(localized: "points")
    }

    /// « +16 », « −10 » (vrai signe moins), « 0 ».
    var signedPoints: String {
        if self > 0 { return "+\(self)" }
        if self < 0 { return "−\(-self)" }
        return "0"
    }
}

// MARK: - Explications (tutoriel, partie guidée)

extension PointsBreakdown {
    /// Ex. « 4 × 4 = 16 », « 2 × 5 × 5 = 50 », « 40 + 10 × 3 = 70 ».
    var formula: String {
        switch self {
        case .square(let v, let m, let t), .reflexVelute(let v, let m, let t):
            m == 1 ? "\(v) × \(v) = \(t)" : "\(m) × \(v) × \(v) = \(t)"
        case .culDeChouette(let v, let base, let step, let t):
            "\(base) + \(step) × \(v) = \(t)"
        case .suitePenalty(let points):
            (-points).signedPoints
        case .none:
            "0"
        }
    }
}

extension FigureKind {
    /// Définition de la figure et de ce qu'elle rapporte, selon les règles en vigueur.
    func rule(_ rules: RuleSet) -> String {
        switch self {
        case .chouette:
            String(localized: "Deux dés identiques. Le lanceur marque la valeur du dé au carré.")
        case .velute:
            String(localized: "La somme de deux dés est égale au troisième. Le lanceur marque deux fois le carré du plus grand dé.")
        case .culDeChouette:
            String(localized: "Trois dés identiques. Le lanceur marque \(rules.culDeChouetteBase) points, plus \(rules.culDeChouetteStep) fois la valeur du dé.")
        case .chouetteVelute:
            String(localized: "Une chouette qui est aussi une velute : 1-1-2, 2-2-4 ou 3-3-6. Le premier joueur qui tape sa zone en criant « Pas mou le caillou ! » remporte les points de la velute.")
        case .suite:
            String(localized: "Trois valeurs qui se suivent. Tous les joueurs tapent leur zone en criant « Grelotte ça picote ! » : le plus lent perd \(rules.suitePenalty) points.")
        case .neant:
            String(localized: "Aucune combinaison : le lanceur ne marque rien.")
        }
    }

    /// Symbole SF illustrant la figure.
    var symbolName: String {
        switch self {
        case .culDeChouette: "crown.fill"
        case .chouetteVelute: "hand.raised.fill"
        case .chouette: "circle.grid.2x1.fill"
        case .velute: "equal.circle"
        case .suite: "stairs"
        case .neant: "circle.dashed"
        }
    }

    /// Ordre de présentation dans les règles : du plus courant au plus spectaculaire.
    static let teachingOrder: [FigureKind] = [.chouette, .velute, .culDeChouette, .chouetteVelute, .suite, .neant]
}
