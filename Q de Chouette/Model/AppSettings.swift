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
        static let soundEffects = "soundEffectsEnabled"
        static let music = "musicEnabled"
    }

    private let defaults: UserDefaults

    var rules: RuleSet {
        didSet { save(rules) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) }
    }

    /// Bruitages (dés, gobelet, cloche, fanfare).
    var soundEffectsEnabled: Bool {
        didSet {
            defaults.set(soundEffectsEnabled, forKey: Key.soundEffects)
            SoundEngine.shared.effectsEnabled = soundEffectsEnabled
        }
    }

    /// Musique et ambiance de taverne (désactivées par défaut).
    var musicEnabled: Bool {
        didSet {
            defaults.set(musicEnabled, forKey: Key.music)
            SoundEngine.shared.musicEnabled = musicEnabled
        }
    }

    var lastMode: GameMode {
        didSet { defaults.set(lastMode.rawValue, forKey: Key.lastMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rules = defaults.data(forKey: Key.rules).flatMap { try? JSONDecoder().decode(RuleSet.self, from: $0) } ?? .standard
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        soundEffectsEnabled = defaults.object(forKey: Key.soundEffects) as? Bool ?? true
        musicEnabled = defaults.object(forKey: Key.music) as? Bool ?? false
        lastMode = defaults.string(forKey: Key.lastMode).flatMap(GameMode.init(rawValue:)) ?? .simple
        SoundEngine.shared.effectsEnabled = soundEffectsEnabled
        SoundEngine.shared.musicEnabled = musicEnabled
    }

    private func save(_ rules: RuleSet) {
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: Key.rules)
        }
    }
}
