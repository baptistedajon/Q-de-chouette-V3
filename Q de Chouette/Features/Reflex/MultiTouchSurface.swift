// MultiTouchSurface.swift
// Surface transparente qui capte tous les doigts posés en même temps,
// avec l'horodatage système précis de chaque toucher (UITouch.timestamp).
// SwiftUI ne garantit pas la reconnaissance simultanée de taps sur des vues voisines ;
// UIKit, si. On passe par un gesture recognizer plutôt que par `touchesBegan` sur la vue :
// les recognizers de SwiftUI interceptent sinon les touchers avant qu'ils n'atteignent la vue.

import SwiftUI
import UIKit

struct MultiTouchSurface: UIViewRepresentable {
    /// Point dans le repère de la surface, et instant en secondes depuis le démarrage
    /// (même horloge que `ProcessInfo.processInfo.systemUptime`).
    var onTouch: (CGPoint, TimeInterval) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        let recognizer = TouchDownRecognizer()
        recognizer.onTouch = onTouch
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        for case let recognizer as TouchDownRecognizer in view.gestureRecognizers ?? [] {
            recognizer.onTouch = onTouch
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Laisse notre recognizer fonctionner en même temps que ceux de SwiftUI.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }

    /// Signale chaque doigt posé, dès son arrivée, sans jamais bloquer les autres gestes.
    final class TouchDownRecognizer: UIGestureRecognizer {
        var onTouch: ((CGPoint, TimeInterval) -> Void)?

        override init(target: Any?, action: Selector?) {
            super.init(target: target, action: action)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }

        convenience init() { self.init(target: nil, action: nil) }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let view else { return }
            for touch in touches {
                onTouch?(touch.location(in: view), touch.timestamp)
            }
            if state == .possible { state = .began }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            if allTouchesFinished(event) { state = .ended }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            if allTouchesFinished(event) { state = .cancelled }
        }

        private func allTouchesFinished(_ event: UIEvent) -> Bool {
            (event.allTouches ?? []).allSatisfy { $0.phase == .ended || $0.phase == .cancelled }
        }
    }
}

/// Découpage de l'écran en zones de tap, une par joueur.
/// Les zones du haut sont retournées pour les joueurs assis en face.
enum ReflexLayout {
    struct Zone {
        let rect: CGRect
        let isRotated: Bool
    }

    static func zones(count: Int, in size: CGSize, spacing: CGFloat = 8) -> [Zone] {
        guard count > 0 else { return [] }
        let columns = count <= 3 ? 1 : 2
        let rows = (count + columns - 1) / columns
        let height = (size.height - spacing * CGFloat(rows + 1)) / CGFloat(rows)
        let fullWidth = size.width - spacing * 2
        let halfWidth = (size.width - spacing * CGFloat(columns + 1)) / CGFloat(columns)

        return (0..<count).map { index in
            let row = index / columns
            let column = index % columns
            let isAloneOnRow = columns == 2 && row == rows - 1 && count % 2 == 1
            let width = (columns == 1 || isAloneOnRow) ? fullWidth : halfWidth
            let x = spacing + CGFloat(isAloneOnRow ? 0 : column) * (halfWidth + spacing)
            let y = spacing + CGFloat(row) * (height + spacing)
            return Zone(rect: CGRect(x: x, y: y, width: width, height: height),
                        isRotated: rows >= 2 && row < rows / 2)
        }
    }
}
