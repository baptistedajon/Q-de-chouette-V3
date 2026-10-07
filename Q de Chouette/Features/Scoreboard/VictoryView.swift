// VictoryView.swift
// Écran de victoire : vainqueur, classement final, revanche.

import SwiftUI
import ChouetteRules

struct VictoryView: View {
    let model: GameViewModel
    let onRematch: () -> Void
    let onNewGame: () -> Void
    let onHome: () -> Void
    let onClose: () -> Void

    @State private var showScores = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let engine = model.engine
        ZStack {
            Theme.background.ignoresSafeArea()
            if !reduceMotion {
                ConfettiView().ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
            }
            ScrollView {
                VStack(spacing: 24) {
                    if let winner = engine.winner {
                        VStack(spacing: 12) {
                            Text("🏆").font(.system(size: 72)).accessibilityHidden(true)
                            AvatarView(avatar: model.avatar(of: winner), size: 96)
                                .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                            Text("Victoire de \(model.name(of: winner)) !")
                                .font(Theme.title())
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                            Text("\(engine.players[winner].score) points en \(engine.history.count) tours")
                                .font(.headline)
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }

                    VStack(spacing: 8) {
                        ForEach(Array(engine.players.sorted { $0.score > $1.score }.enumerated()), id: \.element.id) { index, player in
                            HStack {
                                Text(medal(index)).frame(width: 30)
                                AvatarView(avatar: model.avatar(of: player.id), size: 28)
                                Text(player.name)
                                Spacer()
                                Text("\(player.score)").monospacedDigit().bold()
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .parchmentCard()

                    VStack(spacing: 12) {
                        Button(action: onRematch) { Label("Revanche !", systemImage: "arrow.clockwise") }
                            .buttonStyle(.primary)
                        Button { showScores = true } label: { Label("Détail des scores", systemImage: "list.number") }
                            .buttonStyle(.secondary)
                        Button(action: onNewGame) { Label("Nouvelle partie", systemImage: "person.3") }
                            .buttonStyle(.secondary)
                        Button(action: onHome) { Label("Accueil", systemImage: "house") }
                            .buttonStyle(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Theme.ink)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .accessibilityLabel(Text("Revenir à la table"))
            .padding()
        }
        .sheet(isPresented: $showScores) {
            ScoreboardView(engine: engine, avatars: model.avatars)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.5)) { appeared = true }
        }
    }

    private func medal(_ index: Int) -> String {
        switch index {
        case 0: "🥇"
        case 1: "🥈"
        case 2: "🥉"
        default: "\(index + 1)."
        }
    }
}

/// Pluie de confettis aux couleurs héraldiques, dessinée avec Canvas.
struct ConfettiView: View {
    private struct Piece {
        let x: Double, speed: Double, drift: Double, spin: Double, size: Double, color: Color, delay: Double
    }

    private static let colors: [Color] = [Theme.gold, Theme.accent, Color(light: 0x2C4A8A, dark: 0x4A6CB3),
                                          Color(light: 0x2F6B3A, dark: 0x4C8E57), .white]
    @State private var pieces: [Piece] = (0..<90).map { _ in
        Piece(x: .random(in: 0...1), speed: .random(in: 0.12...0.3), drift: .random(in: -0.05...0.05),
              spin: .random(in: 1...5), size: .random(in: 6...12),
              color: colors.randomElement()!, delay: .random(in: 0...3))
    }
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let progress = (t - piece.delay) * piece.speed
                    guard progress > 0 else { continue }
                    let y = progress.truncatingRemainder(dividingBy: 1.2) - 0.1
                    let x = piece.x + sin(t * piece.spin) * piece.drift
                    var copy = context
                    copy.translateBy(x: x * size.width, y: y * size.height)
                    copy.rotate(by: .radians(t * piece.spin))
                    copy.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)),
                              with: .color(piece.color))
                }
            }
        }
    }
}
