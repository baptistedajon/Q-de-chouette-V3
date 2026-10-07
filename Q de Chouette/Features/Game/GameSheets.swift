// GameSheets.swift
// Fenêtres de la partie : civet, grelottine, paris du sirotage, saisie manuelle des dés.

import SwiftUI
import ChouetteRules

// MARK: - Civet

struct CivetSheet: View {
    let model: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var figure = FigureKind.chouette
    @State private var stake = 10

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Pariez sur la figure de votre prochain lancer. Gagné : vous empochez la mise. Perdu : vous la perdez. Un seul civet par partie.")
                        .font(.callout)
                        .foregroundStyle(Theme.inkSecondary)
                }
                .listRowBackground(Theme.surface)
                Section("Figure") {
                    FigurePicker(selection: $figure)
                }
                .listRowBackground(Theme.surface)
                Section("Mise") {
                    Stepper(value: $stake, in: 1...model.rules.civet.maxStake) {
                        Text("\(stake) points").font(.headline.monospacedDigit())
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .navigationTitle("Civet de \(model.currentPlayer.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Parier") { model.declareCivet(figure, stake: stake) }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Grelottine

struct GrelottineSheet: View {
    let model: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var target: PlayerID?
    @State private var figure = FigureKind.chouette
    @State private var stake = 10

    var body: some View {
        let engine = model.engine
        let targets = engine.grelottineTargets
        let maxStake = target.map { engine.grelottineMaxStake(against: $0) } ?? 1
        NavigationStack {
            Form {
                Section {
                    Text("Défiez un joueur : il lance les dés. S'il obtient la figure, il vous prend la mise ; sinon, c'est vous qui la lui prenez.")
                        .font(.callout)
                        .foregroundStyle(Theme.inkSecondary)
                }
                .listRowBackground(Theme.surface)
                Section("Adversaire") {
                    Picker("Adversaire", selection: $target) {
                        ForEach(targets, id: \.self) { id in
                            Text("\(model.name(of: id)) (\(engine.players[id].score))").tag(Optional(id))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                .listRowBackground(Theme.surface)
                Section("Figure à réussir") {
                    FigurePicker(selection: $figure)
                }
                .listRowBackground(Theme.surface)
                Section {
                    Stepper(value: $stake, in: 1...max(1, maxStake)) {
                        Text("\(stake) points").font(.headline.monospacedDigit())
                    }
                } header: {
                    Text("Mise")
                } footer: {
                    Text("Maximum : \(maxStake) points")
                }
                .listRowBackground(Theme.surface)
            }
            .navigationTitle("Grelottine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Défier") {
                        if let target { model.launchGrelottine(target: target, figure: figure, stake: stake) }
                    }
                    .disabled(target == nil)
                }
            }
            .onAppear { if target == nil { target = targets.first } }
            .onChange(of: maxStake) { _, newMax in stake = min(stake, max(1, newMax)) }
        }
    }
}

// MARK: - Paris du sirotage

struct SirotageBetsSheet: View {
    let model: GameViewModel
    @State private var bets: [PlayerID: Int] = [:]

    var body: some View {
        let others = model.players.filter { $0.id != model.engine.currentPlayer }
        NavigationStack {
            Form {
                Section {
                    Text("Sur quelle valeur tombera le dé relancé ? Chaque pari juste rapporte \(model.rules.sirotage.betReward) points.")
                        .font(.callout)
                        .foregroundStyle(Theme.inkSecondary)
                }
                .listRowBackground(Theme.surface)
                Section("Paris") {
                    ForEach(others) { player in
                        Picker(selection: Binding(get: { bets[player.id] ?? 0 },
                                                  set: { bets[player.id] = $0 == 0 ? nil : $0 })) {
                            Text("Pas de pari").tag(0)
                            ForEach(DieFace.all, id: \.self) { face in
                                Text("\(face.value) – \(face.birdName)").tag(face.value)
                            }
                        } label: {
                            HStack {
                                AvatarView(avatar: model.avatar(of: player.id), size: 28)
                                Text(player.name)
                            }
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .navigationTitle("Paris")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") { model.placeBets(bets) }
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Saisie manuelle

/// Saisie rapide des valeurs de vrais dés : une rangée de six faces par dé.
struct ManualDiceEntry: View {
    let count: Int
    let title: String
    let onSubmit: ([DieFace]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var values: [Int?]

    init(count: Int, title: String, onSubmit: @escaping ([DieFace]) -> Void) {
        self.count = count
        self.title = title
        self.onSubmit = onSubmit
        _values = State(initialValue: Array(repeating: nil, count: count))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(0..<count, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            if count > 1 {
                                Text("Dé \(index + 1)").font(.headline)
                            }
                            HStack(spacing: 8) {
                                ForEach(1...6, id: \.self) { value in
                                    Button {
                                        values[index] = value
                                    } label: {
                                        DieView(value: value, size: 44, isHighlighted: values[index] == value)
                                            .opacity(values[index] == nil || values[index] == value ? 1 : 0.45)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("\(value)"))
                                    .accessibilityAddTraits(values[index] == value ? .isSelected : [])
                                }
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(Text("Dé \(index + 1)"))
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        onSubmit(values.compactMap { $0.flatMap(DieFace.init) })
                    }
                    .disabled(values.contains(nil))
                }
            }
        }
        // Les trois rangées doivent être visibles d'emblée, même sur petit écran.
        .presentationDetents(count == 1 ? [.medium, .large] : [.large])
    }
}

// MARK: - Choix d'une figure

struct FigurePicker: View {
    @Binding var selection: FigureKind

    var body: some View {
        Picker("Figure", selection: $selection) {
            ForEach(FigureKind.betOrder, id: \.self) { kind in
                Text(kind.name).tag(kind)
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }
}
