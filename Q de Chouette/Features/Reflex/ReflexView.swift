// ReflexView.swift
// Mini-jeu « premier / dernier qui crie » : chaque joueur a sa zone sur l'écran partagé.
// Après un délai aléatoire, le signal apparaît ; on tape sa zone en criant la phrase.
// Taper avant le signal est un faux départ (pénalisé si la bévue est activée).

import SwiftUI
import UIKit
import ChouetteRules

struct ReflexView: View {
    let challenge: ReflexChallenge
    let players: [PlayerState]
    let avatars: [Avatar]
    let rules: RuleSet
    let onComplete: (ReflexOutcome) -> Void

    private enum Stage { case waiting, signal, result }

    /// Durée maximale après le signal.
    private static let timeout: TimeInterval = 4
    private static let resultDisplay: Duration = .milliseconds(1800)

    @State private var session: ReflexSession
    @State private var stage = Stage.waiting
    @State private var tapTick = 0
    @State private var signalTick = 0
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(challenge: ReflexChallenge, players: [PlayerState], avatars: [Avatar], rules: RuleSet,
         onComplete: @escaping (ReflexOutcome) -> Void) {
        self.challenge = challenge
        self.players = players
        self.avatars = avatars
        self.rules = rules
        self.onComplete = onComplete
        _session = State(initialValue: ReflexSession(challenge: challenge, rules: rules))
    }

    var body: some View {
        GeometryReader { geometry in
            let zones = ReflexLayout.zones(count: challenge.participants.count, in: geometry.size)
            ZStack(alignment: .topLeading) {
                ForEach(Array(challenge.participants.enumerated()), id: \.element) { index, player in
                    let zone = zones[index]
                    zoneView(for: player)
                        .rotationEffect(.degrees(zone.isRotated ? 180 : 0))
                        .frame(width: zone.rect.width, height: zone.rect.height)
                        .background(zoneColor(for: player), in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.gold.opacity(0.6), lineWidth: 2))
                        .offset(x: zone.rect.minX, y: zone.rect.minY)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { tap(player, at: ProcessInfo.processInfo.systemUptime) }
                }

                MultiTouchSurface { point, time in
                    guard let index = zones.firstIndex(where: { $0.rect.contains(point) }) else { return }
                    tap(challenge.participants[index], at: time)
                }
                .accessibilityHidden(true)

                banner
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(light: 0x1C1511, dark: 0x0E0A08).ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sensoryFeedback(trigger: tapTick) { _, _ in settings.hapticsEnabled ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: signalTick) { _, _ in settings.hapticsEnabled ? .impact(weight: .heavy, intensity: 1) : nil }
        .task { await run() }
    }

    // MARK: Déroulement

    private func run() async {
        // Délai aléatoire avant le signal, plus long avec VoiceOver pour laisser le temps de s'orienter.
        let base = UIAccessibility.isVoiceOverRunning ? 3.0 : 1.4
        try? await Task.sleep(for: .seconds(Double.random(in: base...(base + 1.6))))
        session.signal(at: ProcessInfo.processInfo.systemUptime)
        stage = .signal
        signalTick += 1
        if UIAccessibility.isVoiceOverRunning {
            AccessibilityNotification.Announcement(challenge.kind.phrase).post()
        }

        let deadline = ContinuousClock.now + .seconds(Self.timeout * (UIAccessibility.isVoiceOverRunning ? 2 : 1))
        while !session.isComplete && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(30))
        }
        stage = .result
        try? await Task.sleep(for: Self.resultDisplay)
        onComplete(session.outcome)
    }

    private func tap(_ player: PlayerID, at time: TimeInterval) {
        guard stage != .result else { return }
        switch session.registerTap(by: player, at: time) {
        case .accepted, .falseStart: tapTick += 1
        case .ignored: break
        }
    }

    // MARK: Affichage

    private var banner: some View {
        VStack(spacing: 6) {
            switch stage {
            case .waiting:
                Text("Attendez le signal…")
                    .font(Theme.heading(.title2))
                Text(challenge.kind.instruction)
                    .font(.subheadline)
            case .signal:
                Text(challenge.kind.phrase)
                    .font(Theme.title(.largeTitle))
                    .multilineTextAlignment(.center)
                    .scaleEffect(reduceMotion ? 1 : 1.05)
            case .result:
                Text(resultText)
                    .font(Theme.heading(.title2))
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 30)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private func zoneView(for player: PlayerID) -> some View {
        VStack(spacing: 8) {
            AvatarView(avatar: avatars.indices.contains(player) ? avatars[player] : .owl, size: 44)
            Text(players[player].name)
                .font(Theme.heading(.title3))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(status(for: player))
                .font(.headline)
        }
        .foregroundStyle(Color.white)
        .padding(8)
    }

    private func rank(of player: PlayerID) -> Int? {
        session.taps.firstIndex { $0.player == player }
    }

    private func status(for player: PlayerID) -> String {
        if session.falseStarts.contains(player) { return String(localized: "Bévue ! Trop tôt") }
        if let rank = rank(of: player) {
            switch challenge.kind {
            case .pasMouLeCaillou:
                return rank == 0 ? String(localized: "Premier ! 🏆") : String(localized: "Trop tard")
            case .grelotteCaPicote:
                return String(localized: "\(rank + 1)e")
            }
        }
        switch stage {
        case .waiting: return String(localized: "Pas encore…")
        case .signal: return String(localized: "TAPEZ !")
        case .result: return String(localized: "Trop lent !")
        }
    }

    private func zoneColor(for player: PlayerID) -> Color {
        if session.falseStarts.contains(player) { return Theme.negative.opacity(0.75) }
        if let rank = rank(of: player) {
            if challenge.kind == .pasMouLeCaillou && rank == 0 { return Theme.gold.opacity(0.85) }
            return Theme.positive.opacity(0.7)
        }
        switch stage {
        case .waiting: return Color.white.opacity(0.08)
        case .signal: return Theme.accent.opacity(0.85)
        case .result: return Color.white.opacity(0.08)
        }
    }

    private var resultText: String {
        switch challenge.kind {
        case .pasMouLeCaillou:
            guard let first = session.taps.first else { return String(localized: "Personne n'a crié !") }
            return String(localized: "\(players[first.player].name) remporte \(challenge.points) points !")
        case .grelotteCaPicote:
            let losers = challenge.losers(for: session.outcome, rules: rules)
            if losers.isEmpty { return String(localized: "Personne ne perd de points.") }
            let names = losers.map { players[$0].name }.formatted(.list(type: .and))
            return losers.count == 1
                ? String(localized: "\(names) perd \(challenge.points) points.")
                : String(localized: "\(names) perdent \(challenge.points) points chacun.")
        }
    }
}
