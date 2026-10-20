import ARKit
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
    /// Banner mode swaps the viewfinder for the AR scene in place; the design survives leaving the mode.
    @State private var banner = BannerSession()
    @State private var showBannerDesign = false
    @State private var showBannerHint = true
    @State private var showExposure = false
    /// Shooting options stay folded behind one button until asked for.
    @State private var showOptions = false
    @State private var showZoomPresets = false
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Top bar, a 3:4 viewfinder with its overlays inside, then mode tabs and the shutter — nothing straddles the frame edge.
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                viewfinder
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .top) { topOverlays.padding(.top, 10).padding(.horizontal, 12) }
                    .overlay(alignment: .bottom) { bottomOverlays.padding(.bottom, 10).padding(.horizontal, 16) }
                    .overlay { countdownText }
                    .clipped()
                if isAdjustingBanner {
                    // Positioning takes the shutter's place, so the panel never covers the banner it moves.
                    Spacer(minLength: 0)
                    BannerAdjustPanel(controller: banner.controller)
                        .padding(.horizontal, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    Spacer(minLength: 0)
                } else {
                    // Mode tabs hug the viewfinder like the system Camera; the shutter row centres in what's left.
                    modeSwitcher
                        .padding(.top, 10)
                    Spacer(minLength: 4)
                    bottomBar
                        .padding(.horizontal, 24)
                    Spacer(minLength: 4)
                }
            }

            if flash {
                Color.white.opacity(0.6).ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: camera.toast)
        .animation(.easeInOut(duration: 0.2), value: showExposure)
        .animation(.easeInOut(duration: 0.2), value: showOptions)
        .animation(.easeInOut(duration: 0.2), value: showZoomPresets)
        .animation(.easeInOut(duration: 0.2), value: camera.mode)
        .animation(.easeInOut(duration: 0.2), value: showBannerHint)
        .animation(.easeInOut(duration: 0.2), value: banner.controller.isAdjusting)
        .sheet(isPresented: $showPairing) {
            PairingSheet(url: model.invocationURL, code: model.sessionCode, remote: remote)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $showBannerDesign) {
            BannerDesignSheet(session: banner)
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
        .task(id: banner.controller.isPlaced) {
            // Placing the banner swaps the hint for the gesture tips, which fade after a few seconds.
            showBannerHint = true
            guard banner.controller.isPlaced else { return }
            try? await Task.sleep(for: .seconds(4))
            showBannerHint = false
        }
        .onAppear {
            banner.connect(camera)
            setUpDemo()
        }
    }

    private var bannerMode: Bool { camera.mode == .banner }

    // MARK: Viewfinder

    @ViewBuilder
    private var viewfinder: some View {
        if bannerMode {
            bannerViewfinder
        } else {
            cameraViewfinder
                .overlay(alignment: .topLeading) {
                    if let point = camera.focusIndicator {
                        FocusReticle()
                            .position(point)
                            .id(point.x + point.y)
                    }
                }
        }
    }

    @ViewBuilder
    private var cameraViewfinder: some View {
        #if DEBUG
        if DemoMode.isOn {
            demoScene
                .overlay {
                    if camera.showsGrid {
                        GridLines().stroke(Color.white.opacity(0.45), lineWidth: 1)
                    }
                }
        } else {
            CameraPreview(camera: camera, showsGrid: camera.showsGrid)
        }
        #else
        CameraPreview(camera: camera, showsGrid: camera.showsGrid)
        #endif
    }

    @ViewBuilder
    private var bannerViewfinder: some View {
        #if DEBUG
        if DemoMode.screen == "cloth" {
            BannerClothPreview(design: banner.design)
        } else if DemoMode.isOn {
            demoScene
                .overlay(alignment: .center) {
                    BannerPreview(design: banner.design)
                        .padding(.horizontal, 24)
                        .offset(y: 110)
                }
        } else {
            arView
        }
        #else
        arView
        #endif
    }

    @ViewBuilder
    private var arView: some View {
        if banner.isRunning {
            ARViewContainer(controller: banner.controller)
                .overlay {
                    if camera.showsGrid {
                        GridLines().stroke(Color.white.opacity(0.45), lineWidth: 1).allowsHitTesting(false)
                    }
                }
        } else {
            Color.black
        }
    }

    #if DEBUG
    private var demoScene: some View {
        Image(uiImage: DemoMode.sceneImage())
            .resizable()
            .scaledToFill()
    }
    #endif

    @ViewBuilder
    private var countdownText: some View {
        if let countdown = camera.countdown {
            Text("\(countdown)")
                .font(.system(size: 140, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 10)
                .transition(.scale)
                .allowsHitTesting(false)
        }
    }

    /// Options bar, then status: people count / level in camera mode, the placement hint in banner mode.
    private var topOverlays: some View {
        VStack(spacing: 8) {
            if showOptions {
                Group {
                    if bannerMode { bannerControlsBar } else { controlsBar }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(alignment: .top, spacing: 8) {
                if settings.showFaceCount {
                    // The hands-free mode already shows in the controls bar.
                    SceneBadges(faces: camera.faces, edgeWarning: camera.edgeWarning, autoCapture: .off)
                }
                // Only speak up when the phone is off level.
                if settings.showLevel, let tilt = camera.tilt, abs(tilt) > 1 {
                    LevelIndicator(tilt: tilt)
                        .frame(height: 36)
                }
            }
            if let toast = camera.toast {
                ToastView(message: toast)
            } else if bannerMode, showBannerHint, Self.demoScreen?.hasPrefix("banner") != true {
                ToastView(message: banner.controller.status)
            }
        }
    }

    @ViewBuilder
    private var bottomOverlays: some View {
        if bannerMode {
            if bannerPlaced {
                if !isAdjustingBanner {
                    Button {
                        banner.controller.isAdjusting = true
                    } label: {
                        Label("Adjust Position", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            VStack(spacing: 8) {
                if showExposure {
                    ExposureControl(value: camera.exposureBias, send: camera.handle)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                zoomControl
            }
        }
    }

    private var isAdjustingBanner: Bool {
        bannerMode && bannerPlaced && (banner.controller.isAdjusting || Self.demoScreen == "bannerAdjust")
    }

    private var bannerPlaced: Bool {
        banner.controller.isPlaced || Self.demoScreen?.hasPrefix("banner") == true
    }

    private static var demoScreen: String? {
        #if DEBUG
        return DemoMode.screen
        #else
        return nil
        #endif
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
        case "cloth":
            camera.setMode(.banner)
        case "banner", "bannerDesign", "bannerAdjust":
            camera.setMode(.banner)
            camera.applyDemoState(screen: screen) // switching modes clears the people count
            showBannerDesign = screen == "bannerDesign"
        default: break
        }
        if ProcessInfo.processInfo.arguments.contains("-showOptions") { showOptions = true }
        #endif
    }

    // MARK: Bars

    private var topBar: some View {
        HStack(spacing: 12) {
            // One symbol for the remote: green when connected. Tapping it shows the pairing QR.
            Button {
                showPairing = true
            } label: {
                Image(systemName: remote.connectedRemotes > 0 ? "iphone.radiowaves.left.and.right" : "qrcode")
                    .foregroundStyle(remote.connectedRemotes > 0 ? Color.green : Color.white)
                    .modifier(RoundIcon())
            }
            .accessibilityLabel(remoteText)
            .accessibilityHint(String(localized: "Show pairing QR code"))

            Spacer(minLength: 0)

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

            Spacer(minLength: 0)

            if bannerMode {
                Button {
                    showBannerDesign = true
                } label: {
                    Image(systemName: "paintbrush.pointed.fill")
                        .foregroundStyle(.white)
                        .modifier(RoundIcon())
                }
                .accessibilityLabel(String(localized: "Banner Design"))
            }

            // Yellow while any option is changed from its default, so a folded timer or burst isn't forgotten.
            Button {
                showOptions.toggle()
                if !showOptions { showExposure = false }
            } label: {
                Image(systemName: showOptions ? "chevron.up" : "slider.horizontal.3")
                    .foregroundStyle(hasActiveOptions ? Color.yellow : Color.white)
                    .modifier(RoundIcon())
            }
            .accessibilityLabel(String(localized: "Shooting options"))
        }
    }

    private var hasActiveOptions: Bool {
        let status = camera.status
        let shared = status.timerSeconds > 0 || status.autoCapture != .off || status.showsGrid
        guard status.mode.usesCaptureSession else { return shared || banner.controller.occlusionEnabled }
        return shared || status.flash != .off || status.burstCount > 1 || status.intervalSeconds > 0
            || abs(status.exposureBias) > 0.01
    }

    /// A single chip with the current zoom; tapping it shows the presets, picking one folds them again.
    @ViewBuilder
    private var zoomControl: some View {
        if showZoomPresets {
            ZoomChips(current: camera.zoom, minZoom: camera.minZoom, maxZoom: camera.maxZoom) {
                camera.setZoom($0)
                showZoomPresets = false
            }
        } else {
            Button {
                showZoomPresets = true
            } label: {
                Text(Format.zoom(camera.zoom))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(abs(camera.zoom - 1) < 0.05 ? Color.white : Color.yellow)
                    .frame(minWidth: 44, minHeight: 36)
                    .background(Color.black.opacity(0.45), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Zoom"))
            .accessibilityValue(Format.zoom(camera.zoom))
        }
    }

    /// Icon-only shooting controls, like the system Camera. Grid, "look at the camera" and Settings sit in the ⋯ menu,
    /// exposure opens on demand.
    private var controlsBar: some View {
        let status = camera.status
        return HStack(spacing: 2) {
            FlashButton(mode: status.flash, isAvailable: status.flashAvailable) {
                camera.handle(.setFlash(status.flash.next))
            }
            TimerButton(seconds: status.timerSeconds) { camera.handle(.setTimer(seconds: $0)) }
            DriveMenu(burstCount: status.burstCount, intervalSeconds: status.intervalSeconds, send: camera.handle)
                .disabled(status.isBusy || status.mode != .photo)
            AutoCaptureMenu(mode: status.autoCapture) { camera.handle(.setAutoCapture($0)) }
                .disabled(status.isBusy)
            SettingButton(systemImage: "plusminus.circle", title: String(localized: "Exposure"),
                          isOn: showExposure || abs(status.exposureBias) > 0.01) {
                showExposure.toggle()
            }
            .accessibilityLabel(String(localized: "Exposure"))
            .accessibilityValue(Format.exposure(status.exposureBias))
            moreMenu
        }
        .modifier(OptionsBarStyle())
    }

    /// Explains the trade-off, since "on" lets people near the banner show through it.
    private func showToastForOcclusion(_ isOn: Bool) {
        camera.showToast(isOn
            ? String(localized: "People standing in front of the banner now show over it.")
            : String(localized: "The banner stays in front of everyone."))
    }

    /// Banner mode keeps the camera's timer and hands-free shutter, and swaps flash, burst and exposure
    /// (which need the capture session) for people occlusion, turn-to-face and start over.
    private var bannerControlsBar: some View {
        let status = camera.status
        let controller = banner.controller
        return HStack(spacing: 2) {
            TimerButton(seconds: status.timerSeconds) { camera.handle(.setTimer(seconds: $0)) }
            AutoCaptureMenu(mode: status.autoCapture) { camera.handle(.setAutoCapture($0)) }
            SettingButton(systemImage: "person.crop.rectangle", title: String(localized: "Show people in front"),
                          isOn: controller.occlusionEnabled) {
                controller.setOcclusion(!controller.occlusionEnabled)
                showToastForOcclusion(controller.occlusionEnabled)
            }
            .accessibilityLabel(String(localized: "Show people in front"))
            .accessibilityValue(controller.occlusionEnabled ? String(localized: "On") : String(localized: "Off"))
            SettingButton(systemImage: "arrow.counterclockwise", title: String(localized: "Reset"), isOn: false) {
                controller.reset()
            }
            .disabled(!controller.isPlaced)
            .accessibilityLabel(String(localized: "Reset"))
            moreMenu
        }
        .modifier(OptionsBarStyle())
    }

    private var moreMenu: some View {
        Menu {
            Toggle(isOn: Binding(get: { camera.showsGrid }, set: { camera.handle(.setGrid($0)) })) {
                Label(String(localized: "Grid"), systemImage: "grid")
            }
            Button {
                camera.handle(.attention)
            } label: {
                Label(String(localized: "Ask everyone to look at the camera"), systemImage: "megaphone.fill")
            }
            Divider()
            Button {
                showSettings = true
            } label: {
                Label(String(localized: "Settings"), systemImage: "gearshape")
            }
        } label: {
            SettingLabel(systemImage: "ellipsis.circle", title: String(localized: "More"), isOn: false)
        }
        .accessibilityLabel(String(localized: "More"))
    }

    /// Photo · Video · Banner, as text tabs like the system Camera. Banner turns the viewfinder into the AR scene.
    private var modeSwitcher: some View {
        HStack(spacing: 24) {
            ForEach(CaptureMode.allCases) { mode in
                modeTab(mode.title, isSelected: camera.mode == mode) { select(mode) }
            }
        }
        .disabled(camera.isBusy)
    }

    private func modeTab(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? Color.yellow : Color.white)
                .lineLimit(1)
                .fixedSize()
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ mode: CaptureMode) {
        if mode == .banner, !ARWorldTrackingConfiguration.isSupported, !Self.isDemo {
            camera.alertMessage = String(localized: "This iPhone doesn't support AR.")
            return
        }
        showOptions = false
        showExposure = false
        showZoomPresets = false
        camera.setMode(mode)
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
            // ARKit only runs on the back camera, so the flip button gives way in banner mode.
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
            .opacity(bannerMode ? 0 : 1)
            .allowsHitTesting(!bannerMode)
            .accessibilityHidden(bannerMode)
            .accessibilityLabel(String(localized: "Switch camera"))
        }
    }

    private var remoteText: String {
        remote.connectedRemotes > 0
            ? String(localized: "\(remote.connectedRemotes) remote connected")
            : remote.bluetoothState
    }
}

/// 44pt round icon button on a dark disc, used along the top bar.
private struct RoundIcon: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title2)
            .frame(width: 44, height: 44)
            .background(Color.black.opacity(0.5), in: Circle())
    }
}

private struct OptionsBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .background(Color.black.opacity(0.55), in: Capsule())
            .environment(\.compactSettingControls, true)
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
