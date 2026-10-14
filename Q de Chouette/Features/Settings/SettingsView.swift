// SettingsView.swift
// Réglages des règles (appliqués aux nouvelles parties) et du confort de jeu.
// Par défaut : règles traditionnelles. Les variantes allégées sont proposées à part.

import SwiftUI
import ChouetteRules

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var confirmReset = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Text("Les règles choisies ici s'appliquent aux nouvelles parties. Une partie en cours garde ses règles.")
                    .font(.callout)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .listRowBackground(Theme.surface)

            Section("Fin de partie") {
                Stepper(value: $settings.rules.targetScore, in: 21...999) {
                    LabeledContent("Score à atteindre") { Text("\(settings.rules.targetScore)").monospacedDigit() }
                }
                Picker("Victoire", selection: $settings.rules.victoryMode) {
                    Text("Atteindre ou dépasser").tag(RuleSet.VictoryMode.reachOrExceed)
                    Text("Score exact").tag(RuleSet.VictoryMode.exact)
                }
                Toggle("Scores négatifs autorisés", isOn: $settings.rules.allowNegativeScores)
            }
            .listRowBackground(Theme.surface)

            Section {
                Picker("Lancer 1-2-3", selection: $settings.rules.oneTwoThree) {
                    Text("Velute puis suite").tag(RuleSet.OneTwoThreeRule.veluteAndSuite)
                    Text("Velute seule").tag(RuleSet.OneTwoThreeRule.veluteOnly)
                    Text("Suite seule").tag(RuleSet.OneTwoThreeRule.suiteOnly)
                }
                Toggle("Le lanceur garde sa chouette sur une chouette-velute",
                       isOn: $settings.rules.chouetteVeluteRollerKeepsChouette)
                Stepper(value: $settings.rules.suitePenalty, in: 1...50) {
                    LabeledContent("Pénalité de suite") { Text("\(settings.rules.suitePenalty)").monospacedDigit() }
                }
            } header: {
                Text("Règles de base")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle(isOn: Binding(
                    get: { settings.rules.usesLightVariants },
                    set: { light in
                        if light {
                            settings.rules.applyLightVariants()
                        } else {
                            settings.rules.sirotage.failure = .loseChouette
                            settings.rules.suiteLosers = .allLate
                            settings.rules.grelottine.stakeLimitedByScores = false
                        }
                    })) {
                    Text("Tout alléger").font(.headline)
                }
                Toggle("Sirotage raté sans pénalité", isOn: Binding(
                    get: { settings.rules.sirotage.failure == .scoreNothing },
                    set: { settings.rules.sirotage.failure = $0 ? .scoreNothing : .loseChouette }))
                Toggle("Suite : seul le plus lent des joueurs ayant tapé perd", isOn: Binding(
                    get: { settings.rules.suiteLosers == .lastTapperOnly },
                    set: { settings.rules.suiteLosers = $0 ? .lastTapperOnly : .allLate }))
                Toggle("Grelottine : mise limitée aux scores", isOn: $settings.rules.grelottine.stakeLimitedByScores)
            } header: {
                Text("Variantes allégées")
            } footer: {
                Text("Désactivées, ce sont les règles traditionnelles qui s'appliquent.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Sirotage", isOn: $settings.rules.sirotage.isEnabled)
                if settings.rules.sirotage.isEnabled {
                    Toggle("Paris des autres joueurs", isOn: $settings.rules.sirotage.betsEnabled)
                    if settings.rules.sirotage.betsEnabled {
                        numberStepper("Gain d'un pari juste", value: $settings.rules.sirotage.betReward, range: 1...100)
                    }
                }
                Toggle("Bévue", isOn: $settings.rules.bevue.isEnabled)
                if settings.rules.bevue.isEnabled {
                    numberStepper("Pénalité de faux départ", value: $settings.rules.bevue.penalty, range: 1...50)
                }
                Toggle("Civet", isOn: $settings.rules.civet.isEnabled)
                if settings.rules.civet.isEnabled {
                    numberStepper("Civets par joueur", value: $settings.rules.civet.perPlayer, range: 1...5)
                    numberStepper("Mise maximale", value: $settings.rules.civet.maxStake, range: 1...343)
                }
                Toggle("Grelottine", isOn: $settings.rules.grelottine.isEnabled)
                if settings.rules.grelottine.isEnabled {
                    numberStepper("Mise maximale", value: $settings.rules.grelottine.maxStake, range: 1...343)
                }
            } header: {
                Text("Règles avancées")
            } footer: {
                Text("Sirotage : après une chouette, relancer le dernier dé pour tenter le cul de chouette. Bévue : taper avant le signal coûte des points. Civet : parier sur son prochain lancer. Grelottine : gagnée sur un néant, permet de défier un joueur.")
            }
            .listRowBackground(Theme.surface)

            Section("Barème") {
                numberStepper("Chouette : multiplicateur", value: $settings.rules.chouetteMultiplier, range: 1...5)
                numberStepper("Velute : multiplicateur", value: $settings.rules.veluteMultiplier, range: 1...5)
                numberStepper("Cul de chouette : base", value: $settings.rules.culDeChouetteBase, range: 0...100)
                numberStepper("Cul de chouette : par point", value: $settings.rules.culDeChouetteStep, range: 0...50)
            }
            .listRowBackground(Theme.surface)

            Section("Confort") {
                Toggle("Vibrations", isOn: $settings.hapticsEnabled)
                Toggle("Bruitages", isOn: $settings.soundEffectsEnabled)
                Toggle("Musique et ambiance de taverne", isOn: $settings.musicEnabled)
            }
            .listRowBackground(Theme.surface)

            Section {
                Button("Rétablir les règles traditionnelles", role: .destructive) { confirmReset = true }
                    .disabled(settings.rules == .standard)
            }
            .listRowBackground(Theme.surface)
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .themedBackground()
        .navigationTitle("Réglages")
        .confirmationDialog("Rétablir toutes les règles par défaut ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Rétablir", role: .destructive) { settings.rules = .standard }
        }
    }

    private func numberStepper(_ title: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            LabeledContent(title) { Text("\(value.wrappedValue)").monospacedDigit() }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
}
