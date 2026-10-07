// HomeView.swift
// Accueil : nouvelle partie, reprise de la partie en cours, historique, réglages.

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(Router.self) private var router
    @Query(filter: #Predicate<SavedGame> { !$0.isFinished }, sort: \SavedGame.updatedAt, order: .reverse)
    private var unfinishedGames: [SavedGame]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                VStack(spacing: 14) {
                    if let current = unfinishedGames.first {
                        Button {
                            router.resume(current)
                        } label: {
                            Label("Reprendre la partie", systemImage: "play.fill")
                        }
                        .buttonStyle(.primary)
                        .accessibilityHint(Text(current.playerNames.formatted(.list(type: .and))))

                        Button { router.push(.setup) } label: {
                            Label("Nouvelle partie", systemImage: "plus")
                        }
                        .buttonStyle(.secondary)
                    } else {
                        Button { router.push(.setup) } label: {
                            Label("Nouvelle partie", systemImage: "dice.fill")
                        }
                        .buttonStyle(.primary)
                    }

                    Button { router.push(.history) } label: {
                        Label("Parties précédentes", systemImage: "scroll")
                    }
                    .buttonStyle(.secondary)

                    Button { router.push(.settings) } label: {
                        Label("Réglages et règles", systemImage: "gearshape")
                    }
                    .buttonStyle(.secondary)
                }
                .frame(maxWidth: 480)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
        .themedBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("🦉")
                .font(.system(size: 88))
                .accessibilityHidden(true)
            Text("Cul de Chouette")
                .font(Theme.title())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Le jeu de dés de taverne, de 2 à 8 joueurs")
                .font(.headline)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                DieView(value: 4, size: 40)
                DieView(value: 4, size: 40)
                DieView(value: 1, size: 40)
            }
            .rotationEffect(.degrees(-4))
            .accessibilityHidden(true)
        }
        .padding(.top, 20)
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(Router())
        .modelContainer(Persistence.makeContainer(inMemory: true))
}
