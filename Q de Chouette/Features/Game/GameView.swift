// GameView.swift
// Écran de jeu : scores, dés, résumé du dernier lancer et actions de la phase en cours.

import SwiftUI
import SwiftData
import ChouetteRules

/// Charge la partie enregistrée puis affiche `GameView`.
struct GameScreen: View {
    let gameID: PersistentIdentifier
    @Environment(\.modelContext) private var context
    @State private var model: GameViewModel?
    @State private var failed = false

    var body: some View {
        Group {
            if let model {
                GameView(model: model)
            } else if failed {
                ContentUnavailableView("Partie illisible", systemImage: "exclamationmark.triangle",
                                       description: Text("Cette partie enregistrée n'a pas pu être ouverte."))
            } else {
                ProgressView()
            }
        }
        .themedBackground()
        .task {
            guard model == nil else { return }
            guard let savedGame = context.model(for: gameID) as? SavedGame,
                  let loaded = try? GameViewModel(savedGame: savedGame, context: context) else {
                failed = true
                return
            }
            model = loaded
        }
    }
}

struct GameView: View {
    @Bindable var model: GameViewModel
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var victoryDismissed = false

    var body: some View {
        VStack(spacing: 0) {
            ScoreStrip(model: model)
            Divider().overlay(Theme.wood.opacity(0.4))
            ScrollView {
                VStack(spacing: 22) {
                    TurnHeader(model: model)
                    DiceTray(model: model, dieSize: sizeClass == .regular ? 110 : 86)
                    if let tip = model.coachTip {
                        CoachCard(tip: tip, onDismiss: { model.dismissCoachTip() })
                            .transition(.opacity)
                    }
                    if let briefing = model.reflexBriefing {
                        CoachCard(tip: briefing)
                            .transition(.opacity)
                    }
                    if !model.feed.isEmpty {
                        ResultFeed(lines: model.feed)
                            .transition(.opacity)
                    }
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.feed)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.coachTip)
            }
            ActionPanel(model: model)
        }
        .navigationTitle(Text("Tour \(model.engine.currentTurn.number)"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    model.undo()
                } label: {
                    Label("Annuler le dernier coup", systemImage: "arrow.uturn.backward")
                }
                .disabled(!model.canUndo)

                Button {
                    model.activeSheet = .scoreboard
                } label: {
                    Label("Tableau des scores", systemImage: "list.number")
                }

                Menu {
                    Toggle(isOn: $model.isGuided) {
                        Label("Partie guidée", systemImage: "graduationcap")
                    }
                    Button {
                        model.activeSheet = .rules
                    } label: {
                        Label("Règles du jeu", systemImage: "book.closed")
                    }
                } label: {
                    Label("Aide", systemImage: "questionmark.circle")
                }
            }
        }
        .themedBackground()
        .sheet(item: $model.activeSheet) { sheet in
            sheetContent(sheet)
                .themedBackground()
        }
        .fullScreenCover(isPresented: Binding(get: { model.isReflexPresented }, set: { _ in })) {
            if let challenge = model.pendingReflex {
                ReflexView(challenge: challenge, players: model.players, avatars: model.avatars, rules: model.rules) {
                    model.resolveReflex($0)
                }
                .id(challenge)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { model.engine.isOver && !victoryDismissed },
                                              set: { if !$0 { victoryDismissed = true } })) {
            VictoryView(model: model,
                        onRematch: { rematch() },
                        onNewGame: { victoryDismissed = true; router.popToRoot(); router.push(.setup(guided: false)) },
                        onHome: { victoryDismissed = true; router.popToRoot() },
                        onClose: { victoryDismissed = true })
        }
        .sensoryFeedback(trigger: model.feedbackTick) { _, _ in
            settings.hapticsEnabled ? model.feedbackKind : nil
        }
        .alert("Oups", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: GameViewModel.Sheet) -> some View {
        switch sheet {
        case .civet:
            CivetSheet(model: model)
        case .grelottine:
            GrelottineSheet(model: model)
        case .sirotageBets:
            SirotageBetsSheet(model: model)
        case .manualEntry(let purpose):
            ManualDiceEntry(count: purpose.diceCount, title: manualTitle(purpose)) { faces in
                model.submitManual(faces, purpose: purpose)
            }
        case .scoreboard:
            ScoreboardView(engine: model.engine, avatars: model.avatars)
        case .rules:
            NavigationStack {
                RulesView(rules: model.rules)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fermer") { model.activeSheet = nil }
                        }
                    }
            }
        }
    }

    private func manualTitle(_ purpose: GameViewModel.RollPurpose) -> String {
        switch purpose {
        case .main: String(localized: "Valeurs des trois dés")
        case .grelottine: String(localized: "Dés du joueur défié")
        case .sirotage: String(localized: "Valeur du dé relancé")
        }
    }

    private func rematch() {
        do {
            let game = try model.makeRematch()
            victoryDismissed = true
            router.startGame(game)
        } catch {
            model.errorMessage = String(localized: "Impossible de lancer la revanche.")
        }
    }
}

// MARK: - Bandeau des scores

struct ScoreStrip: View {
    let model: GameViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.players) { player in
                        chip(player)
                            .id(player.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .onChange(of: model.engine.currentPlayer, initial: true) { _, current in
                withAnimation { proxy.scrollTo(current, anchor: .center) }
            }
        }
        .background(Theme.surface)
    }

    private func chip(_ player: PlayerState) -> some View {
        let isCurrent = player.id == model.engine.currentPlayer
        return HStack(spacing: 8) {
            AvatarView(avatar: model.avatar(of: player.id), size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(player.name)
                    .font(.subheadline.weight(isCurrent ? .bold : .regular))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(player.score)")
                        .font(.headline.monospacedDigit())
                        .contentTransition(.numericText(value: Double(player.score)))
                    if player.hasGrelottine {
                        Image(systemName: "bell.fill").font(.caption2).foregroundStyle(Theme.gold)
                    }
                    if model.rules.civet.isEnabled && player.civetsLeft > 0 {
                        Image(systemName: "hare.fill").font(.caption2).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isCurrent ? Theme.gold.opacity(0.22) : Theme.background, in: Capsule())
        .overlay(Capsule().strokeBorder(isCurrent ? Theme.gold : .clear, lineWidth: 2))
        .animation(.default, value: player.score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chipLabel(player, isCurrent: isCurrent))
    }

    private func chipLabel(_ player: PlayerState, isCurrent: Bool) -> Text {
        var text = Text("\(player.name), \(player.score) points")
        if isCurrent { text = text + Text(verbatim: ", ") + Text("à son tour") }
        if player.hasGrelottine { text = text + Text(verbatim: ", ") + Text("a une grelottine") }
        return text
    }
}

// MARK: - En-tête du tour

struct TurnHeader: View {
    let model: GameViewModel

    var body: some View {
        let player = model.currentPlayer
        VStack(spacing: 8) {
            AvatarView(avatar: model.avatar(of: player.id), size: 56)
            Text("Au tour de \(player.name)")
                .font(Theme.heading(.title2))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(prompt)
                .font(.body)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            if let civet = model.engine.pendingCivet {
                Label {
                    Text("Civet : \(civet.stake) points sur « \(civet.figure.name) »")
                } icon: {
                    Image(systemName: "hare.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.gold)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var prompt: String {
        let engine = model.engine
        switch engine.phase {
        case .awaitingRoll:
            return model.mode == .manual
                ? String(localized: "Lancez vos trois dés puis saisissez les valeurs.")
                : String(localized: "Lancez les trois dés.")
        case .awaitingGrelottineRoll(let c):
            return String(localized: "\(model.name(of: c.target)) relève le défi de \(model.name(of: c.challenger)) : il lui faut « \(c.figure.name) ».")
        case .awaitingSirotageDecision(let pair):
            return String(localized: "Chouette de \(pair) ! Siroter pour tenter le cul de chouette ?")
        case .awaitingSirotageBets:
            return String(localized: "Les autres joueurs peuvent parier sur le dé.")
        case .awaitingSirotageRoll(let pair, _):
            return String(localized: "« \(DieFace(pair)?.birdName ?? "") ! » Relancez le dernier dé.")
        case .awaitingReflex(let challenge):
            return challenge.kind.phrase
        case .gameOver(let winner):
            return String(localized: "Victoire de \(model.name(of: winner)) !")
        }
    }
}

// MARK: - Dés

struct DiceTray: View {
    let model: GameViewModel
    var dieSize: CGFloat = 86
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: dieSize * 0.25) {
            ForEach(0..<3, id: \.self) { index in
                let rolling = model.rollingDice.contains(index)
                DieView(value: model.diceFaces[index], size: dieSize,
                        isHighlighted: model.highlightedDie == index)
                    .rotationEffect(.degrees(rolling && !reduceMotion ? Double(model.diceFaces[index] ?? 1) * 47 : 0))
                    .offset(y: rolling && !reduceMotion ? -dieSize * 0.12 : 0)
                    .animation(reduceMotion ? nil : .spring(duration: 0.18), value: model.diceFaces[index])
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color(light: 0x2F5B3A, dark: 0x1E3B26), Color(light: 0x23472D, dark: 0x142A1B)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.wood, lineWidth: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        let values = model.diceFaces.compactMap { $0 }
        if model.isRolling { return Text("Les dés roulent") }
        if values.count < 3 { return Text("Dés pas encore lancés") }
        return Text("Dés : \(values.map(String.init).joined(separator: ", "))")
    }
}

// MARK: - Résumé

struct ResultFeed: View {
    let lines: [GameViewModel.FeedLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines) { line in
                HStack(alignment: .firstTextBaseline) {
                    Text(line.text)
                        .font(line == lines.first ? .headline : .body)
                    Spacer(minLength: 8)
                    if let delta = line.delta {
                        Text(delta.signedPoints)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(delta >= 0 ? Theme.positive : Theme.negative)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .parchmentCard()
    }
}

// MARK: - Actions

struct ActionPanel: View {
    let model: GameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            content
        }
        .padding()
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .disabled(model.isRolling)
    }

    @ViewBuilder
    private var content: some View {
        let engine = model.engine
        switch engine.phase {
        case .awaitingRoll:
            rollButton(title: model.mode == .manual ? String(localized: "Saisir mes dés") : String(localized: "Lancer les dés"))
            if engine.canDeclareCivet || engine.canLaunchGrelottine {
                HStack(spacing: 10) {
                    if engine.canDeclareCivet {
                        Button { model.activeSheet = .civet } label: {
                            Label("Civet", systemImage: "hare.fill")
                        }
                        .buttonStyle(.secondary)
                    }
                    if engine.canLaunchGrelottine {
                        Button { model.activeSheet = .grelottine } label: {
                            Label("Grelottine", systemImage: "bell.fill")
                        }
                        .buttonStyle(.secondary)
                    }
                }
            }
        case .awaitingGrelottineRoll(let c):
            rollButton(title: String(localized: "Lancer pour \(model.name(of: c.target))"))
        case .awaitingSirotageDecision(let pair):
            Button { model.decideSirotage(true) } label: {
                Label("Siroter !", systemImage: "wineglass")
            }
            .buttonStyle(.primary)
            Button { model.decideSirotage(false) } label: {
                Text("Garder la chouette (\(RollAnalyzer.chouettePoints(pair, rules: model.rules)) points)")
            }
            .buttonStyle(.secondary)
        case .awaitingSirotageBets:
            Button { model.activeSheet = .sirotageBets } label: {
                Label("Prendre les paris", systemImage: "list.bullet.clipboard")
            }
            .buttonStyle(.primary)
        case .awaitingSirotageRoll:
            rollButton(title: model.mode == .manual ? String(localized: "Saisir le dé relancé") : String(localized: "Relancer le dé"))
        case .awaitingReflex:
            if model.reflexBriefing != nil {
                Button { model.startBriefedReflex() } label: {
                    Label("Prêts ? C'est parti !", systemImage: "hand.tap.fill")
                }
                .buttonStyle(.primary)
            } else {
                Text("Mini-jeu en cours…").font(.headline)
            }
        case .gameOver:
            EmptyView()
        }
    }

    private func rollButton(title: String) -> some View {
        Button {
            Task { await model.roll(reduceMotion: reduceMotion) }
        } label: {
            Label(title, systemImage: model.mode == .manual ? "hand.point.up.left.fill" : "dice.fill")
        }
        .buttonStyle(.primary)
        .keyboardShortcut(.defaultAction)
    }
}

// MARK: - Conseil de la partie guidée

struct CoachCard: View {
    let tip: CoachTip
    /// `nil` : pas de bouton de fermeture (consignes à suivre avant de continuer).
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("🦉")
                .font(.system(size: 34))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(tip.title)
                    .font(Theme.heading(.headline))
                Text(tip.body)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(6)
                }
                .accessibilityLabel(Text("Masquer le conseil"))
            }
        }
        .padding()
        .background(Theme.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Conseil : \(tip.title). \(tip.body)"))
    }
}
