import Testing
@testable import ChouetteRules

private func rules(_ configure: (inout RuleSet) -> Void) -> RuleSet {
    var rules = RuleSet()
    configure(&rules)
    return rules
}

@Suite("Règles avancées : sirotage")
struct SirotageTests {

    let sirotage = rules { $0.sirotage.isEnabled = true }

    @Test("Une chouette propose le sirotage ; refuser encaisse la chouette")
    func decline() throws {
        var game = try makeGame(rules: sirotage)
        let events = try game.roll(4, 1, 4)
        #expect(events.contains(.sirotageOffered(0, pairValue: 4)))
        #expect(game.phase == .awaitingSirotageDecision(pairValue: 4))
        #expect(game.scores == [0, 0, 0])
        try game.apply(.decideSirotage(false))
        #expect(game.scores == [16, 0, 0])
        #expect(game.currentPlayer == 1)
    }

    @Test("Sirotage réussi : cul de chouette, et les bons parieurs gagnent")
    func success() throws {
        var game = try makeGame(rules: sirotage)
        try game.roll(4, 1, 4)
        try game.apply(.decideSirotage(true))
        #expect(game.phase == .awaitingSirotageBets(pairValue: 4))
        try game.apply(.placeSirotageBets([1: 4, 2: 3]))
        try game.apply(.sirotageRoll(DieFace(4)!))
        #expect(game.scores == [80, 25, 0])
        #expect(game.history[0].sirotageFace == DieFace(4))
    }

    @Test("Sirotage raté : le lanceur perd la valeur de sa chouette")
    func failure() throws {
        var game = try makeGame(rules: sirotage)
        try game.roll(4, 1, 4)
        try game.apply(.decideSirotage(true))
        try game.apply(.placeSirotageBets([1: 4, 2: 3]))
        let events = try game.apply(.sirotageRoll(DieFace(3)!))
        #expect(events.contains(.sirotageResolved(face: DieFace(3)!, success: false)))
        #expect(game.scores == [-16, 0, 25])
    }

    @Test("Sans paris, on passe directement à la relance")
    func noBets() throws {
        var game = try makeGame(rules: rules {
            $0.sirotage.isEnabled = true
            $0.sirotage.betsEnabled = false
        })
        try game.roll(2, 2, 6)
        try game.apply(.decideSirotage(true))
        #expect(game.phase == .awaitingSirotageRoll(pairValue: 2, bets: [:]))
    }

    @Test("Paris invalides", arguments: [[0: 3], [1: 0], [1: 7], [9: 2]])
    func invalidBets(bets: [PlayerID: Int]) throws {
        var game = try makeGame(rules: sirotage)
        try game.roll(5, 5, 2)
        try game.apply(.decideSirotage(true))
        #expect(throws: GameError.invalidBet) { try game.apply(.placeSirotageBets(bets)) }
    }

    @Test("Pas de sirotage sur une chouette-velute ni un cul de chouette")
    func onlyPlainChouette() throws {
        var game = try makeGame(rules: sirotage)
        try game.roll(2, 2, 4)
        #expect(game.reflex != nil)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [])))
        try game.roll(3, 3, 3)
        #expect(game.phase == .awaitingRoll)
        #expect(game.scores == [0, 70, 0])
    }
}

@Suite("Règles avancées : bévue")
struct BevueTests {

    @Test("Un faux départ coûte des points si la bévue est activée")
    func falseStartPenalized() throws {
        var game = try makeGame(rules: rules { $0.bevue.isEnabled = true })
        try game.roll(2, 2, 4)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [0], falseStarts: [1, 2])))
        #expect(game.scores == [32, -10, -10])
    }

    @Test("Faux départ ignoré si la bévue est désactivée")
    func falseStartIgnored() throws {
        var game = try makeGame()
        try game.roll(2, 2, 4)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [0], falseStarts: [1])))
        #expect(game.scores == [32, 0, 0])
    }
}

@Suite("Règles avancées : civet")
struct CivetTests {

    let civet = rules { $0.civet.isEnabled = true }

    @Test("Civet gagné : mise + points de la figure")
    func won() throws {
        var game = try makeGame(rules: civet)
        #expect(game.canDeclareCivet)
        try game.apply(.declareCivet(figure: .chouette, stake: 50))
        #expect(!game.canDeclareCivet, "Un seul civet par tour")
        try game.roll(3, 3, 1)
        #expect(game.scores == [59, 0, 0])
        #expect(game.players[0].civetsLeft == 0)
    }

    @Test("Civet perdu : la mise est retirée")
    func lost() throws {
        var game = try makeGame(rules: civet)
        try game.apply(.declareCivet(figure: .culDeChouette, stake: 102))
        try game.roll(3, 3, 1)
        #expect(game.scores == [9 - 102, 0, 0])
    }

    @Test("Mise hors limites", arguments: [0, -5, 103])
    func invalidStake(stake: Int) throws {
        var game = try makeGame(rules: civet)
        #expect(throws: GameError.invalidStake) { try game.apply(.declareCivet(figure: .velute, stake: stake)) }
        #expect(game.players[0].civetsLeft == 1)
    }

    @Test("Un civet par partie et par joueur")
    func onePerGame() throws {
        var game = try makeGame(players: 2, rules: civet)
        try game.apply(.declareCivet(figure: .neant, stake: 10))
        try game.roll(1, 3, 6)
        #expect(game.scores == [10, 0])
        try game.roll(1, 3, 6)
        #expect(game.currentPlayer == 0)
        #expect(throws: GameError.civetUnavailable) { try game.apply(.declareCivet(figure: .neant, stake: 10)) }
    }

    @Test("La suite d'un 1-2-3 compte pour un civet sur la suite")
    func civetOnSuite() throws {
        var game = try makeGame(rules: civet)
        try game.apply(.declareCivet(figure: .suite, stake: 20))
        try game.roll(1, 2, 3)
        #expect(game.scores == [38, 0, 0])
    }
}

@Suite("Règles avancées : grelottine")
struct GrelottineTests {

    let grelottine = rules { $0.grelottine.isEnabled = true }

    @Test("Un néant donne une grelottine (une seule à la fois)")
    func granted() throws {
        var game = try makeGame(players: 2, rules: grelottine)
        let first = try game.roll(1, 3, 6)
        #expect(first.contains(.grelottineGranted(0)))
        try game.roll(1, 3, 6)
        let second = try game.roll(1, 3, 6)
        #expect(!second.contains(.grelottineGranted(0)))
        #expect(game.players[0].hasGrelottine)
    }

    /// J0 : grelottine et 36 pts ; J1 : 25 pts. C'est au tour de J0.
    private func setUp() throws -> GameEngine {
        var game = try makeGame(players: 2, rules: grelottine)
        try game.roll(1, 3, 6)   // J0 néant → grelottine
        try game.roll(5, 5, 1)   // J1 +25
        try game.roll(6, 6, 2)   // J0 +36
        try game.roll(1, 1, 5)   // J1 +1 → 26
        return game
    }

    @Test("Défi réussi par la cible : elle prend la mise au lanceur du défi")
    func targetSucceeds() throws {
        var game = try setUp()
        #expect(game.canLaunchGrelottine)
        #expect(game.grelottineTargets == [1])
        #expect(game.grelottineMaxStake(against: 1) == 26)
        try game.apply(.launchGrelottine(target: 1, figure: .chouette, stake: 20))
        #expect(!game.players[0].hasGrelottine)
        let events = try game.apply(.grelottineRoll(Roll(2, 5, 2)))
        #expect(events.contains { if case .grelottineResolved(_, _, true) = $0 { true } else { false } })
        #expect(game.scores == [16, 46])
        #expect(game.phase == .awaitingRoll)
        #expect(game.currentPlayer == 0, "Le défieur joue ensuite son tour normal")
        try game.roll(1, 3, 6)
        #expect(game.history.last?.grelottineRolls == [Roll(2, 5, 2)])
    }

    @Test("Défi raté par la cible : le défieur prend la mise")
    func targetFails() throws {
        var game = try setUp()
        try game.apply(.launchGrelottine(target: 1, figure: .culDeChouette, stake: 26))
        try game.apply(.grelottineRoll(Roll(2, 5, 2)))
        #expect(game.scores == [62, 0])
    }

    @Test("Défis invalides")
    func invalid() throws {
        var game = try setUp()
        #expect(throws: GameError.invalidTarget) {
            try game.apply(.launchGrelottine(target: 0, figure: .chouette, stake: 5))
        }
        #expect(throws: GameError.invalidStake) {
            try game.apply(.launchGrelottine(target: 1, figure: .chouette, stake: 27))
        }
        #expect(game.players[0].hasGrelottine)
    }

    @Test("Impossible de défier un joueur à 0 point")
    func noTargetWithoutPoints() throws {
        var game = try makeGame(players: 2, rules: grelottine)
        try game.roll(1, 3, 6)
        try game.roll(1, 3, 6)
        #expect(!game.canLaunchGrelottine)
    }

    @Test("Une grelottine peut terminer la partie")
    func grelottineVictory() throws {
        var game = try GameEngine(playerNames: ["a", "b"], rules: rules {
            $0.grelottine.isEnabled = true
            $0.targetScore = 60
        })
        try game.roll(1, 3, 6)
        try game.roll(5, 5, 1)   // J1 25
        try game.roll(6, 6, 2)   // J0 36
        try game.roll(1, 1, 5)   // J1 26
        try game.apply(.launchGrelottine(target: 1, figure: .culDeChouette, stake: 26))
        try game.apply(.grelottineRoll(Roll(1, 2, 4)))
        #expect(game.winner == 0)
        #expect(game.history.last?.grelottineRolls.count == 1)
    }
}

@Suite("Parties aléatoires complètes")
struct SimulationTests {

    /// Joue une partie entière avec des décisions aléatoires et vérifie les invariants.
    @Test("Invariants sur 200 parties", arguments: [RuleSet.standard, RuleSet.allAdvanced])
    func randomGames(rules: RuleSet) throws {
        for seed in UInt64(0)..<200 {
            var rng = SeededGenerator(seed: seed)
            let count = Int.random(in: 2...8, using: &rng)
            var game = try makeGame(players: count, rules: rules)
            var steps = 0

            while !game.isOver {
                steps += 1
                try #require(steps < 20_000, "La partie \(seed) ne se termine pas")
                try game.apply(randomAction(for: game, using: &rng))
            }

            // Le score de chacun est la somme de ses variations dans l'historique.
            for player in game.players {
                let total = game.history.flatMap(\.changes).filter { $0.player == player.id }.map(\.delta).reduce(0, +)
                #expect(total == player.score, "Partie \(seed), joueur \(player.id)")
            }
            let winner = try #require(game.winner)
            #expect(game.players[winner].score >= rules.targetScore)
            #expect(game.players.allSatisfy { $0.score <= game.players[winner].score })
        }
    }

    private func randomAction(for game: GameEngine, using rng: inout SeededGenerator) -> GameAction {
        let others = game.players.map(\.id).filter { $0 != game.currentPlayer }
        switch game.phase {
        case .awaitingRoll:
            if game.canLaunchGrelottine, Int.random(in: 0..<3, using: &rng) == 0,
               let target = game.grelottineTargets.randomElement(using: &rng) {
                return .launchGrelottine(target: target, figure: FigureKind.allCases.randomElement(using: &rng)!,
                                         stake: Int.random(in: 1...game.grelottineMaxStake(against: target), using: &rng))
            }
            if game.canDeclareCivet, Int.random(in: 0..<5, using: &rng) == 0 {
                return .declareCivet(figure: FigureKind.allCases.randomElement(using: &rng)!,
                                     stake: Int.random(in: 1...game.rules.civet.maxStake, using: &rng))
            }
            return .roll(Roll.random(using: &rng))
        case .awaitingGrelottineRoll:
            return .grelottineRoll(Roll.random(using: &rng))
        case .awaitingSirotageDecision:
            return .decideSirotage(Bool.random(using: &rng))
        case .awaitingSirotageBets:
            let bets = Dictionary(uniqueKeysWithValues: others.filter { _ in Bool.random(using: &rng) }
                .map { ($0, Int.random(in: 1...6, using: &rng)) })
            return .placeSirotageBets(bets)
        case .awaitingSirotageRoll:
            return .sirotageRoll(DieFace.random(using: &rng))
        case .awaitingReflex(let challenge):
            let taps = challenge.participants.shuffled(using: &rng).filter { _ in Int.random(in: 0..<4, using: &rng) > 0 }
            let falseStarts = Set(challenge.participants.filter { _ in Int.random(in: 0..<10, using: &rng) == 0 })
            return .resolveReflex(ReflexOutcome(tapOrder: taps, falseStarts: falseStarts))
        case .gameOver:
            preconditionFailure("Partie déjà terminée")
        }
    }
}
