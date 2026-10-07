// RulesView.swift
// Livre de règles illustré et interactif. Les points et options affichés suivent
// les règles en vigueur (réglages, ou règles de la partie en cours).

import SwiftUI
import ChouetteRules

struct RulesView: View {
    /// Règles à présenter. `nil` : les réglages actuels.
    var rules: RuleSet?
    /// Lance une partie guidée (proposé depuis l'accueil).
    var onStartGuidedGame: (() -> Void)?

    @Environment(AppSettings.self) private var settings
    @State private var practice: ReflexKind?

    private var currentRules: RuleSet { rules ?? settings.rules }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                goal
                if let onStartGuidedGame {
                    Button(action: onStartGuidedGame) {
                        Label("Jouer une première partie guidée", systemImage: "graduationcap.fill")
                    }
                    .buttonStyle(.primary)
                }

                sectionTitle("Les combinaisons")
                ForEach(FigureKind.teachingOrder, id: \.self) { kind in
                    FigureCard(kind: kind, rules: currentRules)
                }

                sectionTitle("Les cris")
                shouts

                sectionTitle("Pour s'entraîner")
                RollTester(rules: currentRules)
                PointsTable(rules: currentRules)

                sectionTitle("Règles avancées")
                advancedRules
            }
            .padding()
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .themedBackground()
        .navigationTitle("Règles du jeu")
        .fullScreenCover(item: $practice) { kind in
            ReflexPracticeView(kind: kind)
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(Theme.heading(.title2))
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private var goal: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Le but du jeu", systemImage: "flag.checkered")
                .font(Theme.heading(.title3))
                .accessibilityAddTraits(.isHeader)
            Text("De 2 à 8 joueurs, chacun son tour, on lance trois dés. Certaines combinaisons rapportent des points, d'autres en font perdre.")
            Text(currentRules.victoryMode == .exact
                 ? String(localized: "Le premier qui atteint exactement \(currentRules.targetScore) points gagne la partie.")
                 : String(localized: "Le premier qui atteint \(currentRules.targetScore) points gagne la partie."))
                .font(.headline)
            Text("Pas de dés ? L'app les lance pour vous. Vous avez les vôtres ? Choisissez « Mes propres dés » et saisissez simplement les valeurs.")
                .foregroundStyle(Theme.inkSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .parchmentCard()
    }

    private var shouts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deux combinaisons font jouer toute la table. L'app affiche une zone par joueur : au signal, chacun tape la sienne en criant la phrase.")
                .fixedSize(horizontal: false, vertical: true)
            shoutRow(.pasMouLeCaillou, detail: String(localized: "Sur une chouette-velute. Le plus rapide gagne la velute."))
            shoutRow(.grelotteCaPicote, detail: String(localized: "Sur une suite. Le plus lent perd \(currentRules.suitePenalty) points."))
            if currentRules.bevue.isEnabled {
                Text("Bévue activée : taper avant le signal coûte \(currentRules.bevue.penalty) points.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .parchmentCard()
    }

    private func shoutRow(_ kind: ReflexKind, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("« \(kind.phrase) »").font(Theme.heading(.headline))
            Text(detail).font(.subheadline)
            Button { practice = kind } label: {
                Label("S'entraîner", systemImage: "hand.tap")
            }
            .buttonStyle(.secondary)
        }
    }

    private var advancedRules: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optionnelles, à activer dans les réglages pour pimenter les parties.")
                .foregroundStyle(Theme.inkSecondary)
            advancedRule("Sirotage", enabled: currentRules.sirotage.isEnabled,
                         text: currentRules.sirotage.failure == .loseChouette
                         ? String(localized: "Après une chouette, le lanceur peut relancer le dernier dé en annonçant le nom de sa chouette (Linotte, Alouette, Fauvette, Mouette, Bergeronnette ou Chouette, de 1 à 6). S'il obtient la même valeur, il marque un cul de chouette ; sinon, il perd les points de sa chouette. Les autres joueurs peuvent parier sur le résultat.")
                         : String(localized: "Après une chouette, le lanceur peut relancer le dernier dé en annonçant le nom de sa chouette (Linotte, Alouette, Fauvette, Mouette, Bergeronnette ou Chouette, de 1 à 6). S'il obtient la même valeur, il marque un cul de chouette ; sinon, il ne marque rien. Les autres joueurs peuvent parier sur le résultat."))
            advancedRule("Bévue", enabled: currentRules.bevue.isEnabled,
                         text: String(localized: "Taper avant le signal pendant un cri coûte \(currentRules.bevue.penalty) points, et le tap ne compte pas."))
            advancedRule("Civet", enabled: currentRules.civet.isEnabled,
                         text: String(localized: "Avant de lancer, un joueur peut parier jusqu'à \(currentRules.civet.maxStake) points sur la figure qu'il va obtenir. Gagné, il empoche la mise ; perdu, il la perd. Une fois par partie."))
            advancedRule("Grelottine", enabled: currentRules.grelottine.isEnabled,
                         text: String(localized: "Un néant donne une grelottine. Au début d'un tour, son détenteur peut défier un autre joueur : celui-ci lance les dés et doit obtenir la figure choisie. Réussi, il prend la mise au défieur ; raté, c'est l'inverse."))
        }
        .parchmentCard()
    }

    private func advancedRule(_ title: LocalizedStringKey, enabled: Bool, text: String) -> some View {
        DisclosureGroup {
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        } label: {
            HStack {
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                Spacer()
                Text(enabled ? "Activée" : "Désactivée")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(enabled ? Theme.positive : Theme.inkSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack { RulesView() }
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
}
