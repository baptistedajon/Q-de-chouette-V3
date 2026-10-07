// RuleSet.swift
// Toutes les règles configurables du jeu. Chaque valeur par défaut correspond
// à la variante documentée dans RULES.md.

/// Ensemble complet des règles d'une partie. Sérialisable pour être enregistré
/// avec la partie : une partie en cours garde ses règles même si les réglages changent.
public struct RuleSet: Hashable, Sendable, Codable {

    // MARK: Fin de partie

    /// Comment se termine la partie.
    public enum VictoryMode: String, Hashable, Sendable, Codable, CaseIterable {
        /// Le premier joueur dont le score atteint ou dépasse la cible gagne.
        case reachOrExceed
        /// Il faut atteindre la cible exactement ; l'excédent est retranché
        /// (ex. cible 343, score 350 → 336).
        case exact
    }

    public var targetScore = 343
    public var victoryMode = VictoryMode.reachOrExceed
    /// Si `false`, un score ne descend jamais sous 0.
    public var allowNegativeScores = true

    // MARK: Barème de base

    /// Chouette : `chouetteMultiplier × valeur²`.
    public var chouetteMultiplier = 1
    /// Velute : `veluteMultiplier × (grand dé)²`.
    public var veluteMultiplier = 2
    /// Cul de chouette : `culDeChouetteBase + culDeChouetteStep × valeur`.
    public var culDeChouetteBase = 40
    public var culDeChouetteStep = 10
    /// Points perdus par le(s) dernier(s) à crier « Grelotte ça picote ! » sur une suite.
    public var suitePenalty = 10

    /// Qui perd des points sur une suite.
    public enum SuiteLosers: String, Hashable, Sendable, Codable, CaseIterable {
        /// Règle traditionnelle : le dernier à crier perd. Ceux qui n'ont pas crié du tout
        /// sont tous à égalité au dernier rang et perdent tous.
        case allLate
        /// Allégée : seuls ceux qui ont tapé comptent ; le plus lent d'entre eux perd.
        /// Personne n'a tapé : personne ne perd.
        case lastTapperOnly
    }

    public var suiteLosers = SuiteLosers.allLate

    // MARK: Cas ambigus

    /// Traitement du lancer 1-2-3, qui est à la fois une velute et une suite.
    public enum OneTwoThreeRule: String, Hashable, Sendable, Codable, CaseIterable {
        /// Le lanceur marque la velute, puis on joue la suite.
        case veluteAndSuite
        case veluteOnly
        case suiteOnly
    }

    public var oneTwoThree = OneTwoThreeRule.veluteAndSuite

    /// Chouette-velute (1-1-2, 2-2-4, 3-3-6) : si `true`, le lanceur marque
    /// en plus les points de sa chouette, quel que soit le gagnant du réflexe.
    public var chouetteVeluteRollerKeepsChouette = false

    // MARK: Règles avancées

    public struct SirotageRules: Hashable, Sendable, Codable {
        public var isEnabled = false
        /// Les autres joueurs peuvent parier sur la valeur du dé relancé.
        public var betsEnabled = true
        /// Points gagnés par chaque parieur qui a vu juste.
        public var betReward = 25
        /// Conséquence d'un sirotage raté.
        public var failure = Failure.loseChouette
        public init() {}

        public enum Failure: String, Hashable, Sendable, Codable, CaseIterable {
            /// Règle traditionnelle : le lanceur perd les points de sa chouette.
            case loseChouette
            /// Allégée : le lanceur ne marque rien, sans perte.
            case scoreNothing
        }
    }

    public struct BevueRules: Hashable, Sendable, Codable {
        public var isEnabled = false
        /// Points perdus pour un faux départ pendant un réflexe.
        public var penalty = 10
        public init() {}
    }

    public struct CivetRules: Hashable, Sendable, Codable {
        public var isEnabled = false
        /// Nombre de civets que chaque joueur peut jouer par partie.
        public var perPlayer = 1
        public var maxStake = 102
        public init() {}
    }

    public struct GrelottineRules: Hashable, Sendable, Codable {
        public var isEnabled = false
        public var maxStake = 50
        /// Allégée : la mise ne peut dépasser ni le score du défieur ni celui de sa cible
        /// (un joueur à 0 point ne peut donc pas être défié). Règle traditionnelle : seul
        /// le plafond `maxStake` s'applique, et les scores peuvent devenir négatifs.
        public var stakeLimitedByScores = false
        public init() {}
    }

    public var sirotage = SirotageRules()
    public var bevue = BevueRules()
    public var civet = CivetRules()
    public var grelottine = GrelottineRules()

    public init() {}

    /// Règles de base uniquement.
    public static let standard = RuleSet()

    /// Toutes les règles avancées activées.
    public static var allAdvanced: RuleSet {
        var rules = RuleSet()
        rules.sirotage.isEnabled = true
        rules.bevue.isEnabled = true
        rules.civet.isEnabled = true
        rules.grelottine.isEnabled = true
        return rules
    }

    // MARK: Règles allégées

    /// Applique les trois variantes allégées (sirotage raté sans perte, seul le plus lent
    /// des joueurs ayant tapé perd sur une suite, mise de grelottine limitée aux scores).
    /// Les autres réglages ne changent pas.
    public mutating func applyLightVariants() {
        sirotage.failure = .scoreNothing
        suiteLosers = .lastTapperOnly
        grelottine.stakeLimitedByScores = true
    }

    /// Vrai si les trois variantes allégées sont actives.
    public var usesLightVariants: Bool {
        sirotage.failure == .scoreNothing && suiteLosers == .lastTapperOnly && grelottine.stakeLimitedByScores
    }

    /// Règles de base avec les variantes allégées.
    public static var light: RuleSet {
        var rules = RuleSet()
        rules.applyLightVariants()
        return rules
    }
}
