import Testing
@testable import ChouetteRules

/// Implémentation de référence volontairement naïve (toutes les permutations),
/// pour vérifier l'analyseur sur les 216 lancers.
private func referenceFigures(_ roll: Roll, rules: RuleSet) -> [Figure] {
    let d = roll.dice.map(\.value)
    let perms = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]].map { $0.map { d[$0] } }

    if d[0] == d[1] && d[1] == d[2] { return [.culDeChouette(value: d[0])] }
    // Paire (x, x) et troisième dé y.
    if let p = perms.first(where: { $0[0] == $0[1] }) {
        return p[0] + p[1] == p[2]
            ? [.chouetteVelute(pairValue: p[0], veluteValue: p[2])]
            : [.chouette(value: p[0])]
    }
    let velute = perms.first { $0[0] + $0[1] == $0[2] }.map { Figure.velute(value: $0[2]) }
    let suite = perms.first { $0[1] == $0[0] + 1 && $0[2] == $0[1] + 1 }.map { Figure.suite(lowest: $0[0]) }
    switch (velute, suite) {
    case let (v?, s?):
        switch rules.oneTwoThree {
        case .veluteAndSuite: return [v, s]
        case .veluteOnly: return [v]
        case .suiteOnly: return [s]
        }
    case let (v?, nil): return [v]
    case let (nil, s?): return [s]
    case (nil, nil): return [.neant]
    }
}

@Suite("Reconnaissance des figures")
struct RollAnalyzerTests {

    @Test("Les 216 lancers correspondent à l'implémentation de référence",
          arguments: RuleSet.OneTwoThreeRule.allCases)
    func exhaustiveAgainstReference(mode: RuleSet.OneTwoThreeRule) {
        var rules = RuleSet()
        rules.oneTwoThree = mode
        for roll in Roll.allRolls {
            #expect(RollAnalyzer.analyze(roll, rules: rules).figures == referenceFigures(roll, rules: rules),
                    "Lancer \(roll)")
        }
    }

    @Test("Répartition des 216 lancers")
    func distribution() {
        var counts: [FigureKind: Int] = [:]
        for roll in Roll.allRolls {
            for kind in RollAnalyzer.analyze(roll).kinds { counts[kind, default: 0] += 1 }
        }
        #expect(Roll.allRolls.count == 216)
        #expect(counts[.culDeChouette] == 6)
        #expect(counts[.chouetteVelute] == 9)   // 1-1-2, 2-2-4, 3-3-6 × 3 positions
        #expect(counts[.chouette] == 81)
        #expect(counts[.velute] == 36)          // 6 combinaisons × 6 ordres
        #expect(counts[.suite] == 24)           // 4 suites × 6 ordres
        #expect(counts[.neant] == 66)
    }

    @Test("L'ordre des dés n'a pas d'importance")
    func orderIndependence() {
        for roll in Roll.allRolls {
            let sorted = roll.sortedValues
            let canonical = Roll(sorted[0], sorted[1], sorted[2])
            #expect(RollAnalyzer.analyze(roll).figures == RollAnalyzer.analyze(canonical).figures)
        }
    }

    @Test("Exemples de l'énoncé")
    func examples() {
        #expect(RollAnalyzer.analyze(Roll(4, 4, 1)).figures == [.chouette(value: 4)])
        #expect(RollAnalyzer.analyze(Roll(3, 1, 2)).figures == [.velute(value: 3), .suite(lowest: 1)])
        #expect(RollAnalyzer.analyze(Roll(2, 4, 2)).figures == [.chouetteVelute(pairValue: 2, veluteValue: 4)])
        #expect(RollAnalyzer.analyze(Roll(5, 5, 5)).figures == [.culDeChouette(value: 5)])
        #expect(RollAnalyzer.analyze(Roll(6, 4, 5)).figures == [.suite(lowest: 4)])
        #expect(RollAnalyzer.analyze(Roll(1, 3, 6)).figures == [.neant])
        #expect(RollAnalyzer.analyze(Roll(6, 6, 3)).figures == [.chouette(value: 6)]) // 3+3≠6 : pas de velute
    }

    @Test("1-2-3 est la seule velute qui soit aussi une suite")
    func onlyOneTwoThreeIsBoth() {
        let both = Roll.allRolls.filter {
            let k = RollAnalyzer.analyze($0).kinds
            return k.contains(.velute) && k.contains(.suite)
        }
        #expect(both.allSatisfy { $0.sortedValues == [1, 2, 3] })
        #expect(both.count == 6)
    }
}

@Suite("Barème")
struct ScoringTests {

    @Test("Chouette = valeur²", arguments: zip(1...6, [1, 4, 9, 16, 25, 36]))
    func chouette(value: Int, expected: Int) {
        #expect(RollAnalyzer.chouettePoints(value) == expected)
    }

    @Test("Velute = 2 × (grand dé)²", arguments: zip([3, 4, 5, 6], [18, 32, 50, 72]))
    func velute(value: Int, expected: Int) {
        #expect(RollAnalyzer.velutePoints(value) == expected)
    }

    @Test("Cul de chouette = 40 + 10 × valeur", arguments: zip(1...6, [50, 60, 70, 80, 90, 100]))
    func culDeChouette(value: Int, expected: Int) {
        #expect(RollAnalyzer.culDeChouettePoints(value) == expected)
    }

    @Test("Points directs du lanceur")
    func rollerPoints() {
        #expect(RollAnalyzer.rollerPoints(for: .suite(lowest: 2)) == 0)
        #expect(RollAnalyzer.rollerPoints(for: .neant) == 0)
        #expect(RollAnalyzer.rollerPoints(for: .chouetteVelute(pairValue: 2, veluteValue: 4)) == 0)
        var rules = RuleSet()
        rules.chouetteVeluteRollerKeepsChouette = true
        #expect(RollAnalyzer.rollerPoints(for: .chouetteVelute(pairValue: 2, veluteValue: 4), rules: rules) == 4)
    }

    @Test("Le barème est configurable")
    func customScale() {
        var rules = RuleSet()
        rules.chouetteMultiplier = 2
        rules.veluteMultiplier = 3
        rules.culDeChouetteBase = 0
        rules.culDeChouetteStep = 20
        #expect(RollAnalyzer.chouettePoints(3, rules: rules) == 18)
        #expect(RollAnalyzer.velutePoints(4, rules: rules) == 48)
        #expect(RollAnalyzer.culDeChouettePoints(6, rules: rules) == 120)
    }
}

@Suite("Types de base")
struct DiceTests {

    @Test func faceValidation() {
        #expect(DieFace(0) == nil)
        #expect(DieFace(7) == nil)
        #expect(DieFace(1)?.value == 1)
        #expect(Roll([1, 2]) == nil)
        #expect(Roll([1, 2, 9]) == nil)
    }

    @Test func birdNames() {
        #expect(DieFace.all.map(\.birdName) == ["Linotte", "Alouette", "Fauvette", "Mouette", "Bergeronnette", "Chouette"])
    }

    @Test("Le générateur à graine est déterministe et couvre les 6 faces")
    func seededGenerator() {
        var g1 = SeededGenerator(seed: 42)
        var g2 = SeededGenerator(seed: 42)
        let a = (0..<600).map { _ in DieFace.random(using: &g1).value }
        let b = (0..<600).map { _ in DieFace.random(using: &g2).value }
        #expect(a == b)
        #expect(Set(a) == Set(1...6))
    }
}
