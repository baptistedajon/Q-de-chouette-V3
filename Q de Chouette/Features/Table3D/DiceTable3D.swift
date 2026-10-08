// DiceTable3D.swift
// Scène RealityKit de la table de taverne et simulation physique des dés.
// La valeur retenue est celle de la face réellement tournée vers le haut quand
// les dés s'arrêtent (lecture de l'orientation) : rien n'est tiré à l'avance.
//
// ⚠︎ ASSETS PROCÉDURAUX — table, bougies, parchemin, gobelet et dés sont générés en code
// (voir ASSETS.md). Ils peuvent être remplacés par des modèles USDZ sans toucher à la physique :
// seules les fonctions `make…` sont concernées.

import RealityKit
import SwiftUI
import UIKit
import simd
import ChouetteRules

@MainActor
final class DiceTable3D {

    enum State { case idle, rolling, settled }

    // MARK: Dimensions (mètres)

    static let dieSize: Float = 0.045
    /// Zone de jeu délimitée par des murs invisibles.
    static let playArea = SIMD2<Float>(0.9, 0.6)

    // MARK: État

    let root = Entity()
    private(set) var state = State.idle
    private var dice: [ModelEntity] = []
    private let camera = PerspectiveCamera()
    private var flames: [(light: PointLight, flame: ModelEntity, base: Float, phase: Float)] = []

    private var detector = SettleDetector()
    private var thrownIndices: [Int] = []
    private var nudges = 0
    private var completion: (([DieFace]) -> Void)?
    private var time: Float = 0
    private var cameraTarget = SIMD3<Float>(0, 0, 0)
    /// Écartement des dés, pour reculer la caméra et tous les garder dans le cadre.
    private var spread: Float = 0.1
    /// Transformations de l'image précédente : on en déduit les vitesses réelles des dés.
    private var previousTransforms: [Int: (position: SIMD3<Float>, orientation: simd_quatf)] = [:]

    /// Sans mouvements de caméra ni scintillement (« Réduire les animations »).
    var reduceMotion = false
    /// Appelé à chaque choc d'un dé (intensité 0…1), pour les sons et vibrations.
    var onImpact: ((Float) -> Void)?

    init() {
        root.addChild(makeTable())
        root.addChild(makeWalls())
        for entity in makeDecor() + makeLights() { root.addChild(entity) }
        for index in 0..<3 {
            let die = makeDie()
            die.name = "die-\(index)"
            dice.append(die)
            root.addChild(die)
        }
        camera.camera.fieldOfViewInDegrees = 50
        root.addChild(camera)
        placeCamera(immediately: true)
        showResting(faces: [nil, nil, nil])
    }

    // MARK: - Lancer

    /// Lance les dés d'indices donnés. `direction` : sens du geste dans le plan de la table
    /// (x vers la droite, y vers le fond), `strength` entre 0 et 1.
    func throwDice(indices: [Int], direction: SIMD2<Float> = [0, 1], strength: Float = 0.6,
                   completion: @escaping ([DieFace]) -> Void) {
        guard state != .rolling, !indices.isEmpty else { return }
        state = .rolling
        thrownIndices = indices
        nudges = 0
        detector.reset()
        previousTransforms = [:]
        self.completion = completion

        for (index, die) in dice.enumerated() {
            setDynamic(die, indices.contains(index))
        }
        let dir = simd_length(direction) > 0.01 ? simd_normalize(direction) : SIMD2<Float>(0, 1)
        let power = 0.8 + 1.2 * min(max(strength, 0), 1)
        for (slot, index) in indices.enumerated() {
            let die = dice[index]
            // Départ groupé au bord de la table côté joueur, comme à la sortie du gobelet.
            die.position = [Float(slot - 1) * 0.06 + .random(in: -0.01...0.01), 0.14, 0.24]
            die.orientation = simd_quatf(angle: .random(in: 0...(2 * .pi)),
                                         axis: simd_normalize(SIMD3<Float>(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1)) + SIMD3<Float>(0, 0.01, 0)))
            let velocity = SIMD3<Float>(dir.x * power * 0.5 + .random(in: -0.15...0.15),
                                        .random(in: 0.3...0.7),
                                        -dir.y * power + .random(in: -0.1...0.1))
            let spin = SIMD3<Float>(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1)) * Float.random(in: 18...32)
            die.components.set(PhysicsMotionComponent(linearVelocity: velocity, angularVelocity: spin))
        }
    }

    /// Place les dés à plat, faces données vers le haut (restauration d'une partie, valeurs saisies…).
    func showResting(faces: [Int?]) {
        for (index, die) in dice.enumerated() {
            setDynamic(die, false)
            die.position = [Float(index - 1) * 0.09, Self.dieSize / 2, 0.02]
            let face = faces.indices.contains(index) ? faces[index].flatMap(DieFace.init) : nil
            die.orientation = DieOrientation.rotation(showing: face ?? DieFace(1)!, yaw: .random(in: -0.4...0.4))
        }
        state = .idle
        cameraTarget = centroid(of: Array(0..<3))
        spread = spreadOf(Array(0..<3))
    }

    // MARK: - Boucle de simulation

    /// À appeler à chaque image.
    func update(deltaTime: Double) {
        let dt = Float(deltaTime)
        time += dt
        flicker()

        if state == .rolling {
            // Dé tombé de la table : on le replace au-dessus du plateau.
            for index in thrownIndices where dice[index].position.y < -0.3 {
                dice[index].position = [0, 0.15, 0]
                dice[index].components.set(PhysicsMotionComponent(linearVelocity: [0, 0, 0], angularVelocity: [6, 4, 3]))
            }
            let (linear, angular) = measuredVelocities(deltaTime: dt)
            let result = detector.update(linear: linear, angular: angular, deltaTime: deltaTime)
            if result != .rolling { finishRoll() }
            cameraTarget = centroid(of: thrownIndices)
            spread = spreadOf(Array(0..<3))
        }
        placeCamera(immediately: reduceMotion, deltaTime: dt)
    }

    /// Vitesses mesurées d'après le déplacement des dés depuis l'image précédente
    /// (indépendant de ce que le moteur physique expose).
    private func measuredVelocities(deltaTime dt: Float) -> ([SIMD3<Float>], [SIMD3<Float>]) {
        var linear: [SIMD3<Float>] = []
        var angular: [SIMD3<Float>] = []
        for index in thrownIndices {
            let position = dice[index].position
            let orientation = dice[index].orientation
            if let previous = previousTransforms[index], dt > 0 {
                linear.append((position - previous.position) / dt)
                let delta = orientation * previous.orientation.inverse
                let angle = 2 * acos(min(abs(delta.real), 1))
                angular.append([angle / dt, 0, 0])
            } else {
                // Première image : on considère le dé en mouvement.
                linear.append([1, 0, 0])
                angular.append([1, 0, 0])
            }
            previousTransforms[index] = (position, orientation)
        }
        return (linear, angular)
    }

    private func spreadOf(_ indices: [Int]) -> Float {
        let c = centroid(of: indices)
        return indices.map { simd_length(SIMD2(dice[$0].position.x - c.x, dice[$0].position.z - c.z)) }.max() ?? 0.1
    }

    private func finishRoll() {
        var faces: [DieFace] = []
        for index in thrownIndices {
            let (face, alignment) = DieOrientation.topFace(rotation: dice[index].orientation(relativeTo: nil))
            if DieOrientation.isCocked(alignment: alignment) && nudges < 3 {
                // Dé « cassé » contre un bord : on le pousse un peu et on attend qu'il retombe à plat.
                nudges += 1
                detector.reset()
                dice[index].components.set(PhysicsMotionComponent(linearVelocity: [.random(in: -0.2...0.2), 0.5, .random(in: -0.2...0.2)],
                                                                  angularVelocity: [.random(in: -6...6), 0, .random(in: -6...6)]))
                return
            }
            faces.append(face)
        }
        state = .settled
        for die in dice { setDynamic(die, false) }
        // Inclinaison résiduelle (dé calé contre un autre, délai maximal atteint…) : on le pose
        // à plat en douceur sur la face déjà lue, pour que l'affichage corresponde au résultat.
        for index in thrownIndices {
            let die = dice[index]
            let current = die.orientation(relativeTo: nil)
            guard DieOrientation.topFace(rotation: current).alignment < 0.9995 else { continue }
            var target = die.transform
            target.rotation = DieOrientation.flattened(rotation: current)
            // Posé sur la table (et non appuyé sur un autre dé) : on le redescend au contact.
            if target.translation.y < Self.dieSize * 1.2 { target.translation.y = Self.dieSize / 2 }
            die.move(to: target, relativeTo: die.parent, duration: reduceMotion ? 0 : 0.25, timingFunction: .easeOut)
        }
        let done = completion
        completion = nil
        done?(faces)
    }

    // MARK: - Caméra

    private func placeCamera(immediately: Bool, deltaTime: Float = 1) {
        // En mouvement : vue plongeante qui suit les dés ; à l'arrêt : cadrage serré sur le résultat.
        // Plus les dés sont écartés, plus la caméra prend de la hauteur.
        let height = 0.30 + spread * 1.3
        // À l'arrêt, vue presque à la verticale : les faces du dessus se lisent d'un coup d'œil.
        let offset: SIMD3<Float> = state == .rolling ? [0, 0.42, 0.42] : [0, height, height * 0.12]
        let desired = (reduceMotion ? SIMD3<Float>(0, 0, -0.02) : cameraTarget) + (reduceMotion ? [0, 0.6, 0.45] : offset)
        let factor = immediately ? 1 : 1 - exp(-deltaTime * 3)
        camera.position += (desired - camera.position) * factor
        let lookTarget = reduceMotion ? SIMD3<Float>(0, 0, -0.02) : cameraTarget
        camera.look(at: lookTarget, from: camera.position, relativeTo: nil)
    }

    private func centroid(of indices: [Int]) -> SIMD3<Float> {
        guard !indices.isEmpty else { return .zero }
        var sum = SIMD3<Float>.zero
        for index in indices { sum += dice[index].position }
        var c = sum / Float(indices.count)
        c.y = 0
        c.x = min(max(c.x, -0.35), 0.35)
        c.z = min(max(c.z, -0.25), 0.25)
        return c
    }

    // MARK: - Lumières vacillantes

    private func flicker() {
        guard !reduceMotion else { return }
        for candle in flames {
            let t = time * 7 + candle.phase
            let noise = 0.5 * sin(t) + 0.3 * sin(t * 2.3 + 1.7) + 0.2 * sin(t * 5.1 + 0.4)
            candle.light.light.intensity = candle.base * (0.85 + 0.15 * noise)
            candle.flame.scale = [1, 1 + 0.12 * noise, 1]
        }
    }

    // MARK: - Physique

    private func setDynamic(_ die: ModelEntity, _ dynamic: Bool) {
        guard var body = die.components[PhysicsBodyComponent.self] else { return }
        body.mode = dynamic ? .dynamic : .kinematic
        die.components.set(body)
        if !dynamic { die.components.set(PhysicsMotionComponent()) }
    }

    /// Branche les sons et vibrations de chocs sur la scène.
    func subscribeToCollisions(in content: RealityViewCameraContent) -> EventSubscription {
        var lastImpact = Date.distantPast
        return content.subscribe(to: CollisionEvents.Began.self) { [weak self] (event: CollisionEvents.Began) in
            guard let self, self.state == .rolling,
                  event.entityA.name.hasPrefix("die-") || event.entityB.name.hasPrefix("die-"),
                  Date.now.timeIntervalSince(lastImpact) > 0.06 else { return }
            lastImpact = .now
            self.onImpact?(min(event.impulse * 8, 1))
        }
    }

    // MARK: - Construction des objets

    private func makeDie() -> ModelEntity {
        let s = Self.dieSize
        let body = ModelEntity(mesh: .generateBox(size: s, cornerRadius: s * 0.14),
                               materials: [Self.material(color: UIColor(red: 0.96, green: 0.93, blue: 0.85, alpha: 1), roughness: 0.35)])
        let pipMesh = MeshResource.generateSphere(radius: s * 0.085)
        let ink = Self.material(color: UIColor(white: 0.1, alpha: 1), roughness: 0.6)
        let wine = Self.material(color: UIColor(red: 0.6, green: 0.12, blue: 0.1, alpha: 1), roughness: 0.5)
        // Positions des points sur une grille 3×3, comme le dé 2D.
        let layouts: [Int: [(Float, Float)]] = [
            1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)],
            4: [(-1, -1), (1, -1), (-1, 1), (1, 1)], 5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
            6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)],
        ]
        for face in DieFace.all {
            let n = DieOrientation.normal(of: face)
            let (u, v): (SIMD3<Float>, SIMD3<Float>) = abs(n.y) > 0.5 ? ([1, 0, 0], [0, 0, 1])
                : abs(n.x) > 0.5 ? ([0, 0, 1], [0, 1, 0]) : ([1, 0, 0], [0, 1, 0])
            for (x, y) in layouts[face.value] ?? [] {
                let pip = ModelEntity(mesh: pipMesh, materials: [face.value == 1 ? wine : ink])
                pip.position = n * (s / 2 - s * 0.03) + u * (x * s * 0.26) + v * (y * s * 0.26)
                if face.value == 1 { pip.scale = [1.4, 1.4, 1.4] }
                body.addChild(pip)
            }
        }
        body.components.set(CollisionComponent(shapes: [.generateBox(size: [s, s, s])]))
        // Masse ET inertie calculées depuis la forme du dé. `init(mass:)` seul laisse une inertie
        // par défaut d'environ 1 kg·m², énorme pour un cube de 4,5 cm : le dé ne pivotait plus
        // sous son propre poids et restait en équilibre sur une arête.
        var physics = PhysicsBodyComponent(massProperties: PhysicsMassProperties(shape: .generateBox(size: [s, s, s]), mass: 0.02),
                                           material: .generate(staticFriction: 0.8, dynamicFriction: 0.6, restitution: 0.3),
                                           mode: .kinematic)
        // Amortissement : les dés roulent franchement puis s'immobilisent en 2 à 3 secondes.
        physics.linearDamping = 0.6
        physics.angularDamping = 1.6
        body.components.set(physics)
        body.components.set(PhysicsMotionComponent())
        body.components.set(GroundingShadowComponent(castsShadow: true))
        return body
    }

    private func makeTable() -> ModelEntity {
        let size = SIMD3<Float>(1.3, 0.05, 0.9)
        let table = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.01), materials: [Self.woodMaterial()])
        table.position = [0, -size.y / 2, 0]
        table.components.set(CollisionComponent(shapes: [.generateBox(size: size)]))
        table.components.set(PhysicsBodyComponent(massProperties: .default,
                                                  material: .generate(staticFriction: 0.9, dynamicFriction: 0.7, restitution: 0.25),
                                                  mode: .static))
        // Sol sombre sous la table, pour l'ambiance.
        let floor = ModelEntity(mesh: .generatePlane(width: 6, depth: 6),
                                materials: [Self.material(color: UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1), roughness: 1)])
        floor.position = [0, -0.75, 0]
        table.addChild(floor)
        return table
    }

    private func makeWalls() -> Entity {
        let walls = Entity()
        let (w, d) = (Self.playArea.x, Self.playArea.y)
        let h: Float = 0.4
        let specs: [(SIMD3<Float>, SIMD3<Float>)] = [
            ([w + 0.1, h, 0.05], [0, h / 2, -d / 2 - 0.025]),
            ([w + 0.1, h, 0.05], [0, h / 2, d / 2 + 0.025]),
            ([0.05, h, d], [-w / 2 - 0.025, h / 2, 0]),
            ([0.05, h, d], [w / 2 + 0.025, h / 2, 0]),
            ([w, 0.05, d], [0, h + 0.025, 0]),   // plafond invisible
        ]
        for (size, position) in specs {
            let wall = Entity()
            wall.position = position
            wall.components.set(CollisionComponent(shapes: [.generateBox(size: size)]))
            wall.components.set(PhysicsBodyComponent(massProperties: .default,
                                                     material: .generate(staticFriction: 0.3, dynamicFriction: 0.3, restitution: 0.5),
                                                     mode: .static))
            walls.addChild(wall)
        }
        return walls
    }

    private func makeDecor() -> [Entity] {
        var decor: [Entity] = []

        // Bougies aux coins du fond.
        for (index, x) in [Float(-0.5), 0.52].enumerated() {
            let candle = ModelEntity(mesh: .generateCylinder(height: 0.12, radius: 0.022),
                                     materials: [Self.material(color: UIColor(red: 0.95, green: 0.9, blue: 0.78, alpha: 1), roughness: 0.8)])
            candle.position = [x, 0.06, -0.36]
            let flame = ModelEntity(mesh: .generateSphere(radius: 0.012),
                                    materials: [UnlitMaterial(color: UIColor(red: 1, green: 0.72, blue: 0.3, alpha: 1))])
            flame.position = [0, 0.075, 0]
            flame.scale = [1, 1.8, 1]
            candle.addChild(flame)
            let light = PointLight()
            light.light.color = UIColor(red: 1, green: 0.68, blue: 0.38, alpha: 1)
            light.light.intensity = 2600
            light.light.attenuationRadius = 1.4
            light.position = [0, 0.09, 0.02]
            candle.addChild(light)
            flames.append((light, flame, 2600, Float(index) * 2.1))
            decor.append(candle)
        }

        // Parchemin des scores, posé de biais.
        let parchment = ModelEntity(mesh: .generateBox(size: [0.24, 0.002, 0.17], cornerRadius: 0.001),
                                    materials: [Self.material(color: UIColor(red: 0.91, green: 0.83, blue: 0.64, alpha: 1), roughness: 0.95)])
        parchment.position = [-0.44, 0.001, 0.2]
        parchment.orientation = simd_quatf(angle: 0.35, axis: [0, 1, 0])
        decor.append(parchment)

        // Gobelet en cuir.
        let cup = ModelEntity(mesh: .generateCylinder(height: 0.11, radius: 0.05),
                              materials: [Self.material(color: UIColor(red: 0.33, green: 0.18, blue: 0.1, alpha: 1), roughness: 0.75)])
        cup.position = [0.47, 0.055, 0.18]
        decor.append(cup)
        return decor
    }

    private func makeLights() -> [Entity] {
        let sun = DirectionalLight()
        sun.light.color = UIColor(red: 1, green: 0.87, blue: 0.7, alpha: 1)
        sun.light.intensity = 2200
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 2, depthBias: 1)
        sun.look(at: .zero, from: [0.35, 1.2, 0.5], relativeTo: nil)
        return [sun]
    }

    // MARK: - Matériaux

    private static func material(color: UIColor, roughness: Float) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: 0)
        return material
    }

    /// Bois de chêne sombre : texture de veines générée en code.
    private static func woodMaterial() -> PhysicallyBasedMaterial {
        var material = material(color: UIColor(red: 0.45, green: 0.28, blue: 0.15, alpha: 1), roughness: 0.7)
        if let image = woodGrainImage(), let texture = try? TextureResource(image: image, options: .init(semantic: .color)) {
            material.baseColor = .init(tint: .white, texture: .init(texture))
        }
        return material
    }

    private static func woodGrainImage(size: Int = 512) -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let cg = context.cgContext
            UIColor(red: 0.42, green: 0.26, blue: 0.14, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: size, height: size))
            var generator = SeededGenerator(seed: 343)
            // Veines : lignes ondulées plus sombres ou plus claires.
            for _ in 0..<90 {
                let y0 = CGFloat.random(in: 0...CGFloat(size), using: &generator)
                let amplitude = CGFloat.random(in: 2...9, using: &generator)
                let frequency = CGFloat.random(in: 0.005...0.02, using: &generator)
                let dark = Bool.random(using: &generator)
                (dark ? UIColor(red: 0.28, green: 0.16, blue: 0.08, alpha: 0.35)
                      : UIColor(red: 0.6, green: 0.4, blue: 0.22, alpha: 0.22)).setStroke()
                cg.setLineWidth(.random(in: 0.8...3.5, using: &generator))
                cg.move(to: CGPoint(x: 0, y: y0))
                for x in stride(from: 0, through: CGFloat(size), by: 8) {
                    cg.addLine(to: CGPoint(x: x, y: y0 + amplitude * sin(x * frequency * .pi * 2)))
                }
                cg.strokePath()
            }
        }
        return image.cgImage
    }
}
