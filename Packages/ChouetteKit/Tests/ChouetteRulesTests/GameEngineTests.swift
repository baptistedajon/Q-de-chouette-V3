import Foundation
import Testing
@testable import ChouetteRules

// MARK: - Aides

func makeGame(players: Int = 3, rules: RuleSet = .standard) throws -> GameEngine {
    try GameEngine(playerNames: (0..<players).map { "J\($0)" }, rules: rules)
}

extension GameEngine {
    var scores: [Int] { players.map(\.score) }

    /// Lance les dés pour le joueur courant.
    @discardableResult
    mutating func roll(_ a: Int, _ b: Int, _ c: Int) throws -> [GameEvent] {
        try apply(.roll(Roll(a, b, c)))
    }

    var reflex: ReflexChallenge? {
        if case .awaitingReflex(let c) = phase { c } else { nil }
    }
}

// MARK: - Règles de base

@Suite("Partie : règles de base")
struct GameEngineTests {

    @Test("De 2 à 8 joueurs", arguments: [0, 1, 9, 12])
    func invalidPlayerCount(count: Int) {
        #expect(throws: GameError.invalidPlayerCount(count)) {
            try GameEngine(playerNames: Array(repeating: "x", count: count))
        }
    }

    @Test func invalidFirstPlayer() {
        #expect(throws: GameError.invalidFirstPlayer) {
            try GameEngine(playerNames: ["a", "b"], firstPlayer: 2)
        }
    }

    @Test("Une chouette rapporte valeur² au lanceur et passe la main")
    func chouette() throws {
        var game = try makeGame()
        let events = try game.roll(4, 1, 4)
        #expect(game.scores == [16, 0, 0])
        #expect(game.currentPlayer == 1)
        #expect(game.phase == .awaitingRoll)
        #expect(game.history.count == 1)
        #expect(game.history[0].changes == [ScoreChange(player: 0, delta: 16, reason: .figure(.chouette(value: 4)))])
        #expect(events.contains(.turnStarted(1)))
    }

    @Test("Cul de chouette 6-6-6 = 100")
    func culDeChouette() throws {
        var game = try makeGame()
        try game.roll(6, 6, 6)
        #expect(game.scores == [100, 0, 0])
    }

    @Test("Néant : 0 point, pas de grelottine sans la règle avancée")
    func neant() throws {
        var game = try makeGame()
        let events = try game.roll(1, 3, 6)
        #expect(game.scores == [0, 0, 0])
        #expect(!events.contains(.grelottineGranted(0)))
        #expect(game.currentPlayer == 1)
    }

    @Test("Le tour revient au premier joueur après le dernier")
    func turnOrder() throws {
        var game = try GameEngine(playerNames: ["a", "b"], firstPlayer: 1)
        try game.roll(1, 3, 6)
        #expect(game.currentPlayer == 0)
        try game.roll(1, 3, 6)
        #expect(game.currentPlayer == 1)
        #expect(game.history.map(\.number) == [1, 2])
    }

    // MARK: Suite

    @Test("Suite : le dernier à crier perd 10 points")
    func suiteLastLoses() throws {
        var game = try makeGame()
        try game.roll(2, 4, 3)
        let challenge = try #require(game.reflex)
        #expect(challenge.kind == .grelotteCaPicote)
        #expect(challenge.participants == [0, 1, 2])
        #expect(game.currentPlayer == 0, "Le tour ne passe qu'après le mini-jeu")

        let events = try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [2, 0, 1])))
        #expect(game.scores == [0, -10, 0])
        #expect(events.contains(.reflexResolved(challenge, winners: [], losers: [1])))
        #expect(game.currentPlayer == 1)
    }

    @Test("Suite : tous ceux qui n'ont pas crié perdent")
    func suiteSilentPlayersLose() throws {
        var game = try makeGame(players: 4)
        try game.roll(4, 5, 6)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [3])))
        #expect(game.scores == [-10, -10, -10, 0])
    }

    @Test("Suite, variante allégée : seul le plus lent des joueurs ayant tapé perd")
    func suiteLightLastTapperOnly() throws {
        var rules = RuleSet()
        rules.suiteLosers = .lastTapperOnly
        var game = try makeGame(players: 4, rules: rules)
        try game.roll(4, 5, 6)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [3, 1])))
        #expect(game.scores == [0, -10, 0, 0])
        try game.roll(2, 3, 4)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [])))
        #expect(game.scores == [0, -10, 0, 0], "Personne n'a tapé : personne ne perd")
    }

    @Test("Les règles traditionnelles sont les règles par défaut ; le préréglage allégé change les trois choix")
    func lightPreset() {
        let standard = RuleSet.standard
        #expect(standard.sirotage.failure == .loseChouette)
        #expect(standard.suiteLosers == .allLate)
        #expect(!standard.grelottine.stakeLimitedByScores)
        #expect(!standard.usesLightVariants)

        let light = RuleSet.light
        #expect(light.usesLightVariants)
        #expect(light.sirotage.failure == .scoreNothing)
        #expect(light.suiteLosers == .lastTapperOnly)
        #expect(light.grelottine.stakeLimitedByScores)
        // Seuls ces trois choix diffèrent.
        var reverted = light
        reverted.sirotage.failure = .loseChouette
        reverted.suiteLosers = .allLate
        reverted.grelottine.stakeLimitedByScores = false
        #expect(reverted == standard)
    }

    @Test("1-2-3 : velute pour le lanceur, puis suite (réglage par défaut)")
    func oneTwoThreeBoth() throws {
        var game = try makeGame()
        try game.roll(1, 2, 3)
        #expect(game.scores == [18, 0, 0])
        #expect(game.reflex?.kind == .grelotteCaPicote)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [1, 2, 0])))
        #expect(game.scores == [8, 0, 0])
    }

    @Test("1-2-3 : variantes velute seule / suite seule")
    func oneTwoThreeVariants() throws {
        var rules = RuleSet()
        rules.oneTwoThree = .veluteOnly
        var game = try makeGame(rules: rules)
        try game.roll(3, 2, 1)
        #expect(game.scores == [18, 0, 0])
        #expect(game.phase == .awaitingRoll)

        rules.oneTwoThree = .suiteOnly
        game = try makeGame(rules: rules)
        try game.roll(3, 2, 1)
        #expect(game.scores == [0, 0, 0])
        #expect(game.reflex?.kind == .grelotteCaPicote)
    }

    // MARK: Chouette-velute

    @Test("Chouette-velute : le premier à crier gagne la velute, le lanceur rien")
    func chouetteVelute() throws {
        var game = try makeGame()
        try game.roll(2, 4, 2)
        let challenge = try #require(game.reflex)
        #expect(challenge.kind == .pasMouLeCaillou)
        #expect(challenge.points == 32)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [2, 0])))
        #expect(game.scores == [0, 0, 32])
        #expect(game.history[0].changes.last?.reason == .chouetteVeluteWon(veluteValue: 4))
    }

    @Test("Chouette-velute : le lanceur peut gagner son propre réflexe")
    func chouetteVeluteRollerWins() throws {
        var game = try makeGame()
        try game.roll(3, 3, 6)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [0, 1, 2])))
        #expect(game.scores == [72, 0, 0])
    }

    @Test("Chouette-velute : personne ne crie, personne ne marque")
    func chouetteVeluteNobody() throws {
        var game = try makeGame()
        try game.roll(1, 1, 2)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [])))
        #expect(game.scores == [0, 0, 0])
        #expect(game.currentPlayer == 1)
    }

    @Test("Chouette-velute : option « le lanceur garde sa chouette »")
    func chouetteVeluteKeepsChouette() throws {
        var rules = RuleSet()
        rules.chouetteVeluteRollerKeepsChouette = true
        var game = try makeGame(rules: rules)
        try game.roll(2, 2, 4)
        #expect(game.scores == [4, 0, 0])
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [1])))
        #expect(game.scores == [4, 32, 0])
    }

    // MARK: Validation des actions

    @Test("Actions interdites selon la phase")
    func invalidActions() throws {
        var game = try makeGame()
        #expect(throws: GameError.actionNotAllowed) {
            try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [])))
        }
        #expect(throws: GameError.actionNotAllowed) { try game.apply(.decideSirotage(true)) }
        #expect(throws: GameError.actionNotAllowed) { try game.apply(.sirotageRoll(DieFace(1)!)) }
        #expect(throws: GameError.actionNotAllowed) { try game.apply(.grelottineRoll(Roll(1, 1, 1))) }
        #expect(throws: GameError.civetUnavailable) { try game.apply(.declareCivet(figure: .chouette, stake: 10)) }
        #expect(throws: GameError.grelottineUnavailable) {
            try game.apply(.launchGrelottine(target: 1, figure: .chouette, stake: 1))
        }

        try game.roll(2, 3, 4)
        #expect(throws: GameError.actionNotAllowed) { try game.roll(1, 1, 1) }
    }

    @Test("Résultat de réflexe invalide : l'état ne change pas")
    func invalidReflexOutcome() throws {
        var game = try makeGame()
        try game.roll(2, 3, 4)
        let before = game
        #expect(throws: GameError.invalidReflexOutcome) {
            try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [0, 0])))
        }
        #expect(throws: GameError.invalidReflexOutcome) {
            try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [5])))
        }
        #expect(throws: GameError.invalidReflexOutcome) {
            try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [], falseStarts: [7])))
        }
        #expect(game == before)
    }

    // MARK: Victoire

    @Test("Victoire en atteignant ou dépassant la cible")
    func victoryReach() throws {
        var rules = RuleSet()
        rules.targetScore = 30
        var game = try makeGame(rules: rules)
        try game.roll(5, 5, 1)             // 25
        try game.roll(1, 3, 6)
        try game.roll(1, 3, 6)
        let events = try game.roll(2, 2, 1) // 29
        #expect(!game.isOver)
        #expect(events.contains(.turnStarted(1)))
        try game.roll(1, 3, 6)
        try game.roll(1, 3, 6)
        let final = try game.roll(1, 1, 5)  // 30
        #expect(final.contains(.gameOver(winner: 0)))
        #expect(game.winner == 0)
        #expect(game.history.count == 7)
        #expect(throws: GameError.actionNotAllowed) { try game.roll(1, 1, 1) }
    }

    @Test("Victoire d'un autre joueur grâce au réflexe")
    func victoryThroughReflex() throws {
        var rules = RuleSet()
        rules.targetScore = 50
        var game = try makeGame(rules: rules)
        try game.roll(3, 6, 3)
        try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [2])))
        #expect(game.winner == 2)
    }

    @Test("Mode exact : l'excédent est retranché")
    func exactVictory() throws {
        var rules = RuleSet()
        rules.victoryMode = .exact
        rules.targetScore = 110
        var game = try makeGame(players: 2, rules: rules)
        try game.roll(6, 6, 6)            // 100
        try game.roll(1, 3, 6)
        try game.roll(4, 4, 1)            // 116 → 104
        #expect(game.scores == [104, 0])
        #expect(game.history[2].changes.last?.delta == 4)
        #expect(!game.isOver)
        try game.roll(1, 3, 6)
        try game.roll(1, 2, 2)            // 108
        try game.roll(1, 3, 6)
        try game.roll(1, 1, 3)            // 109
        try game.roll(1, 3, 6)
        try game.roll(1, 1, 3)            // 110
        #expect(game.winner == 0)
    }

    @Test("Scores négatifs interdits : plancher à 0, sans événement")
    func noNegativeScores() throws {
        var rules = RuleSet()
        rules.allowNegativeScores = false
        var game = try makeGame(players: 2, rules: rules)
        try game.roll(3, 4, 5)
        let events = try game.apply(.resolveReflex(ReflexOutcome(tapOrder: [0])))
        #expect(game.scores == [0, 0])
        #expect(!events.contains { if case .scoreChanged = $0 { true } else { false } })
    }

    @Test("Les règles sont sérialisables avec la partie")
    func codable() throws {
        var game = try makeGame(rules: .allAdvanced)
        try game.roll(2, 3, 4)
        let data = try JSONEncoder().encode(game)
        let decoded = try JSONDecoder().decode(GameEngine.self, from: data)
        #expect(decoded == game)
    }
}
