// Persistence.swift
// Modèles SwiftData. Le moteur de jeu (valeur Codable) est stocké en JSON :
// l'état exact de la partie est restauré, règles comprises. Les autres champs
// sont des résumés pour les listes, sans avoir à décoder le moteur.

import Foundation
import SwiftData
import ChouetteRules

/// Façon d'obtenir les dés pendant une partie.
enum GameMode: String, Codable, CaseIterable, Identifiable {
    /// Dés virtuels animés en 2D.
    case simple
    /// Table 3D : dés physiques lancés d'un geste ou en secouant le téléphone.
    case table3D
    /// Vrais dés, valeurs saisies à la main.
    case manual
    /// Vrais dés, lus par l'appareil photo (avec correction possible).
    case camera

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .simple: "Dés virtuels"
        case .table3D: "Table 3D"
        case .manual: "Mes propres dés"
        case .camera: "Mes dés, lus à la caméra"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .simple: "L'app lance les dés pour vous."
        case .table3D: "Secouez le téléphone ou lancez d'un geste sur une table de taverne."
        case .manual: "Lancez vos dés et saisissez les valeurs."
        case .camera: "Lancez vos dés, l'appareil photo lit les valeurs."
        }
    }

    var systemImage: String {
        switch self {
        case .simple: "dice"
        case .table3D: "cube"
        case .manual: "hand.point.up.left"
        case .camera: "camera.viewfinder"
        }
    }
}

@Model
final class SavedGame {
    var createdAt: Date
    var updatedAt: Date
    var modeRaw: String
    var playerNames: [String]
    var avatarIDs: [String]
    /// `GameEngine` encodé en JSON.
    var engineData: Data
    var isFinished: Bool
    var winnerName: String?
    var turnCount: Int
    /// Scores dans l'ordre de jeu, pour l'historique.
    var scores: [Int]
    /// Partie guidée : chaque lancer est expliqué.
    var isGuided: Bool = false

    init(engine: GameEngine, avatars: [Avatar], mode: GameMode, isGuided: Bool = false) throws {
        createdAt = .now
        updatedAt = .now
        modeRaw = mode.rawValue
        playerNames = engine.players.map(\.name)
        avatarIDs = avatars.map(\.rawValue)
        engineData = try JSONEncoder().encode(engine)
        isFinished = false
        turnCount = 0
        scores = engine.players.map(\.score)
        self.isGuided = isGuided
    }

    var mode: GameMode { GameMode(rawValue: modeRaw) ?? .simple }

    var avatars: [Avatar] { avatarIDs.map { Avatar(rawValue: $0) ?? .owl } }

    func decodeEngine() throws -> GameEngine {
        try JSONDecoder().decode(GameEngine.self, from: engineData)
    }

    /// Enregistre l'état du moteur et met à jour les résumés.
    func store(_ engine: GameEngine) throws {
        engineData = try JSONEncoder().encode(engine)
        updatedAt = .now
        isFinished = engine.isOver
        winnerName = engine.winner.map { engine.players[$0].name }
        turnCount = engine.history.count
        scores = engine.players.map(\.score)
    }
}

/// Joueur déjà rencontré, proposé lors de la configuration d'une nouvelle partie.
@Model
final class PlayerProfile {
    @Attribute(.unique) var name: String
    var avatarID: String
    var lastPlayed: Date
    var gamesPlayed: Int
    var gamesWon: Int

    init(name: String, avatar: Avatar) {
        self.name = name
        avatarID = avatar.rawValue
        lastPlayed = .now
        gamesPlayed = 0
        gamesWon = 0
    }

    var avatar: Avatar { Avatar(rawValue: avatarID) ?? .owl }
}

enum Persistence {
    static let schema = Schema([SavedGame.self, PlayerProfile.self])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Base illisible (ex. schéma incompatible en développement) : on repart d'une base
            // en mémoire plutôt que de planter. L'erreur est journalisée pour le débogage.
            print("⚠︎ Impossible d'ouvrir la base SwiftData : \(error)")
            return try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }
}
