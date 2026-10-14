// RootView.swift
// Navigation adaptative : barre latérale sur grand écran, pile compacte pilotée par le Router.

import SwiftUI
import SwiftData
import Observation

enum Route: Hashable {
    case setup(guided: Bool)
    case rules
    /// Identifiant stable : l'objet `SavedGame` change à chaque sauvegarde.
    case game(PersistentIdentifier)
    case history
    case settings
}

@Observable
final class Router {
    var path: [Route] = []

    func push(_ route: Route) { path.append(route) }

    /// Remplace tout l'écran courant par une partie (après la configuration ou une revanche) :
    /// le bouton retour ramène alors à l'accueil.
    func startGame(_ game: SavedGame) { path = [.game(game.persistentModelID)] }

    func resume(_ game: SavedGame) { path.append(.game(game.persistentModelID)) }

    func popToRoot() { path = [] }
}

struct RootView: View {
    @Environment(Router.self) private var router
    @Query private var games: [SavedGame]
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var preferredColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        @Bindable var router = router
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredColumn) {
            Group {
                if sizeClass == .compact {
                    HomeView()
                } else {
                    sidebar
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            NavigationStack(path: $router.path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .setup(let guided): SetupView(guided: guided)
                        case .rules: RulesView(onStartGuidedGame: { router.push(.setup(guided: true)) })
                        case .game(let id): GameScreen(gameID: id)
                        case .history: HistoryView()
                        case .settings: SettingsView()
                        }
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: router.path) { _, path in
            preferredColumn = path.isEmpty ? .sidebar : .detail
            if case .game = path.last {
                columnVisibility = .detailOnly
            } else {
                columnVisibility = .all
            }
        }
        .onChange(of: sizeClass) { _, sizeClass in
            if isPlaying && sizeClass == .regular { columnVisibility = .detailOnly }
        }
        .tint(Theme.accent)
        .task { await SoundEngine.shared.prepare() }
    }

    private var isPlaying: Bool {
        if case .game = router.path.last { return true }
        return false
    }

    private var sidebar: some View {
        List {
            Button { router.popToRoot() } label: {
                Label("Accueil", systemImage: "house")
            }
            Section("Jouer") {
                sidebarButton("Nouvelle partie", systemImage: "dice", route: .setup(guided: games.isEmpty))
                sidebarButton("Parties précédentes", systemImage: "scroll", route: .history)
            }
            Section("Le jeu") {
                sidebarButton("Règles du jeu", systemImage: "book.closed", route: .rules)
                sidebarButton("Réglages", systemImage: "gearshape", route: .settings)
            }
        }
        .listStyle(.sidebar)
        .themedBackground()
        .navigationTitle("Cul de Chouette")
    }

    private func sidebarButton(_ title: LocalizedStringKey, systemImage: String, route: Route) -> some View {
        Button { router.path = [route] } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .listRowBackground(router.path.first == route ? Theme.gold.opacity(0.18) : .clear)
        .accessibilityAddTraits(router.path.first == route ? .isSelected : [])
    }

}
