// SoundEngine.swift
// Sons de l'app, entièrement synthétisés en code (aucun fichier audio, aucun droit à céder) :
// chocs de dés, gobelet, cloche du signal, fanfare, ambiance de taverne et air de luth.
// ⚠︎ SONS PROVISOIRES — de qualité correcte, mais à remplacer idéalement par des
// enregistrements (voir ASSETS.md). Seules les fonctions `synth…` sont à remplacer.

import AVFoundation
import Foundation
import ChouetteRules

@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    enum Effect: CaseIterable { case clack, rattle, signal, fanfare }

    var effectsEnabled = true
    var musicEnabled = false {
        didSet { updateMusic() }
    }

    nonisolated static let sampleRate = 44_100.0
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: SoundEngine.sampleRate, channels: 1)!
    private var effectPlayers: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let musicPlayer = AVAudioPlayerNode()
    private let ambiencePlayer = AVAudioPlayerNode()
    private var buffers: [Effect: [AVAudioPCMBuffer]] = [:]
    private var musicBuffer: AVAudioPCMBuffer?
    private var ambienceBuffer: AVAudioPCMBuffer?
    private var isPrepared = false
    private var isMusicPlaying = false

    private init() {}

    /// Génère les sons (en arrière-plan) et prépare le moteur audio. Idempotent.
    func prepare() async {
        guard !isPrepared else { return }
        isPrepared = true
        let samples = await Task.detached(priority: .utility) { Synth.all() }.value

        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<8 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            effectPlayers.append(player)
        }
        for player in [musicPlayer, ambiencePlayer] {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        musicPlayer.volume = 0.35
        ambiencePlayer.volume = 0.5

        buffers[.clack] = samples.clacks.map(makeBuffer)
        buffers[.rattle] = [makeBuffer(samples.rattle)]
        buffers[.signal] = [makeBuffer(samples.signal)]
        buffers[.fanfare] = [makeBuffer(samples.fanfare)]
        musicBuffer = makeBuffer(samples.music)
        ambienceBuffer = makeBuffer(samples.ambience)
        updateMusic()
    }

    func play(_ effect: Effect, volume: Float = 1) {
        guard effectsEnabled, let variants = buffers[effect], let buffer = variants.randomElement(),
              startEngine() else { return }
        let player = effectPlayers[nextPlayer]
        nextPlayer = (nextPlayer + 1) % effectPlayers.count
        player.stop()
        player.volume = max(0.05, min(volume, 1))
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    private func updateMusic() {
        guard isPrepared, let musicBuffer, let ambienceBuffer else { return }
        if musicEnabled, !isMusicPlaying, startEngine() {
            musicPlayer.scheduleBuffer(musicBuffer, at: nil, options: .loops)
            ambiencePlayer.scheduleBuffer(ambienceBuffer, at: nil, options: .loops)
            musicPlayer.play()
            ambiencePlayer.play()
            isMusicPlaying = true
        } else if !musicEnabled, isMusicPlaying {
            musicPlayer.stop()
            ambiencePlayer.stop()
            isMusicPlaying = false
        }
    }

    private func startEngine() -> Bool {
        if engine.isRunning { return true }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        return buffer
    }
}

// MARK: - Synthèse

/// Fonctions pures de synthèse sonore.
nonisolated enum Synth {
    struct Samples: Sendable {
        var clacks: [[Float]], rattle: [Float], signal: [Float], fanfare: [Float], music: [Float], ambience: [Float]
    }

    static let sr = SoundEngine.sampleRate

    static func all() -> Samples {
        var rng = SeededGenerator(seed: 343)
        return Samples(clacks: (0..<5).map { clack(variant: $0, rng: &rng) },
                       rattle: rattle(rng: &rng),
                       signal: bell(),
                       fanfare: fanfare(rng: &rng),
                       music: luteTune(rng: &rng),
                       ambience: tavernAmbience(rng: &rng))
    }

    /// Choc d'un dé en os sur du bois : bruit bref + deux résonances amorties.
    static func clack(variant: Int, rng: inout SeededGenerator) -> [Float] {
        let n = Int(sr * 0.12)
        let f1 = 1900.0 + Double(variant) * 230, f2 = 3300.0 + Double(variant) * 310
        return (0..<n).map { i in
            let t = Double(i) / sr
            let noise = Double.random(in: -1...1, using: &rng) * exp(-t * 90)
            let tone = (sin(2 * .pi * f1 * t) * 0.6 + sin(2 * .pi * f2 * t) * 0.35) * exp(-t * 55)
            let body = sin(2 * .pi * 180 * t) * exp(-t * 35) * 0.5   // le bois de la table
            return Float((noise * 0.5 + tone + body) * 0.55)
        }
    }

    /// Gobelet en cuir secoué : chocs étouffés rapprochés puis lancer.
    static func rattle(rng: inout SeededGenerator) -> [Float] {
        let n = Int(sr * 0.7)
        var out = [Float](repeating: 0, count: n)
        for k in 0..<14 {
            let start = Int(Double(k) * sr * 0.04 + Double.random(in: 0...(sr * 0.015), using: &rng))
            let hit = clack(variant: k % 5, rng: &rng)
            let gain = Float(0.35 * (1 - Double(k) / 20))
            for (i, s) in hit.enumerated() where start + i < n {
                out[start + i] += s * gain
            }
        }
        // Le cuir étouffe les aigus : passe-bas simple.
        return normalized(lowPass(out, amount: 0.35), peak: 0.65)
    }

    /// Cloche (partiels inharmoniques) pour le signal des cris.
    static func bell() -> [Float] {
        let n = Int(sr * 1.6)
        let base = 660.0
        let partials: [(Double, Double, Double)] = [(1, 1, 3), (2.76, 0.5, 5), (5.4, 0.25, 8), (8.9, 0.12, 12)]
        return (0..<n).map { i in
            let t = Double(i) / sr
            let attack = min(1, t * 400)
            return Float(partials.reduce(0) { $0 + sin(2 * .pi * base * $1.0 * t) * $1.1 * exp(-t * $1.2) } * 0.35 * attack)
        }
    }

    /// Petite fanfare au luth (Karplus-Strong) : arpège ré majeur puis accord.
    static func fanfare(rng: inout SeededGenerator) -> [Float] {
        let n = Int(sr * 2.4)
        var out = [Float](repeating: 0, count: n)
        let notes: [(Double, Double)] = [(293.66, 0), (369.99, 0.15), (440, 0.3), (587.33, 0.45),
                                         (293.66, 0.75), (369.99, 0.75), (440, 0.75), (587.33, 0.75)]
        for (freq, at) in notes {
            mix(pluck(freq: freq, duration: 1.6, rng: &rng), into: &out, at: Int(at * sr), gain: 0.32)
        }
        return out
    }

    /// Air de luth en ré dorien sur un bourdon, ~19 s, bouclé sans coupure audible.
    static func luteTune(rng: inout SeededGenerator) -> [Float] {
        let beat = 60.0 / 96
        // (degré MIDI, durée en temps)
        let melody: [(Int, Double)] = [
            (62, 1), (65, 0.5), (67, 0.5), (69, 1), (67, 1), (65, 1), (64, 1), (62, 2),
            (69, 1), (72, 0.5), (71, 0.5), (69, 1), (67, 1), (65, 1.5), (64, 0.5), (62, 2),
            (65, 1), (67, 1), (69, 1.5), (67, 0.5), (65, 1), (64, 1), (60, 1), (62, 3),
        ]
        let total = melody.reduce(0) { $0 + $1.1 } * beat
        let n = Int(total * sr)
        var out = [Float](repeating: 0, count: n)
        var time = 0.0
        for (midi, length) in melody {
            let freq = 440 * pow(2, Double(midi - 69) / 12)
            mix(pluck(freq: freq, duration: min(length * beat + 0.6, 2.5), rng: &rng), into: &out,
                at: Int(time * sr), gain: 0.3, wrap: true)
            if length >= 1 {   // basse sur les temps longs
                mix(pluck(freq: freq / 2, duration: 1.8, rng: &rng), into: &out, at: Int(time * sr), gain: 0.16, wrap: true)
            }
            time += length * beat
        }
        // Bourdon ré-la très doux.
        for i in 0..<n {
            let t = Double(i) / sr
            out[i] += Float((sin(2 * .pi * 73.42 * t) + 0.6 * sin(2 * .pi * 110 * t)) * 0.025)
        }
        return out
    }

    /// Feu de cheminée : grondement grave + crépitements, 12 s en boucle.
    static func tavernAmbience(rng: inout SeededGenerator) -> [Float] {
        let n = Int(sr * 12)
        var out = [Float](repeating: 0, count: n)
        var brown = 0.0
        for i in 0..<n {
            brown = (brown + Double.random(in: -1...1, using: &rng) * 0.02) * 0.995
            out[i] = Float(brown * 0.6)
        }
        for _ in 0..<70 {
            let start = Int.random(in: 0..<n, using: &rng)
            let length = Int(sr * Double.random(in: 0.003...0.02, using: &rng))
            let gain = Float.random(in: 0.05...0.25, using: &rng)
            for i in 0..<length {
                out[(start + i) % n] += Float.random(in: -1...1, using: &rng) * gain * Float(exp(-Double(i) / Double(length) * 4))
            }
        }
        return out
    }

    // MARK: Outils

    /// Corde pincée (algorithme de Karplus-Strong).
    static func pluck(freq: Double, duration: Double, rng: inout SeededGenerator) -> [Float] {
        let n = Int(duration * sr)
        let period = max(2, Int(sr / freq))
        var line = (0..<period).map { _ in Float.random(in: -1...1, using: &rng) }
        var out = [Float](repeating: 0, count: n)
        var index = 0
        for i in 0..<n {
            let next = (index + 1) % period
            let value = line[index]
            line[index] = (value + line[next]) * 0.5 * 0.996
            out[i] = value
            index = next
        }
        // Attaque adoucie pour éviter le clic.
        for i in 0..<min(64, n) { out[i] *= Float(i) / 64 }
        return out
    }

    static func mix(_ source: [Float], into out: inout [Float], at start: Int, gain: Float, wrap: Bool = false) {
        for (i, s) in source.enumerated() {
            var j = start + i
            if j >= out.count {
                guard wrap else { break }
                j %= out.count   // la fin d'une note déborde sur le début de la boucle
            }
            out[j] += s * gain
        }
    }

    static func normalized(_ input: [Float], peak: Float) -> [Float] {
        let current = input.map(abs).max() ?? 0
        guard current > 0 else { return input }
        return input.map { $0 * peak / current }
    }

    static func lowPass(_ input: [Float], amount: Float) -> [Float] {
        var out = input
        var previous: Float = 0
        for i in out.indices {
            previous += (input[i] - previous) * amount
            out[i] = previous
        }
        return out
    }
}
