// RulesComponents.swift
// Briques interactives du livre de règles : dés animés, fiche de figure,
// testeur de lancer, table des points.

import SwiftUI
import ChouetteRules

// MARK: - Dés animés

/// Trois dés qui roulent puis s'arrêtent sur le lancer donné.
/// Relance l'animation à chaque changement de lancer. Sans animation si « Réduire les animations ».
struct AnimatedDice: View {
    let roll: Roll
    var size: CGFloat = 56
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var faces: [Int] = [1, 1, 1]
    @State private var rolling = false

    var body: some View {
        HStack(spacing: size * 0.22) {
            ForEach(0..<3, id: \.self) { index in
                DieView(value: faces[index], size: size)
                    .rotationEffect(.degrees(rolling ? Double(faces[index]) * 53 : 0))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Dés : \(roll.dice.map(\.description).joined(separator: ", "))"))
        .task(id: roll) {
            guard !reduceMotion else {
                faces = roll.dice.map(\.value)
                return
            }
            rolling = true
            for step in 0..<9 {
                faces = (0..<3).map { _ in Int.random(in: 1...6) }
                try? await Task.sleep(for: .milliseconds(50 + step * 12))
            }
            withAnimation(.spring(duration: 0.25)) {
                rolling = false
                faces = roll.dice.map(\.value)
            }
        }
    }
}

// MARK: - Fiche d'une figure

struct FigureCard: View {
    let kind: FigureKind
    let rules: RuleSet
    @State private var exampleIndex = Int.random(in: 0..<1000)

    private var examples: [Roll] { kind.exampleRolls(rules: rules) }

    var body: some View {
        let example = examples.isEmpty ? nil : examples[exampleIndex % examples.count]
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(kind.name).font(Theme.heading(.title3))
            } icon: {
                Image(systemName: kind.symbolName).foregroundStyle(Theme.accent)
            }
            .accessibilityAddTraits(.isHeader)

            Text(kind.rule(rules))
                .fixedSize(horizontal: false, vertical: true)

            if let example {
                let figure = RollAnalyzer.analyze(example, rules: rules).figures[0]
                VStack(spacing: 10) {
                    AnimatedDice(roll: example)
                    Text(exampleCaption(figure))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                if examples.count > 1 {
                    Button {
                        exampleIndex = (exampleIndex + Int.random(in: 1..<examples.count)) % examples.count
                    } label: {
                        Label("Autre exemple", systemImage: "dice")
                    }
                    .buttonStyle(.secondary)
                }
            }
        }
        .parchmentCard()
    }

    private func exampleCaption(_ figure: Figure) -> String {
        let breakdown = RollAnalyzer.breakdown(for: figure, rules: rules)
        switch figure {
        case .neant: return String(localized: "\(figure.name) : 0 point")
        case .suite: return String(localized: "\(figure.name) : le plus lent perd \(rules.suitePenalty) points")
        case .chouetteVelute: return String(localized: "\(figure.name) : \(breakdown.formula) pour le plus rapide")
        default: return String(localized: "\(figure.name) : \(breakdown.formula) \(breakdown.total.pointsUnit)")
        }
    }
}

// MARK: - Testeur de lancer

/// Choisissez trois valeurs : l'app annonce la figure et les points.
/// Pratique pour apprendre… et pour trancher les disputes à table.
struct RollTester: View {
    let rules: RuleSet
    @State private var values = [4, 4, 1]

    var body: some View {
        let roll = Roll(values[0], values[1], values[2])
        let analysis = RollAnalyzer.analyze(roll, rules: rules)
        VStack(alignment: .leading, spacing: 14) {
            Label("Testeur de lancer", systemImage: "wand.and.stars")
                .font(Theme.heading(.title3))
                .accessibilityAddTraits(.isHeader)
            Text("Touchez un dé pour changer sa valeur.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)

            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    Button {
                        values[index] = values[index] % 6 + 1
                    } label: {
                        DieView(value: values[index], size: 60)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Dé \(index + 1) : \(values[index])"))
                    .accessibilityHint(Text("Augmente la valeur"))
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: values[index] = values[index] % 6 + 1
                        case .decrement: values[index] = (values[index] + 4) % 6 + 1
                        @unknown default: break
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(analysis.figures.enumerated()), id: \.offset) { _, figure in
                    let breakdown = RollAnalyzer.breakdown(for: figure, rules: rules)
                    HStack(alignment: .firstTextBaseline) {
                        Text(figure.name).font(.headline)
                        Spacer()
                        Text(breakdown.formula)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(breakdown.total < 0 ? Theme.negative : Theme.ink)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(12)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 10))
        }
        .parchmentCard()
    }
}

// MARK: - Table des points

struct PointsTable: View {
    let rules: RuleSet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Table des points", systemImage: "tablecells")
                .font(Theme.heading(.title3))
                .accessibilityAddTraits(.isHeader)
            Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Dé").gridColumnAlignment(.leading)
                    Text("Chouette")
                    Text("Velute")
                    Text("Cul")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                Divider()
                ForEach(1...6, id: \.self) { v in
                    GridRow {
                        DieView(value: v, size: 24).gridColumnAlignment(.leading)
                        Text("\(RollAnalyzer.chouettePoints(v, rules: rules))")
                        Text(v >= 3 ? "\(RollAnalyzer.velutePoints(v, rules: rules))" : "—")
                        Text("\(RollAnalyzer.culDeChouettePoints(v, rules: rules))")
                    }
                    .font(.body.monospacedDigit())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(rowLabel(v))
                }
            }
            Text("La velute se lit sur le plus grand dé : il vaut au moins 3 (1 + 2).")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
        }
        .parchmentCard()
    }

    private func rowLabel(_ v: Int) -> Text {
        let chouette = RollAnalyzer.chouettePoints(v, rules: rules)
        let cul = RollAnalyzer.culDeChouettePoints(v, rules: rules)
        if v >= 3 {
            return Text("Dé \(v) : chouette \(chouette), velute \(RollAnalyzer.velutePoints(v, rules: rules)), cul de chouette \(cul)")
        }
        return Text("Dé \(v) : chouette \(chouette), cul de chouette \(cul)")
    }
}
