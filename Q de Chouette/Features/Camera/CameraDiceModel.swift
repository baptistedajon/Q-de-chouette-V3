// CameraDiceModel.swift
// Caméra en direct et analyse des images pour reconnaître de vrais dés.
// Les images sont analysées sur l'appareil et ne sont jamais enregistrées ni envoyées.

import AVFoundation
import CoreGraphics
import CoreImage
import Observation
import UIKit
import ChouetteRules

@Observable
final class CameraDiceModel {

    enum Availability { case unknown, ready, denied, unavailable }

    private(set) var availability = Availability.unknown
    /// Derniers dés détectés (positions pour l'affichage).
    private(set) var detected: [DetectedDie] = []
    /// Valeurs stables : identiques sur plusieurs images consécutives.
    private(set) var stableValues: [Int]?

    let session = AVCaptureSession()
    private let runner: SessionRunner
    let expectedCount: Int
    private let analyzer: FrameAnalyzer
    private var recent: [[Int]] = []

    init(expectedCount: Int) {
        self.expectedCount = expectedCount
        analyzer = FrameAnalyzer(expectedCount: expectedCount)
        runner = SessionRunner(session: session)
        analyzer.onResult = { [weak self] dice in
            Task { @MainActor in self?.receive(dice) }
        }
    }

    // MARK: Démarrage

    func start() async {
        #if targetEnvironment(simulator)
        availability = .unavailable
        return
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { availability = .denied; return }
        default:
            availability = .denied
            return
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            availability = .unavailable
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(analyzer, queue: analyzer.queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        // Images en portrait, comme l'aperçu.
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        session.commitConfiguration()
        availability = .ready
        runner.start()
        #endif
    }

    func stop() { runner.stop() }

    // MARK: Résultats

    private func receive(_ dice: [DetectedDie]) {
        detected = dice
        let values = dice.map(\.value)
        recent.append(values)
        if recent.count > 3 { recent.removeFirst() }
        if values.count == expectedCount, recent.count == 3, recent.allSatisfy({ $0 == values }) {
            stableValues = values
        }
    }

    /// Analyse d'une photo choisie dans la photothèque.
    func analyze(photo: UIImage) -> [DetectedDie] {
        guard let gray = GrayImage(image: photo, maxSide: 900) else { return [] }
        let dice = DiceRecognizer.detect(in: gray, expected: expectedCount)
        detected = dice
        if dice.count == expectedCount { stableValues = dice.map(\.value) }
        return dice
    }
}

/// Démarre et arrête la session sur une file dédiée (opérations bloquantes).
nonisolated final class SessionRunner: @unchecked Sendable {
    private let session: AVCaptureSession
    private let queue = DispatchQueue(label: "dice.session")

    init(session: AVCaptureSession) { self.session = session }

    func start() { queue.async { if !self.session.isRunning { self.session.startRunning() } } }
    func stop() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }
}

/// Reçoit les images de la caméra sur une file dédiée et en analyse quelques-unes par seconde.
nonisolated final class FrameAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "dice.frames", qos: .userInitiated)
    var onResult: (@Sendable ([DetectedDie]) -> Void)?
    private let expectedCount: Int
    private var lastAnalysis = Date.distantPast

    init(expectedCount: Int) {
        self.expectedCount = expectedCount
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date.now.timeIntervalSince(lastAnalysis) > 0.25,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let gray = GrayImage(lumaOf: buffer, maxSide: 400) else { return }
        lastAnalysis = .now
        onResult?(DiceRecognizer.detect(in: gray, expected: expectedCount))
    }
}

// MARK: - Conversions vers une image en niveaux de gris

extension GrayImage {

    /// Plan de luminance (Y) d'une image caméra, réduit par moyenne de blocs.
    nonisolated init?(lumaOf buffer: CVPixelBuffer, maxSide: Int) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard CVPixelBufferGetPlaneCount(buffer) >= 1,
              let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return nil }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let factor = max(1, Int((Double(max(width, height)) / Double(maxSide)).rounded(.up)))
        let w = width / factor, h = height / factor
        let source = base.assumingMemoryBound(to: UInt8.self)
        var pixels = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                var sum = 0
                for dy in 0..<factor {
                    let row = source + (y * factor + dy) * stride + x * factor
                    for dx in 0..<factor { sum += Int(row[dx]) }
                }
                pixels[y * w + x] = UInt8(sum / (factor * factor))
            }
        }
        self.init(width: w, height: h, pixels: pixels)
    }

    /// Photo quelconque, redressée selon son orientation et réduite.
    init?(image: UIImage, maxSide: Int) {
        let scale = min(1, CGFloat(maxSide) / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let w = Int(size.width), h = Int(size.height)
        guard w > 0, h > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h)
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                          bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            UIGraphicsPushContext(context)
            // UIKit dessine avec l'origine en haut à gauche : on retourne le repère.
            context.translateBy(x: 0, y: CGFloat(h))
            context.scaleBy(x: 1, y: -1)
            image.draw(in: CGRect(origin: .zero, size: size))
            UIGraphicsPopContext()
            return true
        }
        guard drawn else { return nil }
        self.init(width: w, height: h, pixels: pixels)
    }
}
