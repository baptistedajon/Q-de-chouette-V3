// DiePhysics.swift
// Géométrie d'un dé 3D et détection de l'arrêt, indépendantes du moteur de rendu.
// Le mode 3D lit la face réellement tournée vers le haut après la simulation physique :
// aucun résultat n'est tiré à l'avance.

import simd

/// Correspondance entre les faces d'un dé et les axes de son repère local.
/// Les faces opposées totalisent 7, comme sur un vrai dé.
public enum DieOrientation {

    /// Normale sortante de chaque face, dans le repère local du dé.
    public static func normal(of face: DieFace) -> SIMD3<Float> {
        switch face.value {
        case 1: [0, 1, 0]
        case 6: [0, -1, 0]
        case 2: [1, 0, 0]
        case 5: [-1, 0, 0]
        case 3: [0, 0, 1]
        default: [0, 0, -1]   // 4
        }
    }

    /// Face tournée vers le haut pour une orientation donnée, et son alignement
    /// avec la verticale (1 : parfaitement à plat ; ≈ 0,71 : dé en équilibre sur une arête).
    public static func topFace(rotation: simd_quatf,
                               up: SIMD3<Float> = [0, 1, 0]) -> (face: DieFace, alignment: Float) {
        var best = (face: DieFace.all[0], alignment: -Float.infinity)
        for face in DieFace.all {
            let alignment = simd_dot(rotation.act(normal(of: face)), up)
            if alignment > best.alignment { best = (face, alignment) }
        }
        return best
    }

    /// Vrai si le dé est « cassé » (appuyé contre un bord, pas à plat) : il faut le relancer.
    /// `toleranceDegrees` : inclinaison maximale acceptée.
    public static func isCocked(alignment: Float, toleranceDegrees: Float = 12) -> Bool {
        alignment < cos(toleranceDegrees * .pi / 180)
    }

    /// Orientation qui présente `face` vers le haut, tournée de `yaw` radians autour de la verticale.
    public static func rotation(showing face: DieFace, yaw: Float = 0) -> simd_quatf {
        let up = SIMD3<Float>(0, 1, 0)
        let n = normal(of: face)
        let align: simd_quatf
        if simd_dot(n, up) < -0.999 {
            align = simd_quatf(angle: .pi, axis: [1, 0, 0])   // face du dessous : demi-tour
        } else {
            align = simd_quatf(from: n, to: up)
        }
        return simd_quatf(angle: yaw, axis: up) * align
    }
}

/// Décide quand les dés ont fini de rouler, à partir de leurs vitesses image par image.
public struct SettleDetector: Sendable {
    public var linearThreshold: Float = 0.02      // m/s
    public var angularThreshold: Float = 0.15     // rad/s
    /// Durée pendant laquelle tous les dés doivent rester immobiles.
    public var requiredStillTime: Double = 0.35
    /// Au-delà, on considère les dés arrêtés quoi qu'il arrive.
    public var timeout: Double = 8

    public private(set) var elapsed: Double = 0
    private var stillTime: Double = 0

    public init() {}

    public enum State: Equatable, Sendable { case rolling, settled, timedOut }

    /// Ajoute une image : vitesses linéaire et angulaire de chaque dé, durée écoulée.
    public mutating func update(linear: [SIMD3<Float>], angular: [SIMD3<Float>], deltaTime: Double) -> State {
        elapsed += deltaTime
        let still = zip(linear, angular).allSatisfy { lin, ang in
            simd_length(lin) < linearThreshold && simd_length(ang) < angularThreshold
        }
        stillTime = still ? stillTime + deltaTime : 0
        if stillTime >= requiredStillTime { return .settled }
        if elapsed >= timeout { return .timedOut }
        return .rolling
    }

    public mutating func reset() {
        elapsed = 0
        stillTime = 0
    }
}
