// Table3DView.swift
// Vue SwiftUI de la table 3D : lancer par bouton, par geste de glissé ou en secouant le téléphone.

import SwiftUI
import RealityKit
import CoreMotion
import UIKit
import ChouetteRules

struct Table3DView: View {
    let model: GameViewModel

    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var table = DiceTable3D()
    @State private var subscriptions: [EventSubscription] = []
    @State private var shake = ShakeDetector()
    @State private var haptics = ImpactHaptics()

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            content.add(table.root)
            subscriptions.append(content.subscribe(to: SceneEvents.Update.self) { event in
                table.update(deltaTime: event.deltaTime)
            })
            subscriptions.append(table.subscribeToCollisions(in: content))
        }
        .background(Color(light: 0x1C1511, dark: 0x0E0A08))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.wood, lineWidth: 6))
        .overlay(alignment: .bottom) { hint }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let dx = Float(value.predictedEndTranslation.width)
                    let dy = Float(-value.predictedEndTranslation.height)
                    throwDice(direction: [dx, dy], strength: min(hypot(dx, dy) / 700, 1))
                }
        )
        .onChange(of: model.throwRequest) { throwDice(direction: [0, 1], strength: 0.6) }
        .onChange(of: model.restoreTick) { table.showResting(faces: model.diceFaces) }
        .onChange(of: reduceMotion, initial: true) { _, value in table.reduceMotion = value }
        .onAppear {
            table.showResting(faces: model.diceFaces)
            table.onImpact = { [haptics] intensity in
                guard settings.hapticsEnabled else { return }
                haptics.impact(intensity: intensity)
                model.playImpactSound(intensity: intensity)
            }
            shake.start { throwDice(direction: [Float.random(in: -0.3...0.3), 1], strength: 0.9) }
        }
        .onDisappear { shake.stop() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(model.expectedRoll != nil ? Text("Lance les dés") : Text(""))
        .accessibilityAction { throwDice(direction: [0, 1], strength: 0.6) }
    }

    @ViewBuilder
    private var hint: some View {
        if model.expectedRoll != nil && !model.isRolling {
            Label("Secouez le téléphone ou lancez d'un geste vers le haut", systemImage: "hand.draw")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(.bottom, 14)
                .accessibilityHidden(true)
        }
    }

    private var accessibilityText: Text {
        if model.isRolling { return Text("Les dés roulent sur la table") }
        let values = model.diceFaces.compactMap { $0 }
        if values.count < 3 { return Text("Table de jeu en 3D, dés pas encore lancés") }
        return Text("Table de jeu en 3D. Dés : \(values.map(String.init).joined(separator: ", "))")
    }

    private func throwDice(direction: SIMD2<Float>, strength: Float) {
        guard let purpose = model.beginPhysicalThrow() else { return }
        model.playThrowSound()
        table.throwDice(indices: model.targetIndices(for: purpose), direction: direction, strength: strength) { faces in
            model.finishPhysicalThrow(faces, purpose: purpose)
        }
    }
}

/// Détecte une secousse franche du téléphone (accéléromètre).
@MainActor
final class ShakeDetector {
    private let manager = CMMotionManager()
    private var lastShake = Date.distantPast

    func start(threshold: Double = 2.2, onShake: @escaping @MainActor () -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 50
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let a = motion?.userAcceleration else { return }
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            MainActor.assumeIsolated {
                guard let self, magnitude > threshold, Date.now.timeIntervalSince(self.lastShake) > 1.5 else { return }
                self.lastShake = .now
                onShake()
            }
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}

/// Vibrations des chocs des dés, dosées selon la violence de l'impact.
@MainActor
final class ImpactHaptics {
    private let generator = UIImpactFeedbackGenerator(style: .rigid)

    func impact(intensity: Float) {
        generator.impactOccurred(intensity: CGFloat(max(0.2, min(intensity, 1))))
    }
}
