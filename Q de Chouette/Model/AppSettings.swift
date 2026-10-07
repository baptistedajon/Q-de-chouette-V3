// AppSettings.swift
// Réglages de l'app, enregistrés dans UserDefaults. Les règles choisies ici
// sont copiées dans chaque nouvelle partie (une partie en cours ne change pas de règles).

import Foundation
import Observation
import ChouetteRules

@Observable
final class AppSettings {
    private enum Key {
        static let rules = "rules.v1"
        static let haptics = "hapticsEnabled"
        static let lastMode = "lastGameMode"
    }

    private let defaults: UserDefaults

    var rules: RuleSet {
        didSet { save(rules) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) }
    }

    var lastMode: GameMode {
        didSet { defaults.set(lastMode.rawValue, forKey: Key.lastMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rules = defaults.data(forKey: Key.rules).flatMap { try? JSONDecoder().decode(RuleSet.self, from: $0) } ?? .standard
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        lastMode = defaults.string(forKey: Key.lastMode).flatMap(GameMode.init(rawValue:)) ?? .simple
    }

    private func save(_ rules: RuleSet) {
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: Key.rules)
        }
    }
}
