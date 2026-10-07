// CameraDiceSheet.swift
// Lecture de vrais dés : caméra en direct (ou photo de la photothèque), puis
// vérification et correction rapide avant de valider.

import SwiftUI
import AVFoundation
import PhotosUI
import ChouetteRules

struct CameraDiceSheet: View {
    let count: Int
    let title: String
    let onSubmit: ([DieFace]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var camera: CameraDiceModel
    /// Valeurs proposées ; `nil` tant qu'un dé n'est pas lu ni saisi.
    @State private var values: [Int?]
    /// Dès qu'un joueur corrige un dé, la caméra ne modifie plus les valeurs.
    @State private var editedByHand = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var photoMessage: String?

    init(count: Int, title: String, onSubmit: @escaping ([DieFace]) -> Void) {
        self.count = count
        self.title = title
        self.onSubmit = onSubmit
        _camera = State(initialValue: CameraDiceModel(expectedCount: count))
        _values = State(initialValue: Array(repeating: nil, count: count))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    viewfinder
                        .frame(height: 340)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choisir une photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.secondary)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.updatesFrequently)

                    correctionRow
                }
                .padding()
            }
            .themedBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") { onSubmit(values.compactMap { $0.flatMap(DieFace.init) }) }
                        .disabled(values.contains(nil))
                }
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.stableValues) { _, stable in
            guard let stable, !editedByHand else { return }
            values = stable.map(Optional.some)
        }
        .onChange(of: photoItem) { _, item in
            Task { await load(item) }
        }
        .sensoryFeedback(.success, trigger: camera.stableValues) { _, new in settings.hapticsEnabled && new != nil }
    }

    // MARK: Viseur

    @ViewBuilder
    private var viewfinder: some View {
        ZStack {
            Color.black
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .overlay { DetectionOverlay(dice: camera.detected) }
                    .accessibilityLabel(Text("Photo des dés"))
            } else {
                switch camera.availability {
                case .ready:
                    // Même format que les images analysées (720 × 1280 en portrait) : les cadres tombent juste.
                    CameraPreview(session: camera.session)
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .overlay { DetectionOverlay(dice: camera.detected) }
                        .accessibilityLabel(Text("Aperçu de l'appareil photo"))
                case .unknown:
                    ProgressView().tint(.white)
                case .denied:
                    unavailableMessage(String(localized: "L'accès à l'appareil photo est refusé. Autorisez-le dans Réglages, ou choisissez une photo."))
                case .unavailable:
                    unavailableMessage(String(localized: "Aucun appareil photo disponible. Choisissez une photo de vos dés."))
                }
            }
        }
    }

    private func unavailableMessage(_ text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill").font(.largeTitle)
            Text(text).multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.white)
        .padding()
    }

    private var statusText: String {
        if let photoMessage { return photoMessage }
        if editedByHand { return String(localized: "Valeurs corrigées à la main. Vérifiez puis validez.") }
        if camera.stableValues != nil { return String(localized: "Dés reconnus ! Vérifiez puis validez, ou touchez un dé pour le corriger.") }
        return count == 1
            ? String(localized: "Filmez le dé de dessus, sur un fond sombre et uni.")
            : String(localized: "Filmez les dés de dessus, sur un fond sombre et uni, sans qu'ils se touchent.")
    }

    // MARK: Correction rapide

    private var correctionRow: some View {
        VStack(spacing: 8) {
            Text("Touchez un dé pour corriger sa valeur").font(.footnote).foregroundStyle(Theme.inkSecondary)
            HStack(spacing: 16) {
                ForEach(0..<count, id: \.self) { index in
                    Button {
                        editedByHand = true
                        values[index] = (values[index] ?? 0) % 6 + 1
                    } label: {
                        DieView(value: values[index], size: 64, isHighlighted: values[index] != nil)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(values[index].map { Text("Dé \(index + 1) : \($0)") } ?? Text("Dé \(index + 1) : non lu"))
                    .accessibilityHint(Text("Augmente la valeur"))
                    .accessibilityAdjustableAction { direction in
                        editedByHand = true
                        let current = values[index] ?? 1
                        values[index] = direction == .increment ? current % 6 + 1 : (current + 4) % 6 + 1
                    }
                }
            }
        }
        .parchmentCard()
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        photo = image
        camera.stop()
        let dice = camera.analyze(photo: image)
        editedByHand = false
        if dice.count == count {
            values = dice.map { Optional($0.value) }
            photoMessage = String(localized: "Dés reconnus ! Vérifiez puis validez, ou touchez un dé pour le corriger.")
        } else {
            values = (0..<count).map { dice.indices.contains($0) ? dice[$0].value : nil }
            photoMessage = String(localized: "\(dice.count) dé(s) reconnu(s) sur \(count). Complétez en touchant les dés ci-dessous.")
        }
    }
}

/// Cadres dorés autour des dés reconnus, avec leur valeur.
private struct DetectionOverlay: View {
    let dice: [DetectedDie]

    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(dice.enumerated()), id: \.offset) { _, die in
                let rect = CGRect(x: die.minX * geometry.size.width, y: die.minY * geometry.size.height,
                                  width: (die.maxX - die.minX) * geometry.size.width,
                                  height: (die.maxY - die.minY) * geometry.size.height)
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.gold, lineWidth: 3)
                    .frame(width: rect.width, height: rect.height)
                    .overlay(alignment: .topLeading) {
                        Text("\(die.value)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 6)
                            .background(Theme.gold, in: Capsule())
                            .offset(y: -22)
                    }
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Aperçu vidéo de la caméra (mêmes proportions que les images analysées).
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        if let connection = view.previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
