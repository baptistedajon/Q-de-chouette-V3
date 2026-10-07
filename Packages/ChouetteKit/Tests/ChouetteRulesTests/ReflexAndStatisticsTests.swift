import Testing
@testable import ChouetteRules

@Suite("Mini-jeu de réflexe")
struct ReflexSessionTests {

    private func challenge(_ kind: ReflexKind, players: Int = 3) -> ReflexChallenge {
        ReflexChallenge(kind: kind, figure: kind == .pasMouLeCaillou ? .chouetteVelute(pairValue: 2, veluteValue: 4) : .suite(lowest: 2),
                        participants: Array(0..<players), points: kind == .pasMouLeCaillou ? 32 : 10)
    }

    @Test("Pas mou le caillou : terminé au premier tap valide")
    func pasMouCompletesOnFirstTap() {
        var session = ReflexSession(challenge: challenge(.pasMouLeCaillou), rules: .standard)
        #expect(session.registerTap(by: 1, at: 0.5) == .ignored, "Avant le signal, sans bévue : ignoré")
        session.signal(at: 1.0)
        #expect(!session.isComplete)
        #expect(session.registerTap(by: 2, at: 1.3) == .accepted(rank: 0))
        #expect(session.isComplete)
        #expect(session.outcome == ReflexOutcome(tapOrder: [2]))
    }

    @Test("Les taps sont classés par horodatage, même reçus dans le désordre")
    func ordering() {
        var session = ReflexSession(challenge: challenge(.grelotteCaPicote), rules: .standard)
        session.signal(at: 0)
        #expect(session.registerTap(by: 0, at: 0.40) == .accepted(rank: 0))
        #expect(session.registerTap(by: 1, at: 0.20) == .accepted(rank: 0))
        #expect(session.registerTap(by: 0, at: 0.10) == .ignored, "Doublon")
        #expect(!session.isComplete)
        #expect(session.remainingPlayers == [2])
        #expect(session.registerTap(by: 2, at: 0.30) == .accepted(rank: 1))
        #expect(session.isComplete)
        #expect(session.outcome.tapOrder == [1, 2, 0])
    }

    @Test("Bévue : faux départ pénalisé et joueur éliminé")
    func falseStart() {
        var session = ReflexSession(challenge: challenge(.grelotteCaPicote), rules: .allAdvanced)
        #expect(session.registerTap(by: 1, at: 0.1) == .falseStart)
        session.signal(at: 1)
        #expect(session.registerTap(by: 1, at: 1.2) == .ignored)
        session.registerTap(by: 0, at: 1.3)
        session.registerTap(by: 2, at: 1.4)
        #expect(session.isComplete)
        #expect(session.outcome == ReflexOutcome(tapOrder: [0, 2], falseStarts: [1]))
    }

    @Test("Joueur non participant ignoré ; signal unique")
    func edgeCases() {
        var session = ReflexSession(challenge: challenge(.pasMouLeCaillou, players: 2), rules: .standard)
        session.signal(at: 1)
        session.signal(at: 5)
        #expect(session.signalTime == 1)
        #expect(session.registerTap(by: 4, at: 2) == .ignored)
    }

    @Test("Le résultat est accepté par le moteur")
    func integrationWithEngine() throws {
        var game = try makeGame(rules: .allAdvanced)
        try game.roll(2, 3, 4)
        let challenge = try #require(game.reflex)
        var session = ReflexSession(challenge: challenge, rules: game.rules)
        session.registerTap(by: 2, at: 0)
        session.signal(at: 1)
        session.registerTap(by: 0, at: 1.1)
        session.registerTap(by: 1, at: 1.2)
        try game.apply(.resolveReflex(session.outcome))
        // J2 faux départ : −10 (bévue), puis éliminé donc considéré comme silencieux : −10.
        // Un joueur silencieux existe, donc J1 (dernier à avoir tapé) ne perd rien.
        #expect(game.scores == [0, 0, -20])
    }
}

@Suite("Statistiques")
struct StatisticsTests {

    @Test func basicStatistics() throws {
        var game = try makeGame(players: 2)
        try game.roll(4, 4, 1)                                         // J0 chouette +16
        try game.roll(2, 2, 4)                                         // J1 chouette-velute
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [0])))   // J0 +32
        try game.roll(2, 3, 4)                                         // J0 suite
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [0, 1]))) // J1 −10
        try game.roll(6, 6, 6)                                         // J1 +100

        let stats = GameStatistics.compute(for: game)
        #expect(stats[0].turns == 2)
        #expect(stats[0].count(.chouette) == 1)
        #expect(stats[0].count(.suite) == 1)
        #expect(stats[0].pointsGained == 48)
        #expect(stats[0].bestTurn == 32)
        #expect(stats[0].reflexWins == 1)
        #expect(stats[1].turns == 2)
        #expect(stats[1].count(.chouetteVelute) == 1)
        #expect(stats[1].count(.culDeChouette) == 1)
        #expect(stats[1].pointsLost == 10)
        #expect(stats[1].suitePenalties == 1)
        #expect(stats[1].bestTurn == 100)
    }

    @Test("Le tour en cours est compté, sans doublon en fin de partie")
    func currentTurnCounted() throws {
        var rules = RuleSet()
        rules.targetScore = 50
        var game = try makeGame(players: 2, rules: rules)
        try game.roll(2, 3, 4)
        #expect(GameStatistics.compute(for: game)[0].turns == 1)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [0, 1])))
        try game.roll(6, 6, 6)
        #expect(game.isOver)
        #expect(GameStatistics.compute(for: game)[1].turns == 1)
    }
}
