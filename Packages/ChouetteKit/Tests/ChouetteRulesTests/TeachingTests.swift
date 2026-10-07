import Testing
@testable import ChouetteRules

@Suite("Outils pédagogiques")
struct TeachingTests {

    @Test("Nombre d'exemples distincts par figure")
    func exampleCounts() {
        #expect(FigureKind.culDeChouette.exampleRolls().count == 6)
        #expect(FigureKind.chouetteVelute.exampleRolls() == [Roll(1, 1, 2), Roll(2, 2, 4), Roll(3, 3, 6)])
        #expect(FigureKind.chouette.exampleRolls().count == 27)   // 30 paires − 3 chouettes-velutes
        #expect(FigureKind.velute.exampleRolls().count == 6)
        #expect(FigureKind.suite.exampleRolls() == [Roll(2, 3, 4), Roll(3, 4, 5), Roll(4, 5, 6)])
        #expect(FigureKind.neant.exampleRolls().count == 11)
    }

    @Test("Avec « suite seule », 1-2-3 devient un exemple de suite")
    func oneTwoThreeAsSuite() {
        var rules = RuleSet()
        rules.oneTwoThree = .suiteOnly
        #expect(FigureKind.suite.exampleRolls(rules: rules).first == Roll(1, 2, 3))
        #expect(!FigureKind.velute.exampleRolls(rules: rules).contains(Roll(1, 2, 3)))
    }

    @Test("Chaque exemple est bien de la figure annoncée", arguments: FigureKind.allCases)
    func examplesAreCorrect(kind: FigureKind) {
        for roll in kind.exampleRolls() {
            #expect(RollAnalyzer.analyze(roll).figures.first?.kind == kind)
            #expect(roll.dice.map(\.value) == roll.sortedValues)
        }
    }

    @Test("Le détail du calcul donne le même total que le barème")
    func breakdownMatchesScoring() {
        for roll in Roll.allRolls {
            for figure in RollAnalyzer.analyze(roll).figures {
                let total = RollAnalyzer.breakdown(for: figure).total
                switch figure {
                case .chouetteVelute(_, let v): #expect(total == RollAnalyzer.velutePoints(v))
                case .suite: #expect(total == -10)
                default: #expect(total == RollAnalyzer.rollerPoints(for: figure))
                }
            }
        }
    }

    @Test func breakdownDetails() {
        #expect(RollAnalyzer.breakdown(for: .chouette(value: 4)) == .square(value: 4, multiplier: 1, total: 16))
        #expect(RollAnalyzer.breakdown(for: .velute(value: 3)) == .square(value: 3, multiplier: 2, total: 18))
        #expect(RollAnalyzer.breakdown(for: .culDeChouette(value: 2)) == .culDeChouette(value: 2, base: 40, step: 10, total: 60))
        #expect(RollAnalyzer.breakdown(for: .neant) == .none)
    }
}
