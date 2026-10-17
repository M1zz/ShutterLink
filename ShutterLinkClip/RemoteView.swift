import SwiftUI

struct RemoteView: View {
    @ObservedObject var remote: RemoteCentral

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if remote.phase == .connected {
                RemoteControlView(remote: remote)
            } else {
                ConnectionView(remote: remote)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Connection

private struct ConnectionView: View {
    @ObservedObject var remote: RemoteCentral
    @State private var manualCode = ""
    @FocusState private var codeFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.aperture")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
            Text("ShutterLink Remote")
                .font(.title.bold())

            switch remote.phase {
            case .waitingForBluetooth, .scanning, .connecting, .pairing:
                ProgressView()
                    .controlSize(.large)
                Text(progressText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Button("Cancel") { remote.disconnect() }
                    .buttonStyle(.bordered)

            case .failed(let message):
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.orange)
                if remote.code != nil {
                    Button("Try again") { remote.retry() }
                        .buttonStyle(.borderedProminent)
                }
                codeEntry

            case .idle, .connected:
                Text("Scan the QR code on the camera iPhone, or enter the 4-digit pairing code.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                codeEntry
            }
            Spacer()
        }
        .padding(24)
    }

    private var codeEntry: some View {
        HStack(spacing: 12) {
            TextField("0000", text: $manualCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 140, height: 52)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .focused($codeFocused)
                .onChange(of: manualCode) { _, newValue in
                    let digits = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(RemoteConfig.codeLength))
                    if digits != newValue { manualCode = digits }
                }
            Button("Connect") {
                codeFocused = false
                remote.connect(code: manualCode)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!RemoteConfig.isValidCode(manualCode))
        }
    }

    private var progressText: String {
        switch remote.phase {
        case .waitingForBluetooth: return String(localized: "Waiting for Bluetooth…")
        case .scanning: return String(localized: "Looking for camera \(remote.code ?? "")…")
        case .connecting: return String(localized: "Connecting…")
        case .pairing: return String(localized: "Pairing…")
        default: return ""
        }
    }
}

// MARK: - Remote control

private struct RemoteControlView: View {
    @ObservedObject var remote: RemoteCentral
    /// Large, minimal layout for people who just want to press one button.
    @AppStorage("simpleMode") private var simpleMode = false
    @State private var flash = false
    @State private var focusPoint: CGPoint?
    @State private var focusHide: DispatchWorkItem?
    @State private var showReviews = Self.demoShowsReviews

    private var status: RemoteStatus { remote.status ?? RemoteStatus() }

    private static var demoShowsReviews: Bool {
        #if DEBUG
        return DemoMode.screen == "reviews"
        #else
        return false
        #endif
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            if !simpleMode {
                CameraSettingsBar(status: status, send: remote.send)
            }
            preview
            if simpleMode {
                simpleControls
            } else {
                ExposureControl(value: status.exposureBias, send: remote.send)
                ZoomChips(current: status.zoom, minZoom: status.minZoom, maxZoom: status.maxZoom) {
                    remote.send(.setZoom($0))
                }
                Picker("Mode", selection: Binding(get: { status.mode }, set: { remote.send(.setMode($0)) })) {
                    ForEach(CaptureMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
                .disabled(status.isBusy)
                controls
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.2), value: simpleMode)
        .sheet(isPresented: $showReviews) {
            ReviewGallery(reviews: remote.reviews)
        }
        .onChange(of: status.countdown) { _, newValue in
            // Feel the countdown in your hand while you get into the photo.
            guard newValue != nil else { return }
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        .onChange(of: status.captureCount) { oldValue, newValue in
            guard newValue > oldValue else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeOut(duration: 0.3)) { flash = false }
            }
        }
    }

    private var header: some View {
        HStack {
            Label("Connected", systemImage: "dot.radiowaves.left.and.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(.green)
                .lineLimit(1)
            Spacer()
            if status.isRecording {
                Text(Format.duration(status.recordingSeconds))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red, in: Capsule())
            } else if status.isIntervalRunning {
                IntervalBadge(nextShot: status.nextIntervalShot)
            }
            Spacer()
            Menu {
                Toggle(isOn: $simpleMode) {
                    Label("Simple mode (big buttons)", systemImage: "textformat.size.larger")
                }
                Button(role: .destructive) {
                    remote.disconnect()
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "Options"))
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
            if let image = remote.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        GeometryReader { geometry in
                            ZStack(alignment: .topLeading) {
                                if status.showsGrid {
                                    GridLines()
                                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                                }
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { location in
                                        focus(at: location, in: geometry.size)
                                    }
                                if let focusPoint {
                                    FocusReticle(size: 56)
                                        .position(focusPoint)
                                        .id(focusPoint.x + focusPoint.y)
                                }
                            }
                        }
                    }
                    .accessibilityAddTraits(.allowsDirectInteraction)
                    .accessibilityHint(String(localized: "Tap to focus"))
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for preview…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 6) {
                LevelIndicator(tilt: status.tilt)
                if !simpleMode {
                    SceneBadges(faces: status.faces, edgeWarning: status.edgeWarning, autoCapture: status.autoCapture)
                }
                Spacer()
            }
            .padding(.top, 8)
            if let countdown = status.countdown {
                Text("\(countdown)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
            }
            if flash {
                Color.white.opacity(0.6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func focus(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        remote.send(.focus(x: location.x / size.width, y: location.y / size.height))
        focusPoint = location
        focusHide?.cancel()
        let hide = DispatchWorkItem { focusPoint = nil }
        focusHide = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: hide)
    }

    private var controls: some View {
        HStack {
            reviewThumbnail
            Spacer()
            shutter(size: 88)
            Spacer()
            Button {
                remote.send(.flipCamera)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .disabled(status.isBusy)
            .accessibilityLabel(String(localized: "Switch camera"))
        }
        .padding(.bottom, 8)
    }

    private var simpleControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach([0, 5, 10], id: \.self) { seconds in
                    Button {
                        remote.send(.setTimer(seconds: seconds))
                    } label: {
                        Text(Format.timer(seconds))
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(status.timerSeconds == seconds ? Color.black : Color.white)
                            .background(status.timerSeconds == seconds ? Color.yellow : Color.white.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Timer"))
                    .accessibilityValue(Format.timer(seconds))
                }
            }
            HStack {
                reviewThumbnail
                Spacer()
                shutter(size: 120)
                Spacer()
                Button {
                    remote.send(.attention)
                } label: {
                    Image(systemName: "megaphone.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel(String(localized: "Ask everyone to look at the camera"))
            }
            .padding(.bottom, 8)
        }
    }

    private func shutter(size: CGFloat) -> some View {
        ShutterButton(mode: status.mode,
                      isRecording: status.isBusy,
                      isCountingDown: status.countdown != nil,
                      size: size) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            remote.send(.shutter)
        }
    }

    /// Copies of the photos taken this session, sent by the camera.
    private var reviewThumbnail: some View {
        Button {
            showReviews = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let latest = remote.reviews.first {
                        Image(uiImage: latest.image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white.opacity(0.12))
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                if remote.reviews.count > 1 {
                    Text("\(remote.reviews.count)")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .background(Color.yellow, in: Capsule())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(remote.reviews.isEmpty)
        .accessibilityLabel(String(localized: "Photos from this session"))
    }
}

// MARK: - Photos received from the camera

/// Copies of the photos taken in this session. Save or share them before the App Clip closes.
private struct ReviewGallery: View {
    let reviews: [ReviewPhoto]
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ReviewPhoto.ID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TabView(selection: $selected) {
                    ForEach(reviews) { photo in
                        Image(uiImage: photo.image)
                            .resizable()
                            .scaledToFit()
                            .tag(Optional(photo.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))

                Text("Save or share your copy before closing the remote.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let photo = current {
                    ShareLink(item: Image(uiImage: photo.image),
                              preview: SharePreview(Text("ShutterLink photo"), image: Image(uiImage: photo.image))) {
                        Label("Save or share this photo", systemImage: "square.and.arrow.down")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundStyle(.black)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
            .navigationTitle(Text("\(reviews.count) photos"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { selected = reviews.first?.id }
        }
        .preferredColorScheme(.dark)
    }

    private var current: ReviewPhoto? {
        reviews.first { $0.id == selected } ?? reviews.first
    }
}
