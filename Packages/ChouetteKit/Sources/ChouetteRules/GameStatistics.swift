// GameStatistics.swift
// Statistiques calculées à partir de l'historique d'une partie.

public struct PlayerStatistics: Hashable, Sendable, Identifiable {
    public let player: PlayerID
    public var id: PlayerID { player }
    /// Tours joués (lancers principaux).
    public var turns = 0
    /// Nombre de lancers principaux contenant chaque figure.
    public var figureCounts: [FigureKind: Int] = [:]
    public var pointsGained = 0
    public var pointsLost = 0
    /// Meilleur gain net sur un seul tour (tous mini-jeux compris).
    public var bestTurn = 0
    /// Chouettes-velutes remportées au réflexe.
    public var reflexWins = 0
    /// Pénalités de suite reçues.
    public var suitePenalties = 0

    public func count(_ kind: FigureKind) -> Int { figureCounts[kind, default: 0] }
}

public enum GameStatistics {

    /// Une entrée par joueur, dans l'ordre de jeu.
    public static func compute(for game: GameEngine) -> [PlayerStatistics] {
        var stats = game.players.map { PlayerStatistics(player: $0.id) }
        var turns = game.history
        if game.history.last?.number != game.currentTurn.number { turns.append(game.currentTurn) }

        for turn in turns {
            if let roll = turn.roll {
                stats[turn.player].turns += 1
                for kind in RollAnalyzer.analyze(roll, rules: game.rules).kinds {
                    stats[turn.player].figureCounts[kind, default: 0] += 1
                }
            }
            var net: [PlayerID: Int] = [:]
            for change in turn.changes {
                net[change.player, default: 0] += change.delta
                if change.delta > 0 { stats[change.player].pointsGained += change.delta }
                else { stats[change.player].pointsLost -= change.delta }
                switch change.reason {
                case .chouetteVeluteWon: stats[change.player].reflexWins += 1
                case .suitePenalty: stats[change.player].suitePenalties += 1
                default: break
                }
            }
            for (player, delta) in net where delta > stats[player].bestTurn {
                stats[player].bestTurn = delta
            }
        }
        return stats
    }
}
