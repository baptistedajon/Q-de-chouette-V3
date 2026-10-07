// swift-tools-version: 6.0
// ChouetteKit — logique pure du jeu, sans dépendance à UIKit/SwiftUI.
// Testable sur macOS avec `swift test` comme dans Xcode.

import PackageDescription

let package = Package(
    name: "ChouetteKit",
    defaultLocalization: "fr",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ChouetteRules", targets: ["ChouetteRules"]),
    ],
    targets: [
        .target(name: "ChouetteRules"),
        .testTarget(name: "ChouetteRulesTests", dependencies: ["ChouetteRules"]),
    ]
)
