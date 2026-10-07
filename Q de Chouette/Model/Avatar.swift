// Avatar.swift
// Avatars médiévaux : un emoji sur un écu de couleur.
// ⚠︎ ASSET PROVISOIRE — à remplacer par des illustrations originales (voir ASSETS.md).

import SwiftUI

enum Avatar: String, CaseIterable, Codable, Identifiable {
    case king, queen, wizard, elf, knight, archer, dragon, owl, jester, bard, innkeeper, troll

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .king: "🤴"
        case .queen: "👸"
        case .wizard: "🧙"
        case .elf: "🧝"
        case .knight: "⚔️"
        case .archer: "🏹"
        case .dragon: "🐉"
        case .owl: "🦉"
        case .jester: "🃏"
        case .bard: "🪕"
        case .innkeeper: "🍺"
        case .troll: "🧌"
        }
    }

    /// Couleur héraldique de l'écu.
    var color: Color {
        switch self {
        case .king, .dragon, .innkeeper: Color(light: 0x9E2B25, dark: 0xB8423A)   // gueules
        case .queen, .bard, .owl: Color(light: 0x2C4A8A, dark: 0x4A6CB3)          // azur
        case .wizard, .jester: Color(light: 0x5E3A7A, dark: 0x7E57A0)             // pourpre
        case .elf, .archer, .troll: Color(light: 0x2F6B3A, dark: 0x4C8E57)        // sinople
        case .knight: Color(light: 0x2D2D2D, dark: 0x555555)                      // sable
        }
    }

    var name: LocalizedStringResource {
        switch self {
        case .king: "Roi"
        case .queen: "Reine"
        case .wizard: "Enchanteur"
        case .elf: "Elfe"
        case .knight: "Chevalier"
        case .archer: "Archère"
        case .dragon: "Dragon"
        case .owl: "Chouette"
        case .jester: "Bouffon"
        case .bard: "Barde"
        case .innkeeper: "Tavernier"
        case .troll: "Troll"
        }
    }

    /// Avatar par défaut pour le n-ième joueur, pour que chacun ait un écu différent.
    static func defaultFor(index: Int) -> Avatar {
        allCases[index % allCases.count]
    }
}

/// Forme d'écu héraldique.
nonisolated struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h = rect.height
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.45))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.minY + h * 0.85))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.45),
                          control: CGPoint(x: rect.minX, y: rect.minY + h * 0.85))
        path.closeSubpath()
        return path
    }
}

struct AvatarView: View {
    let avatar: Avatar
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            ShieldShape().fill(avatar.color.gradient)
            ShieldShape().stroke(Theme.gold, lineWidth: max(1.5, size / 22))
            Text(avatar.emoji)
                .font(.system(size: size * 0.48))
                .offset(y: -size * 0.06)
        }
        .frame(width: size, height: size * 1.12)
        .accessibilityHidden(true)
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(), count: 4)) {
        ForEach(Avatar.allCases) { AvatarView(avatar: $0, size: 60) }
    }
    .padding()
}
