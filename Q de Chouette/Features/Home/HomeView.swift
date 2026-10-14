// HomeView.swift
// Accueil : nouvelle partie, reprise de la partie en cours, historique, réglages.

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(Router.self) private var router
    @Query(filter: #Predicate<SavedGame> { !$0.isFinished }, sort: \SavedGame.updatedAt, order: .reverse)
    private var unfinishedGames: [SavedGame]
    @Query private var allGames: [SavedGame]

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var hasRoomForColumns = false

    /// Aucune partie jouée : on propose d'office la partie guidée.
    private var isFirstGame: Bool { allGames.isEmpty }

    var body: some View {
        ScrollView {
            adaptiveLayout {
                header
                    .frame(maxWidth: .infinity)
                VStack(spacing: 14) {
                    if let current = unfinishedGames.first {
                        Button {
                            router.resume(current)
                        } label: {
                            Label("Reprendre la partie", systemImage: "play.fill")
                        }
                        .buttonStyle(.primary)
                        .accessibilityHint(Text(current.playerNames.formatted(.list(type: .and))))

                        Button { router.push(.setup(guided: isFirstGame)) } label: {
                            Label("Nouvelle partie", systemImage: "plus")
                        }
                        .buttonStyle(.secondary)
                    } else {
                        Button { router.push(.setup(guided: isFirstGame)) } label: {
                            Label("Nouvelle partie", systemImage: "dice.fill")
                        }
                        .buttonStyle(.primary)
                    }

                    Button { router.push(.rules) } label: {
                        Label("Règles du jeu", systemImage: "book.closed")
                    }
                    .buttonStyle(.secondary)

                    Button { router.push(.history) } label: {
                        Label("Parties précédentes", systemImage: "scroll")
                    }
                    .buttonStyle(.secondary)

                    Button { router.push(.settings) } label: {
                        Label("Réglages", systemImage: "gearshape")
                    }
                    .buttonStyle(.secondary)
                }
                .frame(maxWidth: 480)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: 1060)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: Bool.self) { geometry in
            geometry.size.width >= 300 + 300 + 40 + 48
        } action: { hasRoomForColumns = $0 }
        .themedBackground()
        .toolbar(sizeClass == .compact ? .hidden : .visible, for: .navigationBar)
    }

    private var adaptiveLayout: AnyLayout {
        sizeClass == .regular && hasRoomForColumns && !dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 40))
            : AnyLayout(VStackLayout(spacing: 28))
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
