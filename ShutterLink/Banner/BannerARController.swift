import AVFoundation
import ARKit
import RealityKit
import SwiftUI
import Combine

/// Owns the ARView, session configuration, banner placement and capture.
@Observable
@MainActor
final class BannerARController: NSObject, ARSessionDelegate {
    // State observed by SwiftUI
    var isPlaced = false
    var status = String(localized: "Tap the floor or a wall to place the banner")
    /// Off by default: the banner always covers people, so nobody seems to poke through it.
    /// On, ARKit's people depth lets someone standing in front of the banner show over it — but its depth
    /// guess is rough, so people just behind the banner can bleed through too.
    var occlusionEnabled = false
    /// Height of the banner's centre above the tapped floor point (metres).
    var holdHeight: Float = 1.15
    /// Turn away from facing the camera, in degrees (the rotation gesture changes it too).
    private(set) var turnDegrees: Float = 0
    /// Size relative to the designed width (the pinch gesture changes it too).
    private(set) var sizeScale: Float = 1
    /// While the position panel is open, taps don't move the banner somewhere else.
    var isAdjusting = false
    /// Placed on a floor, so the height control applies.
    var isOnFloor: Bool { groundPoint != nil }
    var widthMeters: Float { design.widthMeters * sizeScale }
    /// JPEG of each snapshot, handed to the camera so it lands in Photos and the gallery.
    @ObservationIgnored var onCapture: ((Data) -> Void)?
    /// Every AR camera frame (sideways, as the sensor delivers it), for people counting and hands-free triggers.
    @ObservationIgnored var onFrame: ((CVPixelBuffer) -> Void)?
    /// Microphone buffers, for the clap shutter. Called off the main thread.
    @ObservationIgnored nonisolated(unsafe) var onAudio: ((CMSampleBuffer) -> Void)?

    private(set) var arView: ARView?
    private var anchor: AnchorEntity?
    @ObservationIgnored private var sceneUpdates: Cancellable?
    @ObservationIgnored private var clothClock: Float = 0
    @ObservationIgnored private var lastFlutter: Float = 0
    /// Re-shaping the cloth every rendered frame is wasted work; this is smooth enough for a breeze.
    private static let flutterInterval: Float = 1 / 24
    private var banner: BannerEntity?
    private let design: BannerDesign
    private var groundPoint: SIMD3<Float>?   // set when placed on a horizontal plane
    /// Yaw that faces the camera, set on placement and by "Face Me"; `turnDegrees` is relative to it.
    private var facingYaw: Float = 0
    /// Installed once per AR view; re-placing the banner reuses them.
    @ObservationIgnored private var gesturesInstalled = false

    static let sizeRange: ClosedRange<Float> = 0.4 ... 2
    static let turnRange: ClosedRange<Float> = -90 ... 90

    init(design: BannerDesign) {
        self.design = design
        super.init()
    }

    // MARK: Session

    func attach(_ view: ARView) {
        arView = view
        view.session.delegate = self
        view.automaticallyConfigureSession = false
        view.environment.sceneUnderstanding.options = []
        view.renderOptions.remove(.disableGroundingShadows)
        runSession()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)

        sceneUpdates = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated { self?.advanceCloth(by: Float(event.deltaTime)) }
        }
    }

    private func advanceCloth(by delta: Float) {
        clothClock += delta
        guard isPlaced, let banner, clothClock - lastFlutter >= Self.flutterInterval else { return }
        lastFlutter = clothClock
        banner.flutter(at: clothClock)
    }

    func runSession() {
        guard let arView else { return }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        config.isLightEstimationEnabled = true
        config.providesAudioData = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        if occlusionEnabled,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        arView.session.run(config, options: [])
    }

    func setOcclusion(_ enabled: Bool) {
        occlusionEnabled = enabled
        runSession()
    }

    // MARK: Placement

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }
        let point = gesture.location(in: arView)

        // Ignore taps on the banner itself (those are for gestures), and any tap while adjusting.
        if isPlaced, isAdjusting || arView.entity(at: point) is BannerEntity { return }

        if let hit = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any).first {
            place(at: hit)
        } else {
            placeInFrontOfCamera()
        }
    }

    private func place(at hit: ARRaycastResult) {
        guard let arView else { return }
        let hitPosition = SIMD3<Float>(hit.worldTransform.columns.3.x,
                                       hit.worldTransform.columns.3.y,
                                       hit.worldTransform.columns.3.z)
        let camera = arView.cameraTransform.translation

        var position = hitPosition
        if hit.targetAlignment == .vertical {
            // Flat against the wall, nudged out so it doesn't z-fight.
            let toCamera = simd_normalize(camera - hitPosition)
            position += toCamera * 0.02
            groundPoint = nil
        } else {
            // On the floor: raise it to "hand-held" height.
            position.y += holdHeight
            groundPoint = hitPosition
        }
        install(at: position, facing: camera)
    }

    private func placeInFrontOfCamera() {
        guard let arView else { return }
        let cam = arView.cameraTransform
        var forward = -SIMD3<Float>(cam.matrix.columns.2.x, 0, cam.matrix.columns.2.z)
        if simd_length(forward) < 0.001 { forward = [0, 0, -1] }
        forward = simd_normalize(forward)
        let position = cam.translation + forward * 3.0
        groundPoint = nil
        install(at: position, facing: cam.translation)
    }

    private func install(at position: SIMD3<Float>, facing camera: SIMD3<Float>) {
        guard let arView else { return }
        anchor?.removeFromParent()

        do {
            let texture = try BannerRenderer.renderTexture(design)
            let entity: BannerEntity
            if let existing = banner {
                entity = existing
                try entity.rebuild(design: design, texture: texture)
            } else {
                entity = try BannerEntity(design: design, texture: texture)
                banner = entity
            }

            let newAnchor = AnchorEntity(world: position)
            newAnchor.addChild(entity)
            entity.position = .zero
            facingYaw = Self.yawAngle(from: position, toward: camera)
            turnDegrees = 0
            entity.orientation = simd_quatf(angle: facingYaw, axis: [0, 1, 0])
            entity.scale = SIMD3(repeating: sizeScale)
            arView.scene.addAnchor(newAnchor)
            if !gesturesInstalled {
                gesturesInstalled = true
                for gesture in arView.installGestures([.translation, .rotation, .scale], for: entity) {
                    gesture.addTarget(self, action: #selector(handleEntityGesture(_:)))
                }
            }
            anchor = newAnchor
            isPlaced = true
            status = String(localized: "Drag the banner to move it, or use Adjust Position below.")
        } catch {
            status = String(localized: "Couldn't create the banner: \(error.localizedDescription)")
        }
    }

    /// Re-render texture / material after the design changed.
    func refreshDesign() {
        guard let banner else { return }
        do {
            let texture = try BannerRenderer.renderTexture(design)
            try banner.rebuild(design: design, texture: texture)
        } catch {
            status = String(localized: "Couldn't update the design.")
        }
    }

    func updateHoldHeight(_ height: Float) {
        holdHeight = height
        guard let anchor, let ground = groundPoint else { return }
        anchor.position = [ground.x, ground.y + height, ground.z]
    }

    func faceCamera() {
        guard let arView, let banner else { return }
        facingYaw = Self.yawAngle(from: banner.position(relativeTo: nil), toward: arView.cameraTransform.translation)
        setTurn(0)
    }

    func setTurn(_ degrees: Float) {
        turnDegrees = min(max(degrees, Self.turnRange.lowerBound), Self.turnRange.upperBound)
        banner?.orientation = simd_quatf(angle: facingYaw + turnDegrees * .pi / 180, axis: [0, 1, 0])
    }

    func setSize(_ scale: Float) {
        sizeScale = min(max(scale, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
        banner?.scale = SIMD3(repeating: sizeScale)
    }

    /// Slides the banner over the floor relative to the camera's view: `right` across, `away` farther from the camera.
    func nudge(right: Float, away: Float) {
        guard let arView, let anchor else { return }
        let m = arView.cameraTransform.matrix
        var across = SIMD3<Float>(m.columns.0.x, 0, m.columns.0.z)
        var ahead = -SIMD3<Float>(m.columns.2.x, 0, m.columns.2.z)
        guard simd_length(across) > 0.001, simd_length(ahead) > 0.001 else { return }
        across = simd_normalize(across)
        ahead = simd_normalize(ahead)
        let delta = across * right + ahead * away
        anchor.position += delta
        if let ground = groundPoint { groundPoint = ground + delta }
    }

    /// Keeps the panel's sliders in step with the on-banner rotate and pinch gestures.
    @objc private func handleEntityGesture(_ gesture: UIGestureRecognizer) {
        guard let banner else { return }
        let q = banner.orientation
        var turn = (2 * atan2(q.imag.y, q.real) - facingYaw) * 180 / .pi
        turn = remainder(turn, 360)
        if turn != turnDegrees { turnDegrees = turn }
        let scale = banner.scale.x
        if scale < Self.sizeRange.lowerBound || scale > Self.sizeRange.upperBound {
            setSize(scale)
        } else if scale != sizeScale {
            sizeScale = scale
        }
    }

    func reset() {
        anchor?.removeFromParent()
        anchor = nil
        groundPoint = nil
        isPlaced = false
        isAdjusting = false
        turnDegrees = 0
        sizeScale = 1
        status = String(localized: "Tap the floor or a wall to place the banner")
    }

    private static func yawAngle(from position: SIMD3<Float>, toward camera: SIMD3<Float>) -> Float {
        let d = camera - position
        return atan2(d.x, d.z) // +Z face rotates to point at the camera
    }

    // MARK: Capture

    func capture() {
        guard let arView else { return }
        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let self, let image else { return }
            Task { @MainActor in
                // ShutterLink's camera saves it like any other shot: Photos, the gallery, a copy to the remote.
                if let data = image.jpegData(compressionQuality: 0.92) {
                    self.onCapture?(data)
                }
            }
        }
    }

    /// Stops ARKit so the regular capture session can take the camera back. The next ARView starts fresh.
    func pause() {
        sceneUpdates?.cancel()
        sceneUpdates = nil
        arView?.session.pause()
        reset()
        arView = nil
        gesturesInstalled = false
    }

    // MARK: ARSessionDelegate

    nonisolated func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
        onAudio?(audioSampleBuffer)
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let buffer = frame.capturedImage
        // ARSession delivers on the main queue (no delegateQueue set).
        MainActor.assumeIsolated { onFrame?(buffer) }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in self.status = String(localized: "Couldn't show the banner: \(error.localizedDescription)") }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in self.status = String(localized: "The banner paused for a moment") }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in self.runSession() }
    }
}
