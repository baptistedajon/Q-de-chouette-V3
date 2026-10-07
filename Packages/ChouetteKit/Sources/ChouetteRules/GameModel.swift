// GameModel.swift
// Types décrivant l'état d'une partie, les actions possibles et les événements produits.

/// Identifiant d'un joueur : son index dans l'ordre de jeu (0…n-1).
public typealias PlayerID = Int

public struct PlayerState: Hashable, Sendable, Codable, Identifiable {
    public let id: PlayerID
    public var name: String
    public var score = 0
    /// Civets encore disponibles pour ce joueur.
    public var civetsLeft: Int
    /// Le joueur détient une grelottine (obtenue sur un néant).
    public var hasGrelottine = false
}

// MARK: - Mini-jeux et paris

/// Les deux phrases à crier.
public enum ReflexKind: String, Hashable, Sendable, Codable {
    /// Chouette-velute : le *premier* à crier « Pas mou le caillou ! » gagne la velute.
    case pasMouLeCaillou
    /// Suite : le(s) *dernier(s)* à crier « Grelotte ça picote ! » perd/perdent des points.
    case grelotteCaPicote
}

extension ReflexKind: Identifiable {
    public var id: String { rawValue }
}

/// Un mini-jeu de réflexe en attente de résultat.
public struct ReflexChallenge: Hashable, Sendable, Codable {
    public let kind: ReflexKind
    /// Figure à l'origine du mini-jeu (chouette-velute ou suite).
    public let figure: Figure
    /// Joueurs concernés, dans l'ordre de jeu (tous les joueurs, lanceur compris).
    public let participants: [PlayerID]
    /// Points gagnés (pas mou le caillou) ou perdus (grelotte ça picote).
    public let points: Int
}

public extension ReflexChallenge {
    /// Gagnant d'un « Pas mou le caillou » : le plus rapide, s'il y en a un.
    func winners(for outcome: ReflexOutcome) -> [PlayerID] {
        guard kind == .pasMouLeCaillou, let first = outcome.tapOrder.first else { return [] }
        return [first]
    }

    /// Perdants d'un « Grelotte ça picote », selon la règle choisie.
    func losers(for outcome: ReflexOutcome, rules: RuleSet) -> [PlayerID] {
        guard kind == .grelotteCaPicote else { return [] }
        switch rules.suiteLosers {
        case .allLate:
            // Ceux qui n'ont pas tapé perdent tous ; si tout le monde a tapé, le dernier perd.
            let silent = participants.filter { !outcome.tapOrder.contains($0) }
            return silent.isEmpty ? Array(outcome.tapOrder.suffix(1)) : silent
        case .lastTapperOnly:
            return Array(outcome.tapOrder.suffix(1))
        }
    }
}

/// Résultat d'un mini-jeu de réflexe, mesuré par l'interface.
public struct ReflexOutcome: Hashable, Sendable, Codable {
    /// Joueurs ayant tapé à temps, du plus rapide au plus lent. Sans doublon.
    public var tapOrder: [PlayerID]
    /// Joueurs ayant tapé avant le signal (pénalisés si la bévue est activée).
    public var falseStarts: Set<PlayerID>

    public init(tapOrder: [PlayerID], falseStarts: Set<PlayerID> = []) {
        self.tapOrder = tapOrder
        self.falseStarts = falseStarts
    }
}

/// Pari du lanceur sur la figure de son prochain lancer.
public struct Civet: Hashable, Sendable, Codable {
    public let player: PlayerID
    public let figure: FigureKind
    public let stake: Int
}

/// Défi lancé par le détenteur d'une grelottine à un autre joueur.
public struct GrelottineChallenge: Hashable, Sendable, Codable {
    public let challenger: PlayerID
    public let target: PlayerID
    public let figure: FigureKind
    public let stake: Int
}

// MARK: - Phases

/// Ce que la partie attend pour avancer.
public enum GamePhase: Hashable, Sendable, Codable {
    /// Le joueur courant doit lancer. Il peut avant cela jouer un civet ou une grelottine.
    case awaitingRoll
    /// Le joueur défié par une grelottine doit lancer les trois dés.
    case awaitingGrelottineRoll(GrelottineChallenge)
    /// Le lanceur a fait une chouette et choisit de siroter ou non.
    case awaitingSirotageDecision(pairValue: Int)
    /// Les autres joueurs parient sur la valeur du dé relancé.
    case awaitingSirotageBets(pairValue: Int)
    /// Le lanceur relance le dé restant.
    case awaitingSirotageRoll(pairValue: Int, bets: [PlayerID: Int])
    /// Un mini-jeu de réflexe est en cours.
    case awaitingReflex(ReflexChallenge)
    /// Partie terminée.
    case gameOver(winner: PlayerID)
}

// MARK: - Actions

public enum GameAction: Hashable, Sendable, Codable {
    /// Le joueur courant parie `stake` points sur la figure de son lancer à venir.
    case declareCivet(figure: FigureKind, stake: Int)
    /// Le joueur courant utilise sa grelottine contre `target`.
    case launchGrelottine(target: PlayerID, figure: FigureKind, stake: Int)
    /// Résultat du lancer de trois dés du joueur courant.
    case roll(Roll)
    /// Résultat du lancer du joueur défié par une grelottine.
    case grelottineRoll(Roll)
    /// Décision de siroter (`true`) ou d'encaisser la chouette (`false`).
    case decideSirotage(Bool)
    /// Paris des autres joueurs (valeur 1…6) ; les absents ne parient pas.
    case placeSirotageBets([PlayerID: Int])
    /// Valeur du dé relancé pendant le sirotage.
    case sirotageRoll(DieFace)
    /// Résultat du mini-jeu de réflexe.
    case resolveReflex(ReflexOutcome)
}

// MARK: - Historique

/// Pourquoi un score a changé.
public enum ScoreReason: Hashable, Sendable, Codable {
    case figure(Figure)
    case chouetteVeluteWon(veluteValue: Int)
    case suitePenalty
    case sirotageSuccess(pairValue: Int)
    case sirotageFailure(pairValue: Int)
    case sirotageBetWon(face: Int)
    case bevue
    case civetWon(FigureKind)
    case civetLost(FigureKind)
    case grelottineWon(FigureKind)
    case grelottineLost(FigureKind)
}

public struct ScoreChange: Hashable, Sendable, Codable {
    public let player: PlayerID
    /// Variation réellement appliquée (après plancher à 0 ou retranchement en mode exact).
    public let delta: Int
    public let reason: ScoreReason
}

/// Un tour complet d'un joueur.
public struct TurnRecord: Hashable, Sendable, Codable {
    public let number: Int
    public let player: PlayerID
    /// Lancers successifs du tour : lancer principal, puis éventuel dé de sirotage
    /// (enregistré dans `sirotageFace`), et lancers de grelottine dans `grelottineRolls`.
    public var roll: Roll?
    public var sirotageFace: DieFace?
    public var grelottineRolls: [Roll] = []
    public var changes: [ScoreChange] = []

    public init(number: Int, player: PlayerID) {
        self.number = number
        self.player = player
    }
}

// MARK: - Événements

/// Ce qui vient de se passer, pour l'animation, les sons et la partie guidée.
public enum GameEvent: Hashable, Sendable, Codable {
    case civetDeclared(Civet)
    case grelottineLaunched(GrelottineChallenge)
    case grelottineResolved(GrelottineChallenge, analysis: RollAnalysis, success: Bool)
    case grelottineGranted(PlayerID)
    case rolled(PlayerID, RollAnalysis)
    case scoreChanged(ScoreChange, newScore: Int)
    case sirotageOffered(PlayerID, pairValue: Int)
    case sirotageBetsOpened(pairValue: Int)
    case sirotageResolved(face: DieFace, success: Bool)
    case reflexStarted(ReflexChallenge)
    case reflexResolved(ReflexChallenge, winners: [PlayerID], losers: [PlayerID])
    case turnEnded(TurnRecord)
    case turnStarted(PlayerID)
    case gameOver(winner: PlayerID)
}

// MARK: - Erreurs

public enum GameError: Error, Hashable, Sendable {
    case invalidPlayerCount(Int)
    case invalidFirstPlayer
    /// L'action n'est pas permise dans la phase actuelle.
    case actionNotAllowed
    case civetUnavailable
    case grelottineUnavailable
    case invalidStake
    case invalidTarget
    case invalidBet
    case invalidReflexOutcome
}
