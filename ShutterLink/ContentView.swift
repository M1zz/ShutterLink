import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        CameraScreen(model: model, camera: model.camera, remote: model.remote,
                     settings: model.camera.settings, shots: model.camera.shots)
            .onAppear {
                // The camera sits on a tripod; never let the screen lock.
                UIApplication.shared.isIdleTimerDisabled = true
            }
            // Ask for camera access after the first-launch guide, not on top of it.
            // (@Published emits its current value on subscribe, so this also covers later launches.)
            .onReceive(model.camera.settings.$hasSeenOnboarding) { seen in
                if seen, !CameraScreen.isDemo { model.start() }
            }
    }
}

private struct CameraScreen: View {
    let model: AppModel
    @ObservedObject var camera: CameraController
    @ObservedObject var remote: RemotePeripheral
    @ObservedObject var settings: AppSettings
    @ObservedObject var shots: ShotStore
    @State private var showPairing = false
    @State private var showSettings = false
    @State private var showGallery = false
    @State private var showExposure = false
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if Self.isDemo {
                #if DEBUG
                Image(uiImage: DemoMode.sceneImage())
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                #endif
            } else {
                CameraPreview(camera: camera)
                    .ignoresSafeArea()
            }

            if settings.showGrid {
                GridOverlay().ignoresSafeArea()
            }

            if let point = camera.focusIndicator {
                FocusSquare()
                    .id(point.x + point.y)
                    .position(point)
                    .ignoresSafeArea()
            }

            if flash {
                Color.white.opacity(0.6).ignoresSafeArea().allowsHitTesting(false)
            }

            if let countdown = camera.countdown {
                CountdownText(value: countdown)
                    .transition(.scale)
            }

            VStack(spacing: 12) {
                topBar
                overlays
                Spacer()
                if showExposure {
                    ExposureSlider(value: camera.exposure) { camera.setExposure($0) }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                ZoomChips(current: camera.zoom, minZoom: camera.minZoom, maxZoom: camera.maxZoom) {
                    camera.setZoom($0)
                }
                toolsRow
                modePicker
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: camera.toast)
        .sheet(isPresented: $showPairing) {
            PairingSheet(url: model.invocationURL, code: model.sessionCode, remote: remote)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .fullScreenCover(isPresented: $showGallery) {
            GalleryView(store: shots)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !settings.hasSeenOnboarding },
            set: { if !$0 { settings.hasSeenOnboarding = true } }
        )) {
            OnboardingView(startPage: Self.demoOnboardingPage) { settings.hasSeenOnboarding = true }
        }
        .alert("ShutterLink", isPresented: Binding(
            get: { camera.alertMessage != nil },
            set: { if !$0 { camera.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(camera.alertMessage ?? "")
        }
        .onChange(of: camera.captureCount) { _, _ in
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeOut(duration: 0.3)) { flash = false }
            }
        }
        .onChange(of: remote.connectedRemotes) { oldValue, newValue in
            // Close the QR sheet automatically once a remote pairs.
            if newValue > oldValue { showPairing = false }
        }
        .onAppear(perform: setUpDemo)
    }

    static var isDemo: Bool {
        #if DEBUG
        return DemoMode.isOn
        #else
        return false
        #endif
    }

    private func setUpDemo() {
        #if DEBUG
        guard let screen = DemoMode.screen else { return }
        camera.applyDemoState(screen: screen)
        remote.applyDemo(connected: screen == "pairing" ? 0 : 1)
        switch screen {
        case "pairing": showPairing = true
        case "gallery":
            camera.loadDemoShots()
            showGallery = true
        default: break
        }
        #endif
    }

    private static var demoOnboardingPage: Int {
        #if DEBUG
        if DemoMode.screen == "onboarding" { return 2 }
        #endif
        return 0
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Label(remoteText, systemImage: remote.connectedRemotes > 0
                  ? "iphone.radiowaves.left.and.right" : "dot.radiowaves.left.and.right")
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(remote.connectedRemotes > 0 ? Color.green : Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5), in: Capsule())

            Spacer(minLength: 0)

            if camera.isRecording || camera.isIntervalRunning {
                Text(Format.duration(camera.recordingSeconds))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(camera.isIntervalRunning ? Color.black : Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(camera.isIntervalRunning ? Color.yellow : Color.red, in: Capsule())
            }

            Spacer(minLength: 0)

            roundButton("gearshape.fill", label: String(localized: "Settings")) { showSettings = true }
            roundButton("qrcode", label: String(localized: "Show pairing QR code")) { showPairing = true }
        }
    }

    private var overlays: some View {
        VStack(spacing: 8) {
            if settings.showLevel {
                LevelIndicator(tilt: camera.tilt)
            }
            if settings.showFaceCount {
                SceneBadges(faces: camera.faces, edgeWarning: camera.edgeWarning, autoCapture: camera.autoCapture)
            }
            if let toast = camera.toast {
                ToastView(message: toast)
            }
        }
    }

    private var toolsRow: some View {
        HStack(spacing: 8) {
            TimerButton(seconds: camera.timerSeconds) { camera.setTimer($0) }
            FlashButton(mode: camera.flash) { camera.setFlash($0) }
            switch camera.mode {
            case .photo:
                BurstButton(count: camera.burstCount) { camera.setBurst($0) }
            case .interval:
                IntervalButton(seconds: camera.intervalSeconds) { camera.setInterval($0) }
                    .disabled(camera.isIntervalRunning)
            case .video:
                EmptyView()
            }
            AutoCaptureButton(mode: camera.autoCapture) { camera.setAutoCapture($0) }
            ExposureButton(value: camera.exposure, isExpanded: $showExposure)
            Button {
                camera.attention()
            } label: {
                ToolChip(systemImage: "megaphone.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Ask everyone to look at the camera"))
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(get: { camera.mode }, set: { camera.setMode($0) })) {
            ForEach(CaptureMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
        .disabled(camera.isRecording || camera.isIntervalRunning)
    }

    private var bottomBar: some View {
        HStack {
            Button {
                showGallery = true
            } label: {
                GalleryThumbnail(store: shots)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Open gallery"))

            Spacer()
            ShutterButton(mode: camera.mode,
                          isRecording: camera.isRecording || camera.isIntervalRunning,
                          isCountingDown: camera.countdown != nil) {
                camera.shutter()
            }
            Spacer()
            Button {
                camera.flipCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.black.opacity(0.4), in: Circle())
            }
            .disabled(camera.isRecording || camera.isIntervalRunning)
            .accessibilityLabel(String(localized: "Switch camera"))
        }
    }

    private func roundButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.5), in: Circle())
        }
        .accessibilityLabel(label)
    }

    private var remoteText: String {
        remote.connectedRemotes > 0
            ? String(localized: "\(remote.connectedRemotes) remote connected")
            : remote.bluetoothState
    }
}

/// Latest shot in the bottom-left corner, like the system Camera app.
private struct GalleryThumbnail: View {
    @ObservedObject var store: ShotStore

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.12))
            if let shot = store.shots.first,
               let image = UIImage(contentsOfFile: store.thumbnailURL(for: shot).path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.6), lineWidth: 1))
    }
}
