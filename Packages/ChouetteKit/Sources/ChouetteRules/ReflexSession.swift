// ReflexSession.swift
// Logique du mini-jeu de réflexe « premier / dernier qui crie », indépendante de l'interface.
// L'interface fournit l'instant du signal et les taps horodatés ; la session
// en déduit un `ReflexOutcome` à transmettre au moteur.

public struct ReflexSession: Hashable, Sendable {

    /// Effet d'un tap enregistré.
    public enum TapResult: Hashable, Sendable {
        /// Tap valide ; `rank` commence à 0 (le plus rapide).
        case accepted(rank: Int)
        /// Tap avant le signal, pénalisé (bévue activée). Le joueur est éliminé du mini-jeu.
        case falseStart
        /// Tap sans effet : avant le signal sans bévue, doublon, joueur éliminé ou non participant.
        case ignored
    }

    public let challenge: ReflexChallenge
    public let bevueEnabled: Bool
    public private(set) var signalTime: Double?
    /// Taps valides triés par instant croissant.
    public private(set) var taps: [(player: PlayerID, time: Double)] = []
    public private(set) var falseStarts: Set<PlayerID> = []

    public init(challenge: ReflexChallenge, rules: RuleSet) {
        self.challenge = challenge
        bevueEnabled = rules.bevue.isEnabled
    }

    public var hasSignaled: Bool { signalTime != nil }

    /// Déclenche le signal (« Criez ! ») à l'instant donné. Sans effet s'il a déjà eu lieu.
    public mutating func signal(at time: Double) {
        if signalTime == nil { signalTime = time }
    }

    @discardableResult
    public mutating func registerTap(by player: PlayerID, at time: Double) -> TapResult {
        guard challenge.participants.contains(player), !falseStarts.contains(player),
              !taps.contains(where: { $0.player == player }) else { return .ignored }

        guard let signalTime, time >= signalTime else {
            guard bevueEnabled else { return .ignored }
            falseStarts.insert(player)
            return .falseStart
        }
        // Les événements tactiles peuvent arriver légèrement dans le désordre :
        // on insère à la bonne place selon l'horodatage.
        let index = taps.firstIndex { $0.time > time } ?? taps.endIndex
        taps.insert((player, time), at: index)
        return .accepted(rank: index)
    }

    /// Joueurs qui peuvent encore taper.
    public var remainingPlayers: [PlayerID] {
        challenge.participants.filter { p in !falseStarts.contains(p) && !taps.contains { $0.player == p } }
    }

    /// Vrai quand le résultat ne peut plus changer : premier tap pour « Pas mou le caillou »,
    /// tous les joueurs restants ont tapé pour « Grelotte ça picote ».
    public var isComplete: Bool {
        switch challenge.kind {
        case .pasMouLeCaillou: !taps.isEmpty || remainingPlayers.isEmpty
        case .grelotteCaPicote: remainingPlayers.isEmpty
        }
    }

    public var outcome: ReflexOutcome {
        ReflexOutcome(tapOrder: taps.map(\.player), falseStarts: falseStarts)
    }

    public static func == (lhs: ReflexSession, rhs: ReflexSession) -> Bool {
        lhs.challenge == rhs.challenge && lhs.bevueEnabled == rhs.bevueEnabled && lhs.signalTime == rhs.signalTime
            && lhs.taps.map(\.player) == rhs.taps.map(\.player) && lhs.taps.map(\.time) == rhs.taps.map(\.time)
            && lhs.falseStarts == rhs.falseStarts
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(challenge)
        hasher.combine(signalTime)
        hasher.combine(taps.map(\.player))
        hasher.combine(falseStarts)
    }
}
