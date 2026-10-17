import AVFoundation
import CoreImage
import ImageIO
import Photos
import UIKit

/// Owns the capture session. UI state is published on the main thread;
/// session work runs on `sessionQueue`, sample buffers on `dataQueue`.
final class CameraController: NSObject, ObservableObject {
    // MARK: Published state (main thread)

    @Published private(set) var mode: CaptureMode = .photo
    @Published private(set) var isRecording = false
    @Published private(set) var recordingSeconds = 0
    @Published private(set) var timerSeconds = 0
    @Published private(set) var countdown: Int?
    @Published private(set) var zoom: Double = 1
    @Published private(set) var minZoom: Double = 1
    @Published private(set) var maxZoom: Double = 1
    @Published private(set) var position: CameraPosition = .back
    @Published private(set) var captureCount = 0
    @Published private(set) var flash: FlashMode = .off
    @Published private(set) var exposure: Double = 0
    @Published private(set) var burstCount = 1
    @Published private(set) var autoCapture: AutoCapture = .off
    @Published private(set) var intervalSeconds = 5
    @Published private(set) var isIntervalRunning = false
    @Published private(set) var faces = 0
    @Published private(set) var edgeWarning = false
    @Published private(set) var tilt: Int?
    /// Where focus was last set, in preview layer coordinates (for the focus square).
    @Published private(set) var focusIndicator: CGPoint?
    /// Short message shown over the viewfinder (e.g. "Best shot picked").
    @Published private(set) var toast: String?
    @Published var alertMessage: String?

    let shots = ShotStore()
    let settings = AppSettings.shared

    let session = AVCaptureSession()

    /// Called on the data queue with a small JPEG whenever `previewDemand` is true.
    var onPreviewFrame: ((Data) -> Void)?
    /// Called on main with a review-size JPEG of each photo the remote should see.
    var onReviewFrame: ((Data) -> Void)?

    var previewDemand: Bool {
        get { demandLock.withLock { _previewDemand } }
        set { demandLock.withLock { _previewDemand = newValue } }
    }

    var status: RemoteStatus {
        RemoteStatus(mode: mode,
                     isRecording: isRecording,
                     recordingSeconds: recordingSeconds,
                     timerSeconds: timerSeconds,
                     countdown: countdown,
                     zoom: zoom,
                     minZoom: minZoom,
                     maxZoom: maxZoom,
                     position: position,
                     captureCount: captureCount,
                     flash: flash,
                     exposure: exposure,
                     burstCount: burstCount,
                     autoCapture: autoCapture,
                     intervalSeconds: intervalSeconds,
                     isIntervalRunning: isIntervalRunning,
                     faces: faces,
                     edgeWarning: edgeWarning,
                     tilt: tilt)
    }

    // MARK: Private

    private let sessionQueue = DispatchQueue(label: "shutterlink.session")
    private let dataQueue = DispatchQueue(label: "shutterlink.data")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let ciContext = CIContext()
    /// Photo settings id -> burst id, read from the photo delegate.
    private let burstLock = NSLock()
    private var burstByPhotoID: [Int64: UUID] = [:]
    private let demandLock = NSLock()
    private var _previewDemand = false
    private let analyzer = SceneAnalyzer()
    private let clapDetector = ClapDetector()
    private let levelMonitor = LevelMonitor()
    private let voice = VoicePrompter()
    /// Read on the data queue to decide which detectors to run.
    private var detectionMode: AutoCapture {
        get { demandLock.withLock { _detectionMode } }
        set { demandLock.withLock { _detectionMode = newValue } }
    }
    private var _detectionMode: AutoCapture = .off

    // sessionQueue
    private var videoInput: AVCaptureDeviceInput?
    private var zoomBase: CGFloat = 1
    private var hasAudio = false
    private var didStart = false

    // dataQueue
    private var recorder: MovieRecorder?
    private var lastPreviewTime: CFTimeInterval = 0

    // main
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservations: [NSKeyValueObservation] = []
    private var countdownTimer: Timer?
    private var recordingTimer: Timer?
    private var intervalTimer: Timer?
    private var toastWork: DispatchWorkItem?
    private var focusResetWork: DispatchWorkItem?
    /// Consecutive analyzer passes with the trigger condition, and when the last auto shot fired.
    private var triggerStreak = 0
    private var lastAutoTrigger: Date = .distantPast
    /// Earliest time a hands-free trigger may fire again (keeps the shutter sound from re-triggering a clap).
    private var autoTriggerQuietUntil: Date = .distantPast
    /// Smile shutter re-arms only after someone stops smiling, so it doesn't fire continuously.
    private var smileArmed = true
    /// Bursts still waiting for photos: burst id -> (expected, received photo data).
    private var pendingBursts: [UUID: (expected: Int, received: [(Shot, Data)])] = [:]
    private var subjectAreaObserver: NSObjectProtocol?

    private static let previewLongEdge: CGFloat = 400
    private static let previewFPS: Double = 12
    private static let reviewLongEdge = 1024
    private static let burstSpacing: TimeInterval = 0.35
    private static let autoTriggerCooldown: TimeInterval = 4
    /// Hands-free triggers need time for the person to lower their hand / settle.
    private static let minimumAutoTimer = 3

    override init() {
        super.init()
        analyzer.onResult = { [weak self] result in self?.handleAnalysis(result) }
        clapDetector.onClap = { [weak self] in
            DispatchQueue.main.async { self?.autoTrigger() }
        }
        levelMonitor.onChange = { [weak self] value in self?.tilt = value }
    }

    // MARK: Lifecycle

    func start() {
        levelMonitor.start()
        Task {
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                await MainActor.run {
                    self.alertMessage = String(localized: "Camera access is required. Enable it in Settings > ShutterLink.")
                }
                return
            }
            let audioGranted = await AVCaptureDevice.requestAccess(for: .audio)
            _ = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            sessionQueue.async {
                guard !self.didStart else { return }
                self.didStart = true
                self.configureSession(includeAudio: audioGranted)
                self.session.startRunning()
                self.refreshRotationCoordinator()
            }
        }
    }

    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        sessionQueue.async { self.refreshRotationCoordinator() }
    }

    // MARK: Controls (call on main)

    func shutter() {
        if countdown != nil {
            cancelCountdown()
            return
        }
        if isRecording {
            stopRecording()
            return
        }
        if isIntervalRunning {
            stopInterval()
            return
        }
        startCountdown(seconds: timerSeconds)
    }

    private func startCountdown(seconds: Int) {
        guard seconds > 0 else {
            fire()
            return
        }
        countdown = seconds
        announce(seconds, isStart: true)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self, let remaining = self.countdown else {
                timer.invalidate()
                return
            }
            if remaining <= 1 {
                timer.invalidate()
                self.countdownTimer = nil
                self.countdown = nil
                self.fire()
            } else {
                self.countdown = remaining - 1
                self.announce(remaining - 1)
            }
        }
    }

    /// Voice and torch cues for each countdown second, so people far from the screen can follow it.
    private func announce(_ remaining: Int, isStart: Bool = false) {
        if settings.voiceCountdown {
            if remaining <= 5 {
                voice.speakCount(remaining)
            } else if isStart {
                voice.speakStarting(seconds: remaining)
            }
        }
        if settings.flashCountdown {
            pulseTorch(times: remaining <= 2 ? 2 : 1)
        }
    }

    /// Plays a spoken prompt so the group looks at the lens.
    func attention() {
        voice.speakAttention()
        if settings.flashCountdown { pulseTorch(times: 3) }
    }

    func setFlash(_ mode: FlashMode) {
        flash = mode
        applyTorch()
    }

    func setExposure(_ value: Double) {
        let clamped = min(max(value, RemoteOptions.exposureRange.lowerBound), RemoteOptions.exposureRange.upperBound)
        exposure = (clamped * 10).rounded() / 10
        let bias = Float(exposure)
        sessionQueue.async {
            guard let device = self.videoInput?.device else { return }
            let value = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(value)
                device.unlockForConfiguration()
            } catch {
                print("Exposure failed: \(error)")
            }
        }
    }

    func setBurst(_ count: Int) {
        burstCount = RemoteOptions.bursts.contains(count) ? count : 1
    }

    func setInterval(_ seconds: Int) {
        guard !isIntervalRunning else { return }
        intervalSeconds = RemoteOptions.intervals.contains(seconds) ? seconds : 5
    }

    func setAutoCapture(_ mode: AutoCapture) {
        autoCapture = mode
        detectionMode = mode
        triggerStreak = 0
        if mode == .clap, !hasAudio {
            alertMessage = String(localized: "Clap shutter needs microphone access. Enable it in Settings > ShutterLink.")
        }
        showToast(mode.hint)
    }

    /// Focus and expose at a point in the preview layer (tap on the camera screen).
    func focus(atLayerPoint point: CGPoint) {
        guard let layer = previewLayer else { return }
        focusIndicator = point
        focusDevice(at: layer.captureDevicePointConverted(fromLayerPoint: point))
    }

    /// Focus at a normalized point of the upright (unmirrored) preview image the remote sees.
    func focus(atImagePoint x: Double, _ y: Double) {
        guard let layer = previewLayer else { return }
        let videoRect = layer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        let imageX = position == .front ? 1 - x : x
        let point = CGPoint(x: videoRect.minX + CGFloat(imageX) * videoRect.width,
                            y: videoRect.minY + CGFloat(y) * videoRect.height)
        focus(atLayerPoint: point)
    }

    func setMode(_ newMode: CaptureMode) {
        guard newMode != mode, !isRecording, !isIntervalRunning else { return }
        cancelCountdown()
        mode = newMode
        applyTorch()
        sessionQueue.async {
            let preset: AVCaptureSession.Preset = newMode == .video ? .high : .photo
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(preset) {
                self.session.sessionPreset = preset
            }
            self.session.commitConfiguration()
            if let device = self.videoInput?.device {
                self.configurePhotoOutput(for: device)
                self.applyDeviceDefaults(device)
            }
        }
    }

    func setTimer(_ seconds: Int) {
        timerSeconds = min(max(seconds, 0), RemoteOptions.timers.last ?? 30)
    }

    func setZoom(_ value: Double) {
        let clamped = min(max(value, minZoom), maxZoom)
        zoom = clamped.rounded2
        sessionQueue.async {
            guard let device = self.videoInput?.device else { return }
            let factor = min(max(CGFloat(clamped) * self.zoomBase, device.minAvailableVideoZoomFactor),
                             device.maxAvailableVideoZoomFactor)
            do {
                try device.lockForConfiguration()
                device.ramp(toVideoZoomFactor: factor, withRate: 12)
                device.unlockForConfiguration()
            } catch {
                print("Zoom failed: \(error)")
            }
        }
    }

    func flipCamera() {
        guard !isRecording, !isIntervalRunning else { return }
        cancelCountdown()
        let target: CameraPosition = position == .back ? .front : .back
        sessionQueue.async {
            guard let device = Self.bestDevice(for: target),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { return }
            self.session.beginConfiguration()
            if let current = self.videoInput { self.session.removeInput(current) }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoInput = newInput
            } else if let current = self.videoInput {
                self.session.addInput(current)
            }
            self.session.commitConfiguration()

            guard let active = self.videoInput?.device else { return }
            self.configurePhotoOutput(for: active)
            self.applyDeviceDefaults(active)
            let newPosition: CameraPosition = active.position == .front ? .front : .back
            DispatchQueue.main.async {
                self.position = newPosition
                self.focusIndicator = nil
                self.setUpRotation(for: active)
                self.setExposure(self.exposure)
                self.applyTorch()
            }
        }
    }

    // MARK: Session configuration (sessionQueue)

    private func configureSession(includeAudio: Bool) {
        configureAudioSession(recording: includeAudio)
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = Self.bestDevice(for: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.alertMessage = String(localized: "No camera available on this device.") }
            return
        }
        session.addInput(input)
        videoInput = input

        if includeAudio,
           let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micInput) {
            session.addInput(micInput)
            hasAudio = true
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: dataQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if hasAudio {
            audioOutput.setSampleBufferDelegate(self, queue: dataQueue)
            if session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
            } else {
                hasAudio = false
            }
        }

        session.commitConfiguration()

        configurePhotoOutput(for: device)
        applyDeviceDefaults(device)
    }

    /// Route the voice countdown to the loud speaker (not the earpiece) and play it even in silent mode.
    private func configureAudioSession(recording: Bool) {
        session.automaticallyConfiguresApplicationAudioSession = false
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if recording {
                try audioSession.setCategory(.playAndRecord, mode: .videoRecording,
                                             options: [.defaultToSpeaker, .allowBluetoothA2DP])
            } else {
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
            try audioSession.setActive(true)
        } catch {
            print("Audio session failed: \(error)")
        }
    }

    private func configurePhotoOutput(for device: AVCaptureDevice) {
        let dimensions = device.activeFormat.supportedMaxPhotoDimensions
        if let largest = dimensions.max(by: { Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height) }) {
            photoOutput.maxPhotoDimensions = largest
        }
        photoOutput.maxPhotoQualityPrioritization = .quality
    }

    /// Normalizes zoom so that 1× is the wide lens even on virtual multi-camera devices.
    private func applyDeviceDefaults(_ device: AVCaptureDevice) {
        var base: CGFloat = 1
        if device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera,
           let firstSwitchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first {
            base = CGFloat(truncating: firstSwitchOver)
        }
        zoomBase = base

        let minFactor = device.minAvailableVideoZoomFactor
        let maxFactor = max(minFactor, min(device.maxAvailableVideoZoomFactor, base * 10))
        let initial = min(max(base, minFactor), maxFactor)

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = initial
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        } catch {
            print("Device configuration failed: \(error)")
        }

        observeSubjectArea(of: device)

        let minDisplay = Double(minFactor / base).rounded2
        let maxDisplay = Double(maxFactor / base).rounded2
        let current = Double(initial / base).rounded2
        DispatchQueue.main.async {
            self.minZoom = minDisplay
            self.maxZoom = maxDisplay
            self.zoom = current
        }
    }

    static func bestDevice(for position: CameraPosition) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInTrueDepthCamera, .builtInWideAngleCamera]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types,
                                                         mediaType: .video,
                                                         position: position == .back ? .back : .front)
        for type in types {
            if let device = discovery.devices.first(where: { $0.deviceType == type }) {
                return device
            }
        }
        return nil
    }

    // MARK: Rotation

    private func refreshRotationCoordinator() {
        guard let device = videoInput?.device else { return }
        DispatchQueue.main.async { self.setUpRotation(for: device) }
    }

    /// main thread
    private func setUpRotation(for device: AVCaptureDevice) {
        rotationObservations.removeAll()
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator

        applyPreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
        rotationObservations.append(
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                DispatchQueue.main.async { self?.applyPreviewRotation(angle) }
            }
        )
        rotationObservations.append(
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelCapture
                DispatchQueue.main.async { self?.applyDataOutputRotation(angle) }
            }
        )
    }

    private func applyPreviewRotation(_ angle: CGFloat) {
        guard let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    /// Rotates the sample buffers themselves so preview frames and recordings are upright.
    /// Skipped while recording, because the writer's dimensions are fixed.
    private func applyDataOutputRotation(_ angle: CGFloat) {
        guard !isRecording else { return }
        sessionQueue.async {
            guard let connection = self.videoOutput.connection(with: .video),
                  connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }

    // MARK: Capture

    private func fire() {
        let busyFor = mode == .photo ? Double(burstCount) * Self.burstSpacing : 0
        autoTriggerQuietUntil = Date().addingTimeInterval(2.5 + busyFor)
        switch mode {
        case .photo: captureBurst()
        case .video: startRecording()
        case .interval: startInterval()
        }
    }

    private func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdown = nil
    }

    /// Group shot: several frames in quick succession; the one with open eyes and smiles is marked best.
    private func captureBurst() {
        guard burstCount > 1 else {
            capturePhoto(burstID: nil)
            return
        }
        let id = UUID()
        pendingBursts[id] = (burstCount, [])
        for index in 0 ..< burstCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * Self.burstSpacing) {
                self.capturePhoto(burstID: id)
            }
        }
    }

    private func startInterval() {
        guard !isIntervalRunning else { return }
        isIntervalRunning = true
        recordingSeconds = 0
        capturePhoto(burstID: nil)
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.recordingSeconds += 1
        }
        intervalTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalSeconds), repeats: true) { [weak self] _ in
            self?.capturePhoto(burstID: nil)
        }
    }

    private func stopInterval() {
        intervalTimer?.invalidate()
        intervalTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        isIntervalRunning = false
    }

    private func capturePhoto(burstID: UUID?) {
        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture
        let flashMode: AVCaptureDevice.FlashMode
        switch flash {
        case .off: flashMode = .off
        case .auto: flashMode = .auto
        case .on: flashMode = .on
        }
        // Bursts and intervals skip the flash so frames stay evenly spaced.
        let useFlash = burstID == nil && mode == .photo
        sessionQueue.async {
            guard self.session.isRunning else { return }
            if let angle, let connection = self.photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            let settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }
            settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
            settings.photoQualityPrioritization = burstID == nil ? .balanced : .speed
            if useFlash, self.photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }
            if let burstID {
                self.burstLock.withLock { self.burstByPhotoID[settings.uniqueID] = burstID }
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        recordingSeconds = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.recordingSeconds += 1
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShutterLink-\(UUID().uuidString)")
            .appendingPathExtension("mov")
        sessionQueue.async {
            let audioSettings = self.hasAudio
                ? self.audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: Any]
                : nil
            self.dataQueue.async {
                do {
                    self.recorder = try MovieRecorder(url: url, audioSettings: audioSettings)
                } catch {
                    DispatchQueue.main.async {
                        self.alertMessage = String(localized: "Couldn't start recording: \(error.localizedDescription)")
                        self.finishRecordingUI()
                    }
                }
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        finishRecordingUI()
        if let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture {
            applyDataOutputRotation(angle)
        }
        // Same queue hop as startRecording (session -> data) so a fast stop can't overtake the start.
        sessionQueue.async {
            self.dataQueue.async {
                guard let recorder = self.recorder else { return }
                self.recorder = nil
                recorder.finish { [weak self] url in
                    guard let self else { return }
                    guard let url else {
                        DispatchQueue.main.async { self.alertMessage = String(localized: "Recording failed.") }
                        return
                    }
                    let store = self.shots
                    guard self.settings.saveToPhotos else {
                        store.addVideo(movingFrom: url)
                        DispatchQueue.main.async { self.captureCount += 1 }
                        return
                    }
                    self.saveToLibrary({ request in
                        request.addResource(with: .video, fileURL: url, options: nil)
                    }, cleanup: {
                        store.addVideo(movingFrom: url)
                    })
                }
            }
        }
    }

    private func finishRecordingUI() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
    }

    private func saveToLibrary(_ build: @escaping (PHAssetCreationRequest) -> Void, cleanup: (() -> Void)? = nil) {
        PHPhotoLibrary.shared().performChanges({
            build(PHAssetCreationRequest.forAsset())
        }) { success, error in
            cleanup?()
            DispatchQueue.main.async {
                if success {
                    self.captureCount += 1
                } else {
                    let reason = error?.localizedDescription ?? String(localized: "Check Photos access in Settings.")
                    self.alertMessage = String(localized: "Couldn't save to Photos. \(reason)")
                }
            }
        }
    }

    // MARK: Preview frames (dataQueue)

    private func emitPreviewFrameIfNeeded(_ sampleBuffer: CMSampleBuffer) {
        guard let handler = onPreviewFrame, previewDemand else { return }
        let now = CACurrentMediaTime()
        guard now - lastPreviewTime >= 1.0 / Self.previewFPS else { return }
        lastPreviewTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        let scale = Self.previewLongEdge / max(image.extent.width, image.extent.height)
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let jpeg = ciContext.jpegRepresentation(
                  of: image,
                  colorSpace: colorSpace,
                  options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.4]
              ) else { return }
        handler(jpeg)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let burstID = burstLock.withLock { burstByPhotoID.removeValue(forKey: photo.resolvedSettings.uniqueID) }
        if let error {
            DispatchQueue.main.async {
                self.alertMessage = String(localized: "Capture failed: \(error.localizedDescription)")
                if let burstID { self.burstPhotoFailed(burstID) }
            }
            return
        }
        guard let data = photo.fileDataRepresentation() else { return }
        DispatchQueue.main.async { self.handleCapturedPhoto(data, burstID: burstID) }
    }
}

#if DEBUG
// MARK: - Screenshot mode

extension CameraController {
    @MainActor
    func applyDemoState(screen: String) {
        faces = 5
        tilt = 0
        zoom = 1
        minZoom = 0.5
        maxZoom = 10
        burstCount = 5
        timerSeconds = 10
        autoCapture = .palm
        switch screen {
        case "countdown":
            countdown = 3
        case "main":
            toast = String(localized: "Best shot picked from \(burstCount) photos")
        default:
            break
        }
    }

    /// Fills the gallery with illustrated group shots.
    @MainActor
    func loadDemoShots() {
        shots.deleteAll()
        for burst in 0 ..< 3 {
            let burstID = UUID()
            for variant in [burst * 2 + 1, burst * 2, burst * 2 + 1] {
                let data = DemoMode.sceneJPEG(variant: variant)
                shots.addPhoto(data, burstID: burstID) { [weak self] shot in
                    if variant % 2 == 0 { self?.shots.markBest(shot.id, inBurst: burstID) }
                }
            }
        }
    }
}
#endif

// MARK: - Shots, bursts and review frames (main)

private extension CameraController {
    func handleCapturedPhoto(_ data: Data, burstID: UUID?) {
        if settings.saveToPhotos {
            saveToLibrary { request in
                request.addResource(with: .photo, data: data, options: nil)
            }
        } else {
            captureCount += 1
        }
        shots.addPhoto(data, burstID: burstID) { [weak self] shot in
            guard let self else { return }
            if let burstID {
                self.collectBurstPhoto(shot, data: data, burstID: burstID)
            } else {
                self.sendReview(of: data)
            }
        }
    }

    func burstPhotoFailed(_ burstID: UUID) {
        guard var burst = pendingBursts[burstID] else { return }
        burst.expected -= 1
        pendingBursts[burstID] = burst
        finishBurstIfComplete(burstID)
    }

    func collectBurstPhoto(_ shot: Shot, data: Data, burstID: UUID) {
        guard var burst = pendingBursts[burstID] else { return }
        burst.received.append((shot, data))
        pendingBursts[burstID] = burst
        finishBurstIfComplete(burstID)
    }

    func finishBurstIfComplete(_ burstID: UUID) {
        guard let burst = pendingBursts[burstID], burst.received.count >= burst.expected else { return }
        pendingBursts[burstID] = nil
        let candidates = burst.received
        guard !candidates.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let scored = candidates.map { ($0.0, $0.1, SceneAnalyzer.score(photoData: $0.1)) }
            // Ties go to the earliest frame.
            guard let best = scored.max(by: { $0.2 < $1.2 }) else { return }
            DispatchQueue.main.async {
                self.shots.markBest(best.0.id, inBurst: burstID)
                self.showToast(String(localized: "Best shot picked from \(candidates.count) photos"))
                self.sendReview(of: best.1)
            }
        }
    }

    func sendReview(of data: Data) {
        guard settings.sendPhotosToRemote, let onReviewFrame else { return }
        DispatchQueue.global(qos: .utility).async {
            guard let jpeg = ShotStore.thumbnail(fromImageData: data, maxPixel: Self.reviewLongEdge) else { return }
            DispatchQueue.main.async { onReviewFrame(jpeg) }
        }
    }
}

// MARK: - Hands-free triggers, toasts, focus and torch

extension CameraController {
    func showToast(_ message: String) {
        toastWork?.cancel()
        toast = message
        let work = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    fileprivate func handleAnalysis(_ result: SceneAnalyzer.Result) {
        if faces != result.faces { faces = result.faces }
        if edgeWarning != result.edgeWarning { edgeWarning = result.edgeWarning }

        let triggered: Bool
        let needed: Int
        switch autoCapture {
        case .palm:
            triggered = result.palmRaised
            needed = 3
        case .smile:
            if !result.everyoneSmiling { smileArmed = true }
            triggered = result.everyoneSmiling && smileArmed
            needed = 3
        case .off, .clap:
            triggered = false
            needed = .max
        }
        triggerStreak = triggered ? triggerStreak + 1 : 0
        if triggerStreak >= needed {
            triggerStreak = 0
            autoTrigger()
        }
    }

    /// Starts a shot from a hands-free trigger (palm, smile, clap).
    fileprivate func autoTrigger() {
        guard autoCapture != .off, countdown == nil, !isRecording, !isIntervalRunning,
              Date() > autoTriggerQuietUntil,
              Date().timeIntervalSince(lastAutoTrigger) > Self.autoTriggerCooldown else { return }
        lastAutoTrigger = Date()
        smileArmed = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        switch autoCapture {
        case .smile:
            // Everyone is already smiling: shoot now.
            fire()
        default:
            startCountdown(seconds: max(timerSeconds, Self.minimumAutoTimer))
        }
    }

    fileprivate func focusDevice(at devicePoint: CGPoint) {
        focusResetWork?.cancel()
        sessionQueue.async {
            guard let device = self.videoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                print("Focus failed: \(error)")
            }
        }
        let work = DispatchWorkItem { [weak self] in self?.focusIndicator = nil }
        focusResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    /// When the scene changes a lot, go back to continuous focus on the center.
    fileprivate func observeSubjectArea(of device: AVCaptureDevice) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let observer = self.subjectAreaObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            self.subjectAreaObserver = NotificationCenter.default.addObserver(
                forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: device, queue: .main
            ) { [weak self] _ in
                self?.resetFocus()
            }
        }
    }

    private func resetFocus() {
        sessionQueue.async {
            guard let device = self.videoInput?.device else { return }
            let center = CGPoint(x: 0.5, y: 0.5)
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusPointOfInterest = center
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = center
                }
                device.unlockForConfiguration()
            } catch {
                print("Focus reset failed: \(error)")
            }
        }
    }

    /// In video mode, "flash on" keeps the torch lit as a fill light.
    fileprivate func applyTorch() {
        let wantsTorch = mode == .video && flash == .on
        sessionQueue.async {
            guard let device = self.videoInput?.device, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                if wantsTorch {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                } else if device.torchMode != .off {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                print("Torch failed: \(error)")
            }
        }
    }

    /// Short torch blinks that people in front of the camera can see during a countdown.
    fileprivate func pulseTorch(times: Int) {
        guard !(mode == .video && flash == .on) else { return }
        sessionQueue.async {
            guard let device = self.videoInput?.device, device.hasTorch, device.isTorchAvailable else { return }
            for index in 0 ..< times {
                let start = Double(index) * 0.25
                self.sessionQueue.asyncAfter(deadline: .now() + start) { self.setTorch(device, on: true) }
                self.sessionQueue.asyncAfter(deadline: .now() + start + 0.12) { self.setTorch(device, on: false) }
            }
        }
    }

    private func setTorch(_ device: AVCaptureDevice, on: Bool) {
        guard device === videoInput?.device else { return }
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: 0.6)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch pulse failed: \(error)")
        }
    }
}

// MARK: - Sample buffers

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let detection = detectionMode
        if output === audioOutput {
            recorder?.appendAudio(sampleBuffer)
            if detection == .clap { clapDetector.process(sampleBuffer) }
            return
        }
        recorder?.appendVideo(sampleBuffer)
        emitPreviewFrameIfNeeded(sampleBuffer)
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            analyzer.submit(pixelBuffer, detectPalm: detection == .palm, detectSmiles: detection == .smile)
        }
    }
}
