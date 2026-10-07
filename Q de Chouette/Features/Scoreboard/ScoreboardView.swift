// ScoreboardView.swift
// Tableau des scores : classement, historique des tours, statistiques.

import SwiftUI
import ChouetteRules

struct ScoreboardView: View {
    let engine: GameEngine
    let avatars: [Avatar]
    @Environment(\.dismiss) private var dismiss
    @State private var tab = Tab.ranking

    enum Tab: Hashable { case ranking, history, stats }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Affichage", selection: $tab) {
                    Text("Classement").tag(Tab.ranking)
                    Text("Tours").tag(Tab.history)
                    Text("Statistiques").tag(Tab.stats)
                }
                .pickerStyle(.segmented)
                .padding()

                switch tab {
                case .ranking: RankingList(engine: engine, avatars: avatars)
                case .history: TurnHistoryList(engine: engine)
                case .stats: StatisticsList(engine: engine, avatars: avatars)
                }
            }
            .themedBackground()
            .navigationTitle("Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

func avatar(_ avatars: [Avatar], _ player: PlayerID) -> Avatar {
    avatars.indices.contains(player) ? avatars[player] : .owl
}

// MARK: - Classement

struct RankingList: View {
    let engine: GameEngine
    let avatars: [Avatar]

    var body: some View {
        let ranked = engine.players.sorted { $0.score > $1.score }
        let target = Double(engine.rules.targetScore)
        List {
            ForEach(Array(ranked.enumerated()), id: \.element.id) { position, player in
                HStack(spacing: 12) {
                    Text("\(position + 1)")
                        .font(Theme.heading(.title3).monospacedDigit())
                        .frame(minWidth: 24)
                        .foregroundStyle(position == 0 ? Theme.gold : Theme.inkSecondary)
                    AvatarView(avatar: avatar(avatars, player.id), size: 36)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(player.name).font(.headline)
                            Spacer()
                            Text("\(player.score)").font(.headline.monospacedDigit())
                        }
                        ProgressView(value: min(max(Double(player.score), 0), target), total: target)
                            .tint(position == 0 ? Theme.gold : Theme.accent)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(position + 1). \(player.name), \(player.score) points sur \(engine.rules.targetScore)"))
                .listRowBackground(Theme.surface)
            }
        }
    }
}

// MARK: - Historique des tours

struct TurnHistoryList: View {
    let engine: GameEngine

    var body: some View {
        let turns = engine.history.reversed()
        if turns.isEmpty {
            ContentUnavailableView("Aucun tour joué", systemImage: "scroll",
                                   description: Text("Les lancers apparaîtront ici."))
        } else {
            List {
                ForEach(Array(turns), id: \.number) { turn in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Tour \(turn.number) · \(engine.players[turn.player].name)")
                                .font(.headline)
                            Spacer()
                            if let roll = turn.roll {
                                Text(roll.description).font(.subheadline.monospacedDigit())
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                        }
                        if let roll = turn.roll {
                            Text(RollAnalyzer.analyze(roll, rules: engine.rules).name)
                                .font(.subheadline)
                        }
                        ForEach(Array(turn.changes.enumerated()), id: \.offset) { _, change in
                            HStack {
                                Text("\(engine.players[change.player].name) · \(change.reason.label)")
                                    .font(.footnote)
                                Spacer()
                                Text(change.delta.signedPoints)
                                    .font(.footnote.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(change.delta >= 0 ? Theme.positive : Theme.negative)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .listRowBackground(Theme.surface)
                }
            }
        }
    }
}

// MARK: - Statistiques

struct StatisticsList: View {
    let engine: GameEngine
    let avatars: [Avatar]

    var body: some View {
        let stats = GameStatistics.compute(for: engine)
        List {
            ForEach(stats) { stat in
                Section {
                    statRow("Tours joués", stat.turns)
                    statRow("Points gagnés", stat.pointsGained)
                    statRow("Points perdus", stat.pointsLost)
                    statRow("Meilleur tour", stat.bestTurn)
                    statRow("Culs de chouette", stat.count(.culDeChouette))
                    statRow("Chouettes", stat.count(.chouette))
                    statRow("Velutes", stat.count(.velute))
                    statRow("Suites", stat.count(.suite))
                    statRow("Néants", stat.count(.neant))
                    statRow("Réflexes gagnés", stat.reflexWins)
                } header: {
                    HStack {
                        AvatarView(avatar: avatar(avatars, stat.player), size: 22)
                        Text(engine.players[stat.player].name)
                    }
                }
                .listRowBackground(Theme.surface)
            }
        }
    }

    private func statRow(_ label: LocalizedStringKey, _ value: Int) -> some View {
        LabeledContent(label) {
            Text("\(value)").monospacedDigit()
        }
    }
}
