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
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            preview
                .overlay(alignment: .topLeading) {
                    if let point = camera.focusIndicator {
                        FocusReticle()
                            .position(point)
                            .id(point.x + point.y)
                    }
                }
                .ignoresSafeArea()

            if flash {
                Color.white.opacity(0.6).ignoresSafeArea().allowsHitTesting(false)
            }

            if let countdown = camera.countdown {
                Text("\(countdown)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 10)
                    .transition(.scale)
            }

            VStack(spacing: 12) {
                topBar
                CameraSettingsBar(status: camera.status, send: camera.handle)
                overlays
                Spacer()
                ExposureControl(value: camera.exposureBias, send: camera.handle)
                ZoomChips(current: camera.zoom, minZoom: camera.minZoom, maxZoom: camera.maxZoom) {
                    camera.setZoom($0)
                }
                modePicker
                bottomBar
            }
            .padding(.horizontal, 20)
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

    @ViewBuilder
    private var preview: some View {
        #if DEBUG
        if DemoMode.isOn {
            Image(uiImage: DemoMode.sceneImage())
                .resizable()
                .scaledToFit()
                .overlay {
                    if camera.showsGrid {
                        GridLines().stroke(Color.white.opacity(0.45), lineWidth: 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            CameraPreview(camera: camera, showsGrid: camera.showsGrid)
        }
        #else
        CameraPreview(camera: camera, showsGrid: camera.showsGrid)
        #endif
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

    static var isDemo: Bool {
        #if DEBUG
        return DemoMode.isOn
        #else
        return false
        #endif
    }

    private static var demoOnboardingPage: Int {
        #if DEBUG
        if DemoMode.screen == "onboarding" { return 2 }
        #endif
        return 0
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

    private var topBar: some View {
        HStack {
            Label(remoteText, systemImage: remote.connectedRemotes > 0
                  ? "iphone.radiowaves.left.and.right" : "dot.radiowaves.left.and.right")
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(remote.connectedRemotes > 0 ? Color.green : Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5), in: Capsule())

            Spacer()

            if camera.isRecording {
                Text(Format.duration(camera.recordingSeconds))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red, in: Capsule())
            } else if camera.isIntervalRunning {
                IntervalBadge(nextShot: camera.nextIntervalShot)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5), in: Circle())
            }
            .accessibilityLabel(String(localized: "Settings"))

            Button {
                showPairing = true
            } label: {
                Image(systemName: "qrcode")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5), in: Circle())
            }
            .accessibilityLabel(String(localized: "Show pairing QR code"))
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(get: { camera.mode }, set: { camera.setMode($0) })) {
            ForEach(CaptureMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 220)
        .disabled(camera.isBusy)
    }

    private var bottomBar: some View {
        HStack {
            LastCaptureButton(thumbnail: camera.lastThumbnail) { showGallery = true }
            Spacer()
            ShutterButton(mode: camera.mode,
                          isRecording: camera.isBusy,
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
            .disabled(camera.isBusy)
            .accessibilityLabel(String(localized: "Switch camera"))
        }
    }

    private var remoteText: String {
        remote.connectedRemotes > 0
            ? String(localized: "\(remote.connectedRemotes) remote connected")
            : remote.bluetoothState
    }
}

/// Bottom-left thumbnail of the last capture, like the system Camera. Tapping opens the gallery.
private struct LastCaptureButton: View {
    let thumbnail: UIImage?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .id(thumbnail)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 52, height: 52)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.8), lineWidth: 1.5))
            .frame(width: 56, height: 56)
            .animation(.spring(duration: 0.35), value: thumbnail)
        }
        .accessibilityLabel(String(localized: "Open gallery"))
    }
}
