// GameViewModel.swift
// Fait le lien entre le moteur de règles, l'affichage et la sauvegarde.
// Le moteur décide de tout ; ce modèle ne gère que les dés affichés, l'annulation,
// les messages de résultat, les retours haptiques et l'enregistrement.

import Foundation
import Observation
import SwiftData
import SwiftUI
import ChouetteRules

@Observable
final class GameViewModel {

    /// Ce que l'on est en train de lancer.
    enum RollPurpose: Hashable, Identifiable {
        case main
        case grelottine
        case sirotage
        var id: Self { self }
        var diceCount: Int { self == .sirotage ? 1 : 3 }
    }

    /// Fenêtres modales de la partie.
    enum Sheet: Hashable, Identifiable {
        case civet
        case grelottine
        case sirotageBets
        case manualEntry(RollPurpose)
        case scoreboard
        case rules
        var id: Self { self }
    }

    /// Une ligne du résumé du dernier lancer.
    struct FeedLine: Identifiable, Hashable {
        let id = UUID()
        let text: String
        var delta: Int?
    }

    // MARK: État

    private(set) var engine: GameEngine
    let avatars: [Avatar]
    let mode: GameMode
    let savedGame: SavedGame

    /// Dés affichés (valeurs 1…6, `nil` tant que rien n'a été lancé).
    private(set) var diceFaces: [Int?] = [nil, nil, nil]
    /// Indices des dés en train de rouler.
    private(set) var rollingDice: Set<Int> = []
    /// Indice du dé relancé pendant un sirotage, mis en valeur.
    private(set) var highlightedDie: Int?
    /// Résumé des derniers événements (lancer, points, paris…).
    private(set) var feed: [FeedLine] = []
    private var feedTurn = 0

    var activeSheet: Sheet?
    var errorMessage: String?

    // MARK: Partie guidée

    /// Explications en direct. Modifiable en cours de partie.
    var isGuided: Bool {
        didSet {
            savedGame.isGuided = isGuided
            if !isGuided {
                coachTip = nil
                reflexBriefed = true
            }
            persist()
        }
    }
    /// Explication du dernier événement marquant (partie guidée uniquement).
    private(set) var coachTip: CoachTip?
    /// En partie guidée, le mini-jeu ne démarre qu'après lecture de ses consignes.
    private(set) var reflexBriefed = true

    /// Incrémenté à chaque retour haptique ; la vue observe ce compteur.
    private(set) var feedbackTick = 0
    private(set) var feedbackKind = SensoryFeedback.impact

    private var undoStack: [GameEngine] = []
    private let context: ModelContext
    private var rng = SystemRandomNumberGenerator()

    init(savedGame: SavedGame, context: ModelContext) throws {
        self.savedGame = savedGame
        self.context = context
        engine = try savedGame.decodeEngine()
        avatars = savedGame.avatars
        mode = savedGame.mode
        isGuided = savedGame.isGuided   // pas de didSet dans l'initialiseur
        feedTurn = engine.currentTurn.number
        restoreDisplayedDice()
        if isGuided {
            reflexBriefed = pendingReflex == nil
            if engine.history.isEmpty && engine.currentTurn.roll == nil {
                coachTip = Coach.welcome(rules: engine.rules, firstPlayer: currentPlayer.name)
            } else if let roll = engine.currentTurn.roll {
                // Reprise en plein tour : on réexplique le lancer en cours.
                coachTip = Coach.tip(for: RollAnalyzer.analyze(roll, rules: engine.rules), player: currentPlayer.name,
                                     rules: engine.rules, grantedGrelottine: false)
            }
        }
    }

    // MARK: Accès pratiques

    var players: [PlayerState] { engine.players }
    var rules: RuleSet { engine.rules }
    var currentPlayer: PlayerState { engine.players[engine.currentPlayer] }
    func avatar(of player: PlayerID) -> Avatar { avatars.indices.contains(player) ? avatars[player] : .owl }
    func name(of player: PlayerID) -> String { engine.players[player].name }

    var isRolling: Bool { !rollingDice.isEmpty }
    var canUndo: Bool { !undoStack.isEmpty && !engine.isOver && !isRolling }

    var pendingReflex: ReflexChallenge? {
        if case .awaitingReflex(let challenge) = engine.phase { challenge } else { nil }
    }

    /// Le mini-jeu en plein écran est affiché (consignes lues en partie guidée).
    var isReflexPresented: Bool { pendingReflex != nil && reflexBriefed }

    /// Consignes à lire avant le mini-jeu, en partie guidée.
    var reflexBriefing: CoachTip? {
        guard let pendingReflex, !reflexBriefed else { return nil }
        return Coach.reflexBriefing(pendingReflex)
    }

    func startBriefedReflex() { reflexBriefed = true }

    func dismissCoachTip() { coachTip = nil }

    /// Le lancer attendu dans la phase actuelle, s'il y en a un.
    var expectedRoll: RollPurpose? {
        switch engine.phase {
        case .awaitingRoll: .main
        case .awaitingGrelottineRoll: .grelottine
        case .awaitingSirotageRoll: .sirotage
        default: nil
        }
    }

    // MARK: Lancers

    /// Lance les dés pour la phase en cours : animation en mode virtuel,
    /// saisie manuelle en mode « mes propres dés ».
    func roll(reduceMotion: Bool) async {
        guard let purpose = expectedRoll, !isRolling else { return }
        switch mode {
        case .manual:
            activeSheet = .manualEntry(purpose)
        case .simple:
            let faces = (0..<purpose.diceCount).map { _ in DieFace.random(using: &rng) }
            await animateAndSubmit(faces, purpose: purpose, reduceMotion: reduceMotion)
        }
    }

    /// Valeurs saisies à la main.
    func submitManual(_ faces: [DieFace], purpose: RollPurpose) {
        activeSheet = nil
        guard faces.count == purpose.diceCount else { return }
        show(faces, purpose: purpose)
        submit(faces, purpose: purpose)
    }

    private func animateAndSubmit(_ faces: [DieFace], purpose: RollPurpose, reduceMotion: Bool) async {
        let indices = targetIndices(for: purpose)
        rollingDice = Set(indices)
        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(250))
        } else {
            // Les faces défilent de plus en plus lentement, comme un dé qui ralentit.
            var delay = 45
            while delay < 160 {
                for i in indices { diceFaces[i] = Int.random(in: 1...6, using: &rng) }
                feedback(.impact(weight: .light, intensity: 0.4))
                try? await Task.sleep(for: .milliseconds(delay))
                delay = Int(Double(delay) * 1.18) + 4
            }
        }
        rollingDice = []
        show(faces, purpose: purpose)
        feedback(.impact(weight: .heavy))
        submit(faces, purpose: purpose)
    }

    /// Dés de l'affichage concernés par un lancer.
    private func targetIndices(for purpose: RollPurpose) -> [Int] {
        guard purpose == .sirotage else { return [0, 1, 2] }
        return [oddDieIndex() ?? 2]
    }

    /// Indice du dé qui ne fait pas partie de la chouette (pour le sirotage).
    private func oddDieIndex() -> Int? {
        let values = diceFaces.compactMap { $0 }
        guard values.count == 3 else { return nil }
        for i in 0..<3 where values.filter({ $0 == values[i] }).count == 1 { return i }
        return nil
    }

    private func show(_ faces: [DieFace], purpose: RollPurpose) {
        if purpose == .sirotage {
            let index = oddDieIndex() ?? 2
            diceFaces[index] = faces[0].value
            highlightedDie = index
        } else {
            diceFaces = faces.map(\.value)
            highlightedDie = nil
        }
    }

    private func submit(_ faces: [DieFace], purpose: RollPurpose) {
        switch purpose {
        case .main: apply(.roll(Roll(faces[0], faces[1], faces[2])))
        case .grelottine: apply(.grelottineRoll(Roll(faces[0], faces[1], faces[2])))
        case .sirotage: apply(.sirotageRoll(faces[0]))
        }
    }

    // MARK: Autres actions

    func decideSirotage(_ accept: Bool) {
        apply(.decideSirotage(accept))
        if accept, case .awaitingSirotageBets = engine.phase { activeSheet = .sirotageBets }
    }

    func placeBets(_ bets: [PlayerID: Int]) {
        activeSheet = nil
        apply(.placeSirotageBets(bets))
    }

    func declareCivet(_ figure: FigureKind, stake: Int) {
        activeSheet = nil
        apply(.declareCivet(figure: figure, stake: stake))
    }

    func launchGrelottine(target: PlayerID, figure: FigureKind, stake: Int) {
        activeSheet = nil
        apply(.launchGrelottine(target: target, figure: figure, stake: stake))
    }

    func resolveReflex(_ outcome: ReflexOutcome) {
        apply(.resolveReflex(outcome))
    }

    func undo() {
        guard canUndo, let previous = undoStack.popLast() else { return }
        engine = previous
        feed = [FeedLine(text: String(localized: "Coup annulé"))]
        feedTurn = engine.currentTurn.number
        coachTip = nil
        reflexBriefed = !isGuided || pendingReflex == nil
        restoreDisplayedDice()
        persist()
    }

    // MARK: Application au moteur

    private func apply(_ action: GameAction) {
        let snapshot = engine
        do {
            let events = try engine.apply(action)
            undoStack.append(snapshot)
            if undoStack.count > 100 { undoStack.removeFirst() }
            record(events, turn: snapshot.currentTurn.number)
            persist()
            if engine.isOver { recordResultInProfiles() }
        } catch {
            errorMessage = String(localized: "Action impossible pour le moment.")
        }
    }

    /// Traduit les événements en lignes de résumé et en retours haptiques.
    private func record(_ events: [GameEvent], turn: Int) {
        if turn != feedTurn {
            feed = []
            feedTurn = turn
        }
        var gained = false, lost = false
        // Ligne du lancer, à compléter avec ses points quand le lancer n'a qu'une figure.
        var rollLine: (index: Int, player: PlayerID, figure: Figure)?
        for event in events {
            switch event {
            case .civetDeclared(let civet):
                feed.append(FeedLine(text: String(localized: "\(name(of: civet.player)) joue un civet de \(civet.stake) sur « \(civet.figure.name) »")))
            case .grelottineLaunched(let c):
                feed.append(FeedLine(text: String(localized: "\(name(of: c.challenger)) défie \(name(of: c.target)) : \(c.figure.name) pour \(c.stake) points")))
            case .grelottineResolved(let c, let analysis, let success):
                feed.append(FeedLine(text: success
                    ? String(localized: "\(name(of: c.target)) réussit : \(analysis.name)")
                    : String(localized: "\(name(of: c.target)) échoue : \(analysis.name)")))
            case .grelottineGranted(let player):
                feed.append(FeedLine(text: String(localized: "\(name(of: player)) gagne une grelottine")))
            case .rolled(let player, let analysis):
                feed.append(FeedLine(text: String(localized: "\(name(of: player)) : \(analysis.name)")))
                if isGuided {
                    coachTip = Coach.tip(for: analysis, player: name(of: player), rules: rules,
                                         grantedGrelottine: events.contains(.grelottineGranted(player)))
                }
                if analysis.figures.count == 1 { rollLine = (feed.count - 1, player, analysis.figures[0]) }
            case .scoreChanged(let change, _):
                if let line = rollLine, change.player == line.player, change.reason == .figure(line.figure) {
                    feed[line.index].delta = change.delta
                } else {
                    feed.append(FeedLine(text: "\(name(of: change.player)) · \(change.reason.label)", delta: change.delta))
                }
                if change.delta > 0 { gained = true } else { lost = true }
            case .sirotageOffered(let player, let pair):
                feed.append(FeedLine(text: String(localized: "\(name(of: player)) peut siroter sa chouette de \(pair)")))
            case .sirotageResolved(let face, let success):
                feed.append(FeedLine(text: success
                    ? String(localized: "Le dé tombe sur \(face.value) : sirotage réussi !")
                    : String(localized: "Le dé tombe sur \(face.value) : raté.")))
            case .reflexResolved(let challenge, let winners, let losers):
                if challenge.kind == .pasMouLeCaillou, winners.isEmpty {
                    feed.append(FeedLine(text: String(localized: "Personne n'a crié à temps.")))
                }
                if isGuided {
                    coachTip = Coach.reflexOutcome(challenge, winners: winners, losers: losers) { self.name(of: $0) }
                }
            case .reflexStarted:
                reflexBriefed = !isGuided
            case .sirotageBetsOpened:
                if isGuided { coachTip = Coach.sirotageBets(rules: rules) }
            case .turnEnded, .turnStarted, .gameOver:
                break
            }
        }
        if engine.isOver {
            feedback(.success)
        } else if gained {
            feedback(.success)
        } else if lost {
            feedback(.warning)
        }
    }

    private func feedback(_ kind: SensoryFeedback) {
        feedbackKind = kind
        feedbackTick &+= 1
    }

    /// Réaffiche les dés du tour courant (ou du précédent) après restauration ou annulation.
    private func restoreDisplayedDice() {
        highlightedDie = nil
        let turn = engine.currentTurn.roll != nil ? engine.currentTurn : engine.history.last
        guard let turn, let roll = turn.grelottineRolls.last ?? turn.roll else {
            diceFaces = [nil, nil, nil]
            return
        }
        diceFaces = roll.dice.map(\.value)
        if let face = turn.sirotageFace, turn.roll == roll, let odd = oddDieIndex() {
            diceFaces[odd] = face.value
            highlightedDie = odd
        }
    }

    private func persist() {
        do {
            try savedGame.store(engine)
            try context.save()
        } catch {
            errorMessage = String(localized: "La partie n'a pas pu être enregistrée.")
        }
    }

    /// Met à jour les profils (parties jouées / gagnées) à la fin de la partie.
    private func recordResultInProfiles() {
        guard let winner = engine.winner,
              let profiles = try? context.fetch(FetchDescriptor<PlayerProfile>()) else { return }
        for player in engine.players {
            guard let profile = profiles.first(where: { $0.name == player.name }) else { continue }
            profile.gamesPlayed += 1
            if player.id == winner { profile.gamesWon += 1 }
            profile.lastPlayed = .now
        }
        try? context.save()
    }

    // MARK: Revanche

    /// Nouvelle partie avec les mêmes joueurs, avatars, mode et règles.
    /// Le perdant (dernier du classement) commence.
    func makeRematch() throws -> SavedGame {
        let last = engine.players.min { $0.score < $1.score }?.id ?? 0
        let newEngine = try GameEngine(playerNames: engine.players.map(\.name), rules: engine.rules, firstPlayer: last)
        let game = try SavedGame(engine: newEngine, avatars: avatars, mode: mode)
        context.insert(game)
        try context.save()
        return game
    }
}
