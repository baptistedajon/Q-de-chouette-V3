// Coach.swift
// Partie guidée : explique en direct chaque lancer et chaque situation,
// à partir des événements du moteur.

import Foundation
import ChouetteRules

/// Un conseil affiché pendant la partie guidée.
struct CoachTip: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let body: String
}

enum Coach {

    /// Conseil d'ouverture, avant le premier lancer.
    static func welcome(rules: RuleSet, firstPlayer: String) -> CoachTip {
        CoachTip(title: String(localized: "Bienvenue à la table !"),
                 body: String(localized: "Chacun son tour, on lance trois dés et on cherche des combinaisons qui rapportent des points. Le premier à \(rules.targetScore) points gagne. \(firstPlayer), à vous : lancez les dés, je vous explique chaque résultat."))
    }

    /// Conseil après un lancer, selon ses figures.
    static func tip(for analysis: RollAnalysis, player: String, rules: RuleSet,
                    grantedGrelottine: Bool) -> CoachTip {
        let paragraphs = analysis.figures.map { explanation(of: $0, roll: analysis.roll, player: player, rules: rules) }
        var body = paragraphs.joined(separator: "\n\n")
        if grantedGrelottine {
            body += "\n\n" + String(localized: "Consolation : \(player) gagne une grelottine. Au début d'un prochain tour, elle permet de défier un autre joueur sur une figure, avec une mise.")
        }
        return CoachTip(title: analysis.name, body: body)
    }

    private static func explanation(of figure: Figure, roll: Roll, player: String, rules: RuleSet) -> String {
        let breakdown = RollAnalyzer.breakdown(for: figure, rules: rules)
        let formula = breakdown.formula
        let total = breakdown.total
        let v = roll.sortedValues
        switch figure {
        case .chouette(let value):
            var text = String(localized: "Deux dés identiques : c'est une chouette. Elle rapporte la valeur au carré : \(formula) \(total.pointsUnit) pour \(player).")
            if rules.sirotage.isEnabled {
                text += " " + String(localized: "\(player) peut aussi siroter : relancer le dernier dé en espérant un \(value). Réussi, c'est un cul de chouette ; raté, la chouette est perdue.")
            }
            return text
        case .velute:
            return String(localized: "\(v[0]) + \(v[1]) = \(v[2]) : la somme de deux dés donne le troisième, c'est une velute. Elle rapporte deux fois le carré du grand dé : \(formula) \(total.pointsUnit) pour \(player).")
        case .culDeChouette:
            return String(localized: "Trois dés identiques : le fameux cul de chouette ! \(formula) \(total.pointsUnit) pour \(player).")
        case .chouetteVelute(let pair, let velute):
            return String(localized: "\(pair) et \(pair) font une chouette, et \(pair) + \(pair) = \(velute) fait une velute ! Dans ce cas, tout le monde peut gagner : le premier qui tape sa zone en criant « Pas mou le caillou ! » remporte \(formula) \(total.pointsUnit).")
        case .suite(let low):
            return String(localized: "\(low), \(low + 1), \(low + 2) se suivent : c'est une suite. Tout le monde doit taper sa zone en criant « Grelotte ça picote ! » dès le signal. Le plus lent perd \(rules.suitePenalty) points.")
        case .neant:
            return String(localized: "Aucune combinaison : c'est un néant, pas de points ce tour-ci.")
        }
    }

    /// Conseil après un mini-jeu de réflexe : qui gagne ou perd, et pourquoi.
    static func reflexOutcome(_ challenge: ReflexChallenge, winners: [PlayerID], losers: [PlayerID],
                              names: (PlayerID) -> String) -> CoachTip {
        let body: String
        switch challenge.kind {
        case .pasMouLeCaillou:
            if let winner = winners.first {
                body = String(localized: "\(names(winner)) a été le plus rapide et remporte \(challenge.points) points.")
            } else {
                body = String(localized: "Personne n'a tapé à temps : la velute n'est attribuée à personne.")
            }
        case .grelotteCaPicote:
            switch losers.count {
            case 0:
                body = String(localized: "Personne ne perd de points cette fois.")
            case 1:
                body = String(localized: "\(names(losers[0])) a été le plus lent et perd \(challenge.points) points.")
            default:
                let list = losers.map(names).formatted(.list(type: .and))
                body = String(localized: "\(list) n'ont pas tapé à temps et perdent \(challenge.points) points chacun.")
            }
        }
        return CoachTip(title: String(localized: "Résultat du cri"), body: body)
    }

    /// Conseil pendant les paris du sirotage.
    static func sirotageBets(rules: RuleSet) -> CoachTip {
        CoachTip(title: String(localized: "Les paris sont ouverts"),
                 body: String(localized: "Avant la relance, les autres joueurs peuvent parier sur la valeur du dé. Chaque pari juste rapporte \(rules.sirotage.betReward) points, que le sirotage réussisse ou non."))
    }

    /// Conseil avant un mini-jeu de réflexe : on laisse le temps de se préparer.
    static func reflexBriefing(_ challenge: ReflexChallenge) -> CoachTip {
        switch challenge.kind {
        case .pasMouLeCaillou:
            CoachTip(title: String(localized: "Préparez-vous à crier !"),
                     body: String(localized: "Posez le téléphone au milieu de la table. Chacun a sa zone. Au signal, tapez la vôtre en criant « Pas mou le caillou ! ». Le plus rapide gagne \(challenge.points) points. Taper trop tôt ne compte pas."))
        case .grelotteCaPicote:
            CoachTip(title: String(localized: "Préparez-vous à crier !"),
                     body: String(localized: "Posez le téléphone au milieu de la table. Chacun a sa zone. Au signal, tapez la vôtre en criant « Grelotte ça picote ! ». Le plus lent perd \(challenge.points) points."))
        }
    }
}
