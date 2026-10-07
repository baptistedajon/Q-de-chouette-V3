// DieView.swift
// Dé 2D dessiné en code (ivoire, points d'encre).

import SwiftUI

struct DieView: View {
    /// `nil` : dé pas encore lancé (face vierge).
    let value: Int?
    var size: CGFloat = 72
    /// Met le dé en valeur (ex. dé relancé pendant un sirotage).
    var isHighlighted = false

    var body: some View {
        let corner = size * 0.2
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(colors: [Color(light: 0xFFFBF0, dark: 0xF4EBD8),
                                              Color(light: 0xE9DCC0, dark: 0xD8C8A6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(isHighlighted ? Theme.gold : Color.black.opacity(0.25),
                              lineWidth: isHighlighted ? size * 0.05 : 1)
            if let value {
                pips(for: value)
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.4, weight: .bold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.25))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.3), radius: size * 0.06, x: 0, y: size * 0.04)
        .accessibilityElement()
        .accessibilityLabel(value.map { Text("Dé : \($0)") } ?? Text("Dé non lancé"))
    }

    /// Positions des points sur une grille 3×3 (colonne, ligne).
    private static let layouts: [Int: [(Int, Int)]] = [
        1: [(1, 1)],
        2: [(0, 0), (2, 2)],
        3: [(0, 0), (1, 1), (2, 2)],
        4: [(0, 0), (2, 0), (0, 2), (2, 2)],
        5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
        6: [(0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)],
    ]

    private func pips(for value: Int) -> some View {
        let pip = size * 0.17
        let step = size * 0.27
        return ZStack {
            ForEach(Array((Self.layouts[value] ?? []).enumerated()), id: \.offset) { _, position in
                Circle()
                    .fill(value == 1 ? Theme.accent : Color(white: 0.12))
                    .frame(width: value == 1 ? pip * 1.35 : pip, height: value == 1 ? pip * 1.35 : pip)
                    .offset(x: CGFloat(position.0 - 1) * step, y: CGFloat(position.1 - 1) * step)
            }
        }
    }
}

#Preview {
    HStack {
        ForEach(1...6, id: \.self) { DieView(value: $0, size: 50) }
        DieView(value: nil, size: 50)
    }
    .padding()
}
