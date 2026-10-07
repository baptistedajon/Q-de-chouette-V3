// SetupViewModel.swift
// Préparation d'une partie : joueurs, avatars, mode, premier joueur.

import Foundation
import Observation
import SwiftData
import SwiftUI
import ChouetteRules

@Observable
final class SetupViewModel {

    struct Entry: Identifiable, Hashable {
        let id = UUID()
        var name: String
        var avatar: Avatar
    }

    enum FirstPlayer: Hashable {
        case random
        case entry(UUID)
    }

    var entries: [Entry]
    var mode: GameMode
    var firstPlayer = FirstPlayer.random

    init(mode: GameMode) {
        self.mode = mode
        entries = (0..<2).map { Entry(name: "", avatar: .defaultFor(index: $0)) }
    }

    // MARK: Joueurs

    var canAddPlayer: Bool { entries.count < GameEngine.playerRange.upperBound }
    var canRemovePlayer: Bool { entries.count > GameEngine.playerRange.lowerBound }

    func addPlayer(name: String = "", avatar: Avatar? = nil) {
        guard canAddPlayer else { return }
        let used = Set(entries.map(\.avatar))
        let chosen = avatar ?? Avatar.allCases.first { !used.contains($0) } ?? .defaultFor(index: entries.count)
        // Remplit d'abord une ligne vide plutôt que d'en ajouter une.
        if !name.isEmpty, let empty = entries.firstIndex(where: { trimmed($0.name).isEmpty }) {
            entries[empty].name = name
            entries[empty].avatar = chosen
        } else {
            entries.append(Entry(name: name, avatar: chosen))
        }
    }

    func remove(at offsets: IndexSet) {
        guard entries.count - offsets.count >= GameEngine.playerRange.lowerBound else { return }
        let removed = offsets.map { entries[$0].id }
        entries.remove(atOffsets: offsets)
        if case .entry(let id) = firstPlayer, removed.contains(id) { firstPlayer = .random }
    }

    func move(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
    }

    func isAlreadyAdded(_ name: String) -> Bool {
        entries.contains { trimmed($0.name).caseInsensitiveCompare(name) == .orderedSame }
    }

    // MARK: Validation

    /// Nom affiché pour une ligne : le nom saisi ou « Joueur n » si vide.
    func resolvedName(at index: Int) -> String {
        let name = trimmed(entries[index].name)
        return name.isEmpty ? String(localized: "Joueur \(index + 1)") : name
    }

    var resolvedNames: [String] { entries.indices.map(resolvedName(at:)) }

    /// Problème empêchant de commencer, ou `nil`.
    var validationMessage: String? {
        let names = resolvedNames.map { $0.lowercased() }
        if Set(names).count != names.count {
            return String(localized: "Deux joueurs portent le même nom.")
        }
        return nil
    }

    var canStart: Bool {
        GameEngine.playerRange.contains(entries.count) && validationMessage == nil
    }

    // MARK: Lancement

    /// Crée et enregistre la partie, et met à jour les profils de joueurs.
    func startGame(rules: RuleSet, in context: ModelContext) throws -> SavedGame {
        let names = resolvedNames
        let first: PlayerID = switch firstPlayer {
        case .random: Int.random(in: 0..<names.count)
        case .entry(let id): entries.firstIndex { $0.id == id } ?? 0
        }
        let engine = try GameEngine(playerNames: names, rules: rules, firstPlayer: first)
        let game = try SavedGame(engine: engine, avatars: entries.map(\.avatar), mode: mode)
        context.insert(game)

        let profiles = (try? context.fetch(FetchDescriptor<PlayerProfile>())) ?? []
        for (index, entry) in entries.enumerated() where !trimmed(entry.name).isEmpty {
            let name = names[index]
            if let profile = profiles.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                profile.avatarID = entry.avatar.rawValue
                profile.lastPlayed = .now
            } else {
                context.insert(PlayerProfile(name: name, avatar: entry.avatar))
            }
        }
        try context.save()
        return game
    }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
}
