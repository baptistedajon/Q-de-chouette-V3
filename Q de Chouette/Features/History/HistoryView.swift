// HistoryView.swift
// Liste des parties enregistrées : reprise des parties en cours, détail des parties finies.

import SwiftUI
import SwiftData
import ChouetteRules

struct HistoryView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedGame.updatedAt, order: .reverse) private var games: [SavedGame]
    @State private var detail: SavedGame?

    var body: some View {
        Group {
            if games.isEmpty {
                ContentUnavailableView("Aucune partie", systemImage: "scroll",
                                       description: Text("Vos parties apparaîtront ici."))
            } else {
                List {
                    ForEach(games) { game in
                        Button {
                            if game.isFinished { detail = game } else { router.resume(game) }
                        } label: {
                            row(game)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(games[index]) }
                        try? context.save()
                    }
                }
            }
        }
        .themedBackground()
        .navigationTitle("Parties précédentes")
        .toolbar { if !games.isEmpty { EditButton() } }
        .sheet(item: $detail) { game in
            if let engine = try? game.decodeEngine() {
                ScoreboardView(engine: engine, avatars: game.avatars)
            }
        }
    }

    private func row(_ game: SavedGame) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(game.updatedAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                if game.isFinished {
                    Label(game.winnerName ?? "", systemImage: "trophy.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                } else {
                    Text("En cours").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                }
            }
            HStack(spacing: -6) {
                ForEach(Array(game.avatars.enumerated()), id: \.offset) { _, avatar in
                    AvatarView(avatar: avatar, size: 26)
                }
            }
            Text(zip(game.playerNames, game.scores).map { "\($0) \($1)" }.joined(separator: " · "))
                .font(.body)
                .lineLimit(2)
            Text("\(game.turnCount) tours · \(Text(game.mode.title))")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(game.isFinished ? Text("Afficher les scores") : Text("Reprendre la partie"))
    }
}
