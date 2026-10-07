import SwiftUI
import ChouetteRules

/// Écran provisoire : remplacé par l'accueil en phase 2.
struct ContentView: View {
    private let example = RollAnalyzer.analyze(Roll(2, 2, 4))

    var body: some View {
        VStack(spacing: 12) {
            Text("Cul de Chouette")
                .font(.largeTitle.bold())
            Text("Moteur de règles prêt — exemple : \(example.roll.description)")
                .font(.body)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
