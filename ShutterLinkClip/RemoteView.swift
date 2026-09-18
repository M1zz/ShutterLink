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
        case .waitingForBluetooth: return "Waiting for Bluetooth…"
        case .scanning: return "Looking for camera \(remote.code ?? "")…"
        case .connecting: return "Connecting…"
        case .pairing: return "Pairing…"
        default: return ""
        }
    }
}

// MARK: - Remote control

private struct RemoteControlView: View {
    @ObservedObject var remote: RemoteCentral
    @State private var flash = false

    private var status: RemoteStatus { remote.status ?? RemoteStatus() }

    var body: some View {
        VStack(spacing: 16) {
            header
            preview
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
            .disabled(status.isRecording)
            controls
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
            Spacer()
            if status.isRecording {
                Text(Format.duration(status.recordingSeconds))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red, in: Capsule())
            }
            Spacer()
            Button("Disconnect") { remote.disconnect() }
                .font(.footnote)
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
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for preview…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
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

    private var controls: some View {
        HStack {
            TimerButton(seconds: status.timerSeconds) { remote.send(.setTimer(seconds: $0)) }
            Spacer()
            ShutterButton(mode: status.mode,
                          isRecording: status.isRecording,
                          isCountingDown: status.countdown != nil,
                          size: 88) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                remote.send(.shutter)
            }
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
            .disabled(status.isRecording)
            .accessibilityLabel("Switch camera")
        }
        .padding(.bottom, 8)
    }
}
