// ReflexPracticeView.swift
// Entraînement au mini-jeu de réflexe, seul : on mesure le temps de réaction.

import SwiftUI
import UIKit
import ChouetteRules

struct ReflexPracticeView: View {
    let kind: ReflexKind

    private enum Stage: Equatable {
        case waiting
        case signal(since: TimeInterval)
        case result(milliseconds: Int)
        case falseStart
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var stage = Stage.waiting
    @State private var attempt = 0
    @State private var best: Int?
    @State private var tick = 0

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(title)
                    .font(Theme.title(.largeTitle))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                if let best {
                    Text("Meilleur temps : \(best) ms").font(.headline.monospacedDigit())
                }
            }
            .foregroundStyle(Color.white)
            .padding(32)
            .allowsHitTesting(false)

            MultiTouchSurface { _, time in tap(at: time) }
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.white)
            }
            .accessibilityLabel(Text("Fermer"))
            .padding()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { tap(at: ProcessInfo.processInfo.systemUptime) }
        .sensoryFeedback(trigger: tick) { _, _ in settings.hapticsEnabled ? .impact(weight: .heavy) : nil }
        .task(id: attempt) { await waitForSignal() }
    }

    private func waitForSignal() async {
        stage = .waiting
        try? await Task.sleep(for: .seconds(Double.random(in: 1.5...3.5)))
        guard !Task.isCancelled, stage == .waiting else { return }
        stage = .signal(since: ProcessInfo.processInfo.systemUptime)
        tick += 1
        if UIAccessibility.isVoiceOverRunning {
            AccessibilityNotification.Announcement(kind.phrase).post()
        }
    }

    private func tap(at time: TimeInterval) {
        switch stage {
        case .waiting:
            stage = .falseStart
        case .signal(let since):
            let ms = max(0, Int((time - since) * 1000))
            stage = .result(milliseconds: ms)
            best = min(best ?? .max, ms)
        case .result, .falseStart:
            attempt += 1   // nouvel essai
        }
    }

    private var title: String {
        switch stage {
        case .waiting: String(localized: "Attendez le signal…")
        case .signal: kind.phrase
        case .result(let ms): String(localized: "\(ms) ms")
        case .falseStart: String(localized: "Trop tôt !")
        }
    }

    private var subtitle: String {
        switch stage {
        case .waiting: String(localized: "Touchez l'écran dès qu'il change de couleur.")
        case .signal: String(localized: "Touchez !")
        case .result: String(localized: "Touchez pour réessayer.")
        case .falseStart: String(localized: "En partie, ce serait une bévue. Touchez pour réessayer.")
        }
    }

    private var background: Color {
        switch stage {
        case .waiting: Color(light: 0x1C1511, dark: 0x0E0A08)
        case .signal: Theme.accent
        case .result: Theme.positive
        case .falseStart: Theme.negative
        }
    }
}
