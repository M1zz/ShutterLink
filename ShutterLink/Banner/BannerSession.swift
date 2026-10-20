import AudioToolbox
import RealityKit
import SwiftUI

/// Banner mode of the camera: the design and the AR scene. `CameraController` still runs the show —
/// its timer, voice countdown and hands-free triggers end in `shoot()`, and shots, preview frames and
/// analysis frames go back to it, so the gallery and the remote work as in Photo mode.
@Observable
@MainActor
final class BannerSession {
    let design = BannerDesign()
    let controller: BannerARController
    /// True once the capture session has let go of the camera and the AR view may run.
    private(set) var isRunning = false

    @ObservationIgnored private weak var camera: CameraController?
    @ObservationIgnored private var previewTimer: Timer?
    @ObservationIgnored private var isSendingPreview = false

    private static let previewFPS: Double = 6
    nonisolated private static let previewLongEdge: CGFloat = 400

    init() {
        controller = BannerARController(design: design)
    }

    func connect(_ camera: CameraController) {
        self.camera = camera
        camera.onBannerStart = { [weak self] in self?.start() }
        camera.onBannerShot = { [weak self] in self?.shoot() }
        camera.onBannerEnd = { [weak self] in self?.stop() }
        controller.onCapture = { [weak camera] data in camera?.addBannerPhoto(data) }
        // Portrait-only app: the sensor image is turned from upright by however the phone is held.
        controller.onFrame = { [weak camera] buffer in
            guard let camera else { return }
            camera.analyzeBannerFrame(buffer, orientation: camera.turn.arFrameOrientation)
        }
        controller.onAudio = { [weak camera] buffer in camera?.analyzeBannerAudio(buffer) }
    }

    private func start() {
        guard !isRunning else { return }
        isRunning = true
        previewTimer = Timer.scheduledTimer(withTimeInterval: 1 / Self.previewFPS, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sendPreviewFrame() }
        }
    }

    private func stop() {
        previewTimer?.invalidate()
        previewTimer = nil
        controller.pause()
        isRunning = false
    }

    private func shoot() {
        AudioServicesPlaySystemSound(1108) // shutter
        controller.capture(turn: camera?.turn ?? .portrait)
    }

    /// The remote sees the banner too: a small snapshot of the AR view, only while someone is watching.
    private func sendPreviewFrame() {
        guard let camera, camera.previewDemand, !isSendingPreview, let arView = controller.arView else { return }
        isSendingPreview = true
        let turn = camera.turn
        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let image else {
                self?.isSendingPreview = false
                return
            }
            Task.detached(priority: .utility) {
                let jpeg = Self.previewJPEG(image.upright(for: turn))
                await MainActor.run {
                    self?.isSendingPreview = false
                    if let jpeg { self?.camera?.addBannerPreviewFrame(jpeg) }
                }
            }
        }
    }

    nonisolated private static func previewJPEG(_ image: UIImage) -> Data? {
        let scale = previewLongEdge / max(image.size.width, image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return small.jpegData(compressionQuality: 0.4)
    }
}

struct ARViewContainer: UIViewRepresentable {
    let controller: BannerARController

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        controller.attach(view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

/// Banner design sheet: live preview over the form. Closing it re-renders the banner in the scene.
struct BannerDesignSheet: View {
    let session: BannerSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerPreview(design: session.design)
                    .padding()
                BannerDesignForm(design: session.design)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Banner Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear { session.controller.refreshDesign() }
    }
}
