import Testing
import simd
@testable import ChouetteRules

@Suite("Dé 3D : lecture de la face du dessus")
struct DieOrientationTests {

    @Test("Les faces opposées totalisent 7")
    func oppositeFaces() {
        for face in DieFace.all {
            let opposite = DieFace(7 - face.value)!
            #expect(simd_dot(DieOrientation.normal(of: face), DieOrientation.normal(of: opposite)) == -1)
        }
    }

    @Test("Chaque face présentée vers le haut est bien lue", arguments: DieFace.all)
    func readsPresentedFace(face: DieFace) {
        for yaw in stride(from: Float(0), to: 2 * .pi, by: 0.7) {
            let (top, alignment) = DieOrientation.topFace(rotation: DieOrientation.rotation(showing: face, yaw: yaw))
            #expect(top == face)
            #expect(alignment > 0.999)
            #expect(!DieOrientation.isCocked(alignment: alignment))
        }
    }

    @Test("Légère inclinaison : même face ; sur une arête : dé cassé")
    func tilt() {
        let base = DieOrientation.rotation(showing: DieFace(4)!)
        let slight = simd_quatf(angle: 5 * .pi / 180, axis: simd_normalize([1, 0, 1])) * base
        let (face, alignment) = DieOrientation.topFace(rotation: slight)
        #expect(face == DieFace(4))
        #expect(!DieOrientation.isCocked(alignment: alignment))

        let onEdge = simd_quatf(angle: 40 * .pi / 180, axis: [1, 0, 0]) * base
        #expect(DieOrientation.isCocked(alignment: DieOrientation.topFace(rotation: onEdge).alignment))
    }

    @Test("Orientations aléatoires : la face lue est celle qui pointe le plus vers le haut")
    func randomOrientations() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<500 {
            let axis = simd_normalize(SIMD3<Float>(Float.random(in: -1...1, using: &rng),
                                                   Float.random(in: -1...1, using: &rng),
                                                   Float.random(in: -1...1, using: &rng)) + [0, 0.001, 0])
            let q = simd_quatf(angle: Float.random(in: 0...(2 * .pi), using: &rng), axis: axis)
            let (face, alignment) = DieOrientation.topFace(rotation: q)
            for other in DieFace.all {
                #expect(simd_dot(q.act(DieOrientation.normal(of: other)), [0, 1, 0]) <= alignment + 1e-5)
            }
            #expect(alignment >= 1 / sqrt(3) - 1e-4, "Au moins une face pointe toujours un peu vers le haut")
            _ = face
        }
    }
}

@Suite("Dé 3D : détection de l'arrêt")
struct SettleDetectorTests {

    private let still = SIMD3<Float>(0, 0, 0)
    private let moving = SIMD3<Float>(0.5, 0, 0)

    @Test("Arrêt après une immobilité continue")
    func settles() {
        var detector = SettleDetector()
        #expect(detector.update(linear: [moving, still], angular: [still, still], deltaTime: 0.1) == .rolling)
        #expect(detector.update(linear: [still, still], angular: [still, still], deltaTime: 0.2) == .rolling)
        #expect(detector.update(linear: [still, still], angular: [still, still], deltaTime: 0.2) == .settled)
    }

    @Test("Un mouvement remet le compteur à zéro")
    func resetOnMovement() {
        var detector = SettleDetector()
        _ = detector.update(linear: [still], angular: [still], deltaTime: 0.3)
        #expect(detector.update(linear: [still], angular: [moving], deltaTime: 0.01) == .rolling)
        #expect(detector.update(linear: [still], angular: [still], deltaTime: 0.3) == .rolling)
        #expect(detector.update(linear: [still], angular: [still], deltaTime: 0.1) == .settled)
    }

    @Test("Délai maximal")
    func timeout() {
        var detector = SettleDetector()
        var state = SettleDetector.State.rolling
        for _ in 0..<100 { state = detector.update(linear: [moving], angular: [moving], deltaTime: 0.1) }
        #expect(state == .timedOut)
    }
}
