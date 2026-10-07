// Theme.swift
// Palette « taverne » (parchemin, bois, encre, vin, or) adaptée au mode sombre,
// et typographie. Tout le style passe par ici pour pouvoir être changé d'un coup.

import SwiftUI
import UIKit

enum Theme {

    // MARK: Couleurs

    /// Fond principal : parchemin clair / bois sombre.
    static let background = Color(light: 0xF3E7CF, dark: 0x1C1511)
    /// Cartes et panneaux.
    static let surface = Color(light: 0xFBF4E4, dark: 0x2A2019)
    /// Texte principal.
    static let ink = Color(light: 0x2B1D12, dark: 0xF1E4CB)
    /// Texte secondaire.
    static let inkSecondary = Color(light: 0x6B5643, dark: 0xB8A68C)
    /// Couleur d'action : rouge vin.
    static let accent = Color(light: 0x8E2A23, dark: 0xE0675C)
    /// Or : mises en valeur, joueur courant, victoire.
    static let gold = Color(light: 0x9C6F12, dark: 0xE2B653)
    /// Bois : bordures et séparateurs.
    static let wood = Color(light: 0x7A5434, dark: 0x6E4E33)
    static let positive = Color(light: 0x2F6B2F, dark: 0x7BC77B)
    static let negative = Color(light: 0xA3261E, dark: 0xF07B70)

    // MARK: Typographie
    //
    // Police serif du système (Dynamic Type complet) en attendant la police
    // médiévale sous licence OFL prévue en phase 6 : seul ce bloc sera à changer.

    static func title(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.bold)
    }

    static func heading(_ style: Font.TextStyle = .title3) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    static let cornerRadius: CGFloat = 14
}

extension Color {
    /// Couleur qui s'adapte au mode clair / sombre, à partir de deux valeurs hexadécimales.
    /// `nonisolated` : SwiftUI résout les couleurs sur son fil de rendu, pas sur le fil principal.
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

// MARK: - Styles réutilisables

/// Bouton principal : rouge vin, texte clair, pleine largeur.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.heading(.title3))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal)
            .foregroundStyle(Color.white)
            .background(Theme.accent.opacity(isEnabled ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Bouton secondaire : contour bois sur parchemin.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal)
            .foregroundStyle(Theme.ink)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.wood, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Panneau façon carte de parchemin.
struct ParchmentCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.wood.opacity(0.35)))
    }
}

extension View {
    func parchmentCard() -> some View { modifier(ParchmentCard()) }

    /// Fond parchemin plein écran pour les écrans principaux.
    func themedBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
    }
}
