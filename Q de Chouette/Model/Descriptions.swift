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
    /// « +16 », « −10 » (vrai signe moins), « 0 ».
    var signedPoints: String {
        if self > 0 { return "+\(self)" }
        if self < 0 { return "−\(-self)" }
        return "0"
    }
}
