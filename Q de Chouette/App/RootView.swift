// RootView.swift
// Pile de navigation unique, pilotée par le `Router`.

import SwiftUI
import SwiftData
import Observation

enum Route: Hashable {
    case setup
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

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .setup: SetupView()
                    case .game(let id): GameScreen(gameID: id)
                    case .history: HistoryView()
                    case .settings: SettingsView()
                    }
                }
        }
        .tint(Theme.accent)
    }
}
