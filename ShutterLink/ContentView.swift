import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        CameraScreen(model: model, camera: model.camera, remote: model.remote)
            .onAppear {
                // The camera sits on a tripod; never let the screen lock.
                UIApplication.shared.isIdleTimerDisabled = true
                model.start()
            }
    }
}

private struct CameraScreen: View {
    let model: AppModel
    @ObservedObject var camera: CameraController
    @ObservedObject var remote: RemotePeripheral
    @State private var showPairing = false
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(camera: camera)
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

            VStack(spacing: 16) {
                topBar
                Spacer()
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
        .sheet(isPresented: $showPairing) {
            PairingSheet(url: model.invocationURL, code: model.sessionCode, remote: remote)
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
    }

    private var topBar: some View {
        HStack {
            Label(remoteText, systemImage: remote.connectedRemotes > 0
                  ? "iphone.radiowaves.left.and.right" : "dot.radiowaves.left.and.right")
                .font(.footnote.weight(.semibold))
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
            }

            Spacer()

            TimerButton(seconds: camera.timerSeconds) { camera.setTimer($0) }

            Button {
                showPairing = true
            } label: {
                Image(systemName: "qrcode")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5), in: Circle())
            }
            .accessibilityLabel("Show pairing QR code")
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
        .disabled(camera.isRecording)
    }

    private var bottomBar: some View {
        HStack {
            LastCaptureButton(thumbnail: camera.lastThumbnail)
            Spacer()
            ShutterButton(mode: camera.mode,
                          isRecording: camera.isRecording,
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
            .disabled(camera.isRecording)
            .accessibilityLabel("Switch camera")
        }
    }

    private var remoteText: String {
        remote.connectedRemotes > 0 ? "Remote connected" : remote.bluetoothState
    }
}

/// Bottom-left thumbnail of the last capture, like the system Camera. Tapping opens Photos.
private struct LastCaptureButton: View {
    let thumbnail: UIImage?
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            // Opens the Photos app (there's no public API to jump into it otherwise).
            if let url = URL(string: "photos-redirect://") { openURL(url) }
        } label: {
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
        .accessibilityLabel(thumbnail == nil ? "Open Photos" : "Last capture. Open Photos")
    }
}
