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
    @Published var alertMessage: String?

    let session = AVCaptureSession()

    /// Called on the data queue with a small JPEG whenever `previewDemand` is true.
    var onPreviewFrame: ((Data) -> Void)?

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
                     captureCount: captureCount)
    }

    // MARK: Private

    private let sessionQueue = DispatchQueue(label: "shutterlink.session")
    private let dataQueue = DispatchQueue(label: "shutterlink.data")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let ciContext = CIContext()
    private let demandLock = NSLock()
    private var _previewDemand = false

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

    private static let previewLongEdge: CGFloat = 400
    private static let previewFPS: Double = 12

    // MARK: Lifecycle

    func start() {
        Task {
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                await MainActor.run {
                    self.alertMessage = "Camera access is required. Enable it in Settings > ShutterLink."
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
        guard timerSeconds > 0 else {
            fire()
            return
        }
        countdown = timerSeconds
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
            }
        }
    }

    func setMode(_ newMode: CaptureMode) {
        guard newMode != mode, !isRecording else { return }
        cancelCountdown()
        mode = newMode
        sessionQueue.async {
            let preset: AVCaptureSession.Preset = newMode == .photo ? .photo : .high
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
        timerSeconds = min(max(seconds, 0), 30)
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
        guard !isRecording else { return }
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
                self.setUpRotation(for: active)
            }
        }
    }

    // MARK: Session configuration (sessionQueue)

    private func configureSession(includeAudio: Bool) {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = Self.bestDevice(for: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.alertMessage = "No camera available on this device." }
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
            device.unlockForConfiguration()
        } catch {
            print("Device configuration failed: \(error)")
        }

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
        switch mode {
        case .photo: capturePhoto()
        case .video: startRecording()
        }
    }

    private func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdown = nil
    }

    private func capturePhoto() {
        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture
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
            settings.photoQualityPrioritization = .balanced
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
                        self.alertMessage = "Couldn't start recording: \(error.localizedDescription)"
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
                        DispatchQueue.main.async { self.alertMessage = "Recording failed." }
                        return
                    }
                    self.saveToLibrary({ request in
                        request.addResource(with: .video, fileURL: url, options: nil)
                    }, cleanup: {
                        try? FileManager.default.removeItem(at: url)
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
                    self.alertMessage = "Couldn't save to Photos. \(error?.localizedDescription ?? "Check Photos access in Settings.")"
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
        if let error {
            DispatchQueue.main.async { self.alertMessage = "Capture failed: \(error.localizedDescription)" }
            return
        }
        guard let data = photo.fileDataRepresentation() else { return }
        saveToLibrary { request in
            request.addResource(with: .photo, data: data, options: nil)
        }
    }
}

// MARK: - Sample buffers

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === audioOutput {
            recorder?.appendAudio(sampleBuffer)
            return
        }
        recorder?.appendVideo(sampleBuffer)
        emitPreviewFrameIfNeeded(sampleBuffer)
    }
}
