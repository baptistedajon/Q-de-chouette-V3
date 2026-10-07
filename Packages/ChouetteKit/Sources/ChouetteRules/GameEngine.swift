// GameEngine.swift
// Machine à états d'une partie. Valeur pure et déterministe : on applique des actions,
// on récupère des événements. Pour annuler un coup, il suffit de garder une copie.

public struct GameEngine: Hashable, Sendable, Codable {

    public static let playerRange = 2...8

    public let rules: RuleSet
    public private(set) var players: [PlayerState]
    public private(set) var currentPlayer: PlayerID
    public private(set) var phase: GamePhase = .awaitingRoll
    /// Tour en cours (pas encore dans `history`).
    public private(set) var currentTurn: TurnRecord
    /// Tours terminés, du plus ancien au plus récent.
    public private(set) var history: [TurnRecord] = []
    /// Civet déclaré pour le lancer à venir.
    public private(set) var pendingCivet: Civet?
    /// Figures restant à résoudre après un mini-jeu (cas 1-2-3 : velute puis suite).
    private var pendingFigures: [Figure] = []

    public init(playerNames: [String], rules: RuleSet = .standard, firstPlayer: PlayerID = 0) throws(GameError) {
        guard Self.playerRange.contains(playerNames.count) else {
            throw .invalidPlayerCount(playerNames.count)
        }
        guard playerNames.indices.contains(firstPlayer) else { throw .invalidFirstPlayer }
        self.rules = rules
        let civets = rules.civet.isEnabled ? rules.civet.perPlayer : 0
        players = playerNames.enumerated().map { PlayerState(id: $0.offset, name: $0.element, civetsLeft: civets) }
        currentPlayer = firstPlayer
        currentTurn = TurnRecord(number: 1, player: firstPlayer)
    }

    // MARK: - Requêtes pour l'interface

    public var isOver: Bool {
        if case .gameOver = phase { true } else { false }
    }

    public var winner: PlayerID? {
        if case .gameOver(let w) = phase { w } else { nil }
    }

    /// Vrai tant que le joueur courant n'a pas encore lancé les dés principaux de son tour.
    private var isBeforeMainRoll: Bool {
        phase == .awaitingRoll && currentTurn.roll == nil
    }

    public var canDeclareCivet: Bool {
        rules.civet.isEnabled && isBeforeMainRoll && pendingCivet == nil
            && players[currentPlayer].civetsLeft > 0
    }

    public var canLaunchGrelottine: Bool {
        rules.grelottine.isEnabled && isBeforeMainRoll && players[currentPlayer].hasGrelottine
            && !grelottineTargets.isEmpty
    }

    /// Joueurs que le joueur courant peut défier (mise possible d'au moins 1 point).
    public var grelottineTargets: [PlayerID] {
        players.map(\.id).filter { $0 != currentPlayer && grelottineMaxStake(against: $0) >= 1 }
    }

    /// Mise maximale d'une grelottine : le plafond des règles, et en variante allégée
    /// pas plus que ce que chacun des deux joueurs possède.
    public func grelottineMaxStake(against target: PlayerID) -> Int {
        guard players.indices.contains(target) else { return 0 }
        guard rules.grelottine.stakeLimitedByScores else { return rules.grelottine.maxStake }
        return min(rules.grelottine.maxStake, players[currentPlayer].score, players[target].score)
    }

    // MARK: - Application des actions

    /// Applique une action et retourne les événements produits, dans l'ordre.
    /// En cas d'erreur, l'état n'est pas modifié.
    @discardableResult
    public mutating func apply(_ action: GameAction) throws(GameError) -> [GameEvent] {
        var copy = self
        var events: [GameEvent] = []
        try copy.perform(action, events: &events)
        self = copy
        return events
    }

    private mutating func perform(_ action: GameAction, events: inout [GameEvent]) throws(GameError) {
        switch (action, phase) {

        case (.declareCivet(let figure, let stake), .awaitingRoll):
            guard canDeclareCivet else { throw .civetUnavailable }
            guard (1...rules.civet.maxStake).contains(stake) else { throw .invalidStake }
            let civet = Civet(player: currentPlayer, figure: figure, stake: stake)
            players[currentPlayer].civetsLeft -= 1
            pendingCivet = civet
            events.append(.civetDeclared(civet))

        case (.launchGrelottine(let target, let figure, let stake), .awaitingRoll):
            guard canLaunchGrelottine else { throw .grelottineUnavailable }
            guard grelottineTargets.contains(target) else { throw .invalidTarget }
            guard (1...grelottineMaxStake(against: target)).contains(stake) else { throw .invalidStake }
            let challenge = GrelottineChallenge(challenger: currentPlayer, target: target, figure: figure, stake: stake)
            players[currentPlayer].hasGrelottine = false
            phase = .awaitingGrelottineRoll(challenge)
            events.append(.grelottineLaunched(challenge))

        case (.grelottineRoll(let roll), .awaitingGrelottineRoll(let challenge)):
            currentTurn.grelottineRolls.append(roll)
            let analysis = RollAnalyzer.analyze(roll, rules: rules)
            let success = analysis.contains(challenge.figure)
            events.append(.grelottineResolved(challenge, analysis: analysis, success: success))
            let (winner, loser) = success ? (challenge.target, challenge.challenger) : (challenge.challenger, challenge.target)
            changeScore(winner, by: challenge.stake, reason: .grelottineWon(challenge.figure), events: &events)
            changeScore(loser, by: -challenge.stake, reason: .grelottineLost(challenge.figure), events: &events)
            phase = .awaitingRoll
            // Une grelottine peut faire gagner la partie en plein tour.
            if checkVictory(events: &events) { history.append(currentTurn) }

        case (.roll(let roll), .awaitingRoll):
            guard currentTurn.roll == nil else { throw .actionNotAllowed }
            currentTurn.roll = roll
            let analysis = RollAnalyzer.analyze(roll, rules: rules)
            events.append(.rolled(currentPlayer, analysis))
            resolveCivet(with: analysis, events: &events)
            pendingFigures = analysis.figures
            continueResolution(events: &events)

        case (.decideSirotage(let accept), .awaitingSirotageDecision(let pair)):
            if !accept {
                changeScore(currentPlayer, by: RollAnalyzer.chouettePoints(pair, rules: rules),
                            reason: .figure(.chouette(value: pair)), events: &events)
                continueResolution(events: &events)
            } else if rules.sirotage.betsEnabled {
                phase = .awaitingSirotageBets(pairValue: pair)
                events.append(.sirotageBetsOpened(pairValue: pair))
            } else {
                phase = .awaitingSirotageRoll(pairValue: pair, bets: [:])
            }

        case (.placeSirotageBets(let bets), .awaitingSirotageBets(let pair)):
            let valid = bets.allSatisfy { player, face in
                player != currentPlayer && players.indices.contains(player) && (1...6).contains(face)
            }
            guard valid else { throw .invalidBet }
            phase = .awaitingSirotageRoll(pairValue: pair, bets: bets)

        case (.sirotageRoll(let face), .awaitingSirotageRoll(let pair, let bets)):
            currentTurn.sirotageFace = face
            let success = face.value == pair
            events.append(.sirotageResolved(face: face, success: success))
            if success {
                changeScore(currentPlayer, by: RollAnalyzer.culDeChouettePoints(pair, rules: rules),
                            reason: .sirotageSuccess(pairValue: pair), events: &events)
            } else if rules.sirotage.failure == .loseChouette {
                changeScore(currentPlayer, by: -RollAnalyzer.chouettePoints(pair, rules: rules),
                            reason: .sirotageFailure(pairValue: pair), events: &events)
            }
            for (player, bet) in bets.sorted(by: { $0.key < $1.key }) where bet == face.value {
                changeScore(player, by: rules.sirotage.betReward, reason: .sirotageBetWon(face: bet), events: &events)
            }
            continueResolution(events: &events)

        case (.resolveReflex(let outcome), .awaitingReflex(let challenge)):
            try resolveReflex(challenge, outcome: outcome, events: &events)
            continueResolution(events: &events)

        default:
            throw .actionNotAllowed
        }
    }

    // MARK: - Résolution d'un lancer

    /// Résout les figures restantes une à une. S'arrête (en changeant de phase)
    /// dès qu'une figure demande une interaction ; termine le tour sinon.
    private mutating func continueResolution(events: inout [GameEvent]) {
        while !pendingFigures.isEmpty {
            let figure = pendingFigures.removeFirst()
            switch figure {
            case .neant:
                if rules.grelottine.isEnabled && !players[currentPlayer].hasGrelottine {
                    players[currentPlayer].hasGrelottine = true
                    events.append(.grelottineGranted(currentPlayer))
                }

            case .chouette(let pair) where rules.sirotage.isEnabled:
                phase = .awaitingSirotageDecision(pairValue: pair)
                events.append(.sirotageOffered(currentPlayer, pairValue: pair))
                return

            case .culDeChouette, .chouette, .velute:
                changeScore(currentPlayer, by: RollAnalyzer.rollerPoints(for: figure, rules: rules),
                            reason: .figure(figure), events: &events)

            case .chouetteVelute(let pair, let velute):
                if rules.chouetteVeluteRollerKeepsChouette {
                    changeScore(currentPlayer, by: RollAnalyzer.chouettePoints(pair, rules: rules),
                                reason: .figure(figure), events: &events)
                }
                startReflex(.pasMouLeCaillou, for: figure, points: RollAnalyzer.velutePoints(velute, rules: rules), events: &events)
                return

            case .suite:
                startReflex(.grelotteCaPicote, for: figure, points: rules.suitePenalty, events: &events)
                return
            }
        }
        endTurn(events: &events)
    }

    private mutating func startReflex(_ kind: ReflexKind, for figure: Figure, points: Int, events: inout [GameEvent]) {
        let challenge = ReflexChallenge(kind: kind, figure: figure, participants: players.map(\.id), points: points)
        phase = .awaitingReflex(challenge)
        events.append(.reflexStarted(challenge))
    }

    private mutating func resolveReflex(_ challenge: ReflexChallenge, outcome: ReflexOutcome,
                                        events: inout [GameEvent]) throws(GameError) {
        let participants = Set(challenge.participants)
        guard Set(outcome.tapOrder).count == outcome.tapOrder.count,
              participants.isSuperset(of: outcome.tapOrder),
              participants.isSuperset(of: outcome.falseStarts) else {
            throw .invalidReflexOutcome
        }

        var winners: [PlayerID] = []
        var losers: [PlayerID] = []
        switch challenge.kind {
        case .pasMouLeCaillou:
            // Le plus rapide gagne la velute. Personne n'a tapé : personne ne marque.
            if let first = outcome.tapOrder.first {
                winners = [first]
                if case .chouetteVelute(_, let velute) = challenge.figure {
                    changeScore(first, by: challenge.points, reason: .chouetteVeluteWon(veluteValue: velute), events: &events)
                }
            }
        case .grelotteCaPicote:
            switch rules.suiteLosers {
            case .allLate:
                // Ceux qui n'ont pas tapé perdent tous ; si tout le monde a tapé, le dernier perd.
                let silent = challenge.participants.filter { !outcome.tapOrder.contains($0) }
                if !silent.isEmpty {
                    losers = silent
                } else if let last = outcome.tapOrder.last {
                    losers = [last]
                }
            case .lastTapperOnly:
                losers = outcome.tapOrder.last.map { [$0] } ?? []
            }
            for loser in losers {
                changeScore(loser, by: -challenge.points, reason: .suitePenalty, events: &events)
            }
        }

        if rules.bevue.isEnabled {
            for player in challenge.participants where outcome.falseStarts.contains(player) {
                changeScore(player, by: -rules.bevue.penalty, reason: .bevue, events: &events)
            }
        }
        events.append(.reflexResolved(challenge, winners: winners, losers: losers))
    }

    private mutating func resolveCivet(with analysis: RollAnalysis, events: inout [GameEvent]) {
        guard let civet = pendingCivet else { return }
        pendingCivet = nil
        if analysis.contains(civet.figure) {
            changeScore(civet.player, by: civet.stake, reason: .civetWon(civet.figure), events: &events)
        } else {
            changeScore(civet.player, by: -civet.stake, reason: .civetLost(civet.figure), events: &events)
        }
    }

    // MARK: - Score, fin de tour, victoire

    private mutating func changeScore(_ player: PlayerID, by delta: Int, reason: ScoreReason,
                                      events: inout [GameEvent]) {
        guard delta != 0 else { return }
        let old = players[player].score
        var new = old + delta
        if rules.victoryMode == .exact, new > rules.targetScore {
            new = 2 * rules.targetScore - new        // l'excédent est retranché
        }
        if !rules.allowNegativeScores { new = max(0, new) }
        guard new != old else { return }
        players[player].score = new
        let change = ScoreChange(player: player, delta: new - old, reason: reason)
        currentTurn.changes.append(change)
        events.append(.scoreChanged(change, newScore: new))
    }

    private mutating func endTurn(events: inout [GameEvent]) {
        phase = .awaitingRoll
        history.append(currentTurn)
        events.append(.turnEnded(currentTurn))
        guard !checkVictory(events: &events) else { return }
        currentPlayer = (currentPlayer + 1) % players.count
        currentTurn = TurnRecord(number: currentTurn.number + 1, player: currentPlayer)
        events.append(.turnStarted(currentPlayer))
    }

    /// Termine la partie si au moins un joueur a atteint la cible.
    /// Plusieurs candidats : le meilleur score l'emporte ; à égalité, le plus proche
    /// du joueur courant dans l'ordre de jeu (le joueur courant en premier).
    /// Retourne `true` si la partie vient de se terminer.
    private mutating func checkVictory(events: inout [GameEvent]) -> Bool {
        let target = rules.targetScore
        let mode = rules.victoryMode
        let n = players.count
        let ordered = (0..<n).map { players[(currentPlayer + $0) % n] }
        let candidates = ordered.filter { mode == .exact ? $0.score == target : $0.score >= target }
        guard let best = candidates.max(by: { $0.score < $1.score }),
              let winner = candidates.first(where: { $0.score == best.score }) else { return false }
        phase = .gameOver(winner: winner.id)
        events.append(.gameOver(winner: winner.id))
        return true
    }
}
