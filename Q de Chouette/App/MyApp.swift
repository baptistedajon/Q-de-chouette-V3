// MyApp.swift
// Point d'entrée : base SwiftData, réglages et navigation partagés.

import SwiftUI
import SwiftData

@main
struct MyApp: App {
    @State private var settings = AppSettings()
    @State private var router = Router()
    private let container = Persistence.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(router)
        }
        .modelContainer(container)
    }
}
