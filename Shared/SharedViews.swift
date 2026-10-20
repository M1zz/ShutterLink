import SwiftUI

struct ShutterButton: View {
    let mode: CaptureMode
    let isRecording: Bool
    var isCountingDown = false
    var size: CGFloat = 76
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: size, height: size)
                RoundedRectangle(cornerRadius: isRecording ? 6 : size / 2)
                    .fill(mode == .video ? Color.red : Color.white)
                    .frame(width: isRecording ? size * 0.4 : size - 14,
                           height: isRecording ? size * 0.4 : size - 14)
                    .opacity(isCountingDown ? 0.5 : 1)
            }
            .animation(.easeInOut(duration: 0.2), value: isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
    }

    private var accessibilityTitle: String {
        if isCountingDown { return String(localized: "Cancel timer") }
        if isRecording {
            return mode == .video ? String(localized: "Stop recording") : String(localized: "Stop interval shooting")
        }
        return mode == .video ? String(localized: "Start recording") : String(localized: "Take photo")
    }
}

struct ZoomChips: View {
    let current: Double
    let minZoom: Double
    let maxZoom: Double
    let onSelect: (Double) -> Void

    private var presets: [Double] {
        [0.5, 1, 2, 3, 5, 10].filter { $0 >= minZoom - 0.01 && $0 <= maxZoom + 0.01 }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.self) { value in
                let isActive = abs(current - value) < 0.05
                Button {
                    onSelect(value)
                } label: {
                    Text(isActive ? Format.zoom(current) : Format.zoom(value))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isActive ? Color.yellow : Color.white)
                        .frame(minWidth: 44, minHeight: 36)
                        .background(Color.black.opacity(0.45), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TimerButton: View {
    let seconds: Int
    let onChange: (Int) -> Void

    var body: some View {
        Menu {
            Picker(String(localized: "Timer"), selection: Binding(get: { seconds }, set: onChange)) {
                ForEach(TimerOptions.all, id: \.self) { option in
                    Text(Format.timer(option)).tag(option)
                }
            }
        } label: {
            SettingLabel(systemImage: seconds == 0 ? "timer" : "timer.circle.fill",
                         title: Format.timer(seconds), isOn: seconds > 0, compactShowsTitle: true)
        }
        .accessibilityLabel(String(localized: "Timer"))
        .accessibilityValue(Format.timer(seconds))
    }
}

// MARK: - Camera settings

/// Flash, timer, drive, grid, hands-free shutter and the attention prompt. Shared by the camera screen and the remote,
/// both of which drive the camera through `RemoteCommand`s.
struct CameraSettingsBar: View {
    let status: RemoteStatus
    let send: (RemoteCommand) -> Void

    var body: some View {
        HStack(spacing: 2) {
            FlashButton(mode: status.flash, isAvailable: status.flashAvailable && status.mode.usesCaptureSession) {
                send(.setFlash(status.flash.next))
            }
            TimerButton(seconds: status.timerSeconds) { send(.setTimer(seconds: $0)) }
            DriveMenu(burstCount: status.burstCount, intervalSeconds: status.intervalSeconds, send: send)
                .disabled(status.isBusy || status.mode != .photo)
            SettingButton(systemImage: "grid", title: String(localized: "Grid"), isOn: status.showsGrid) {
                send(.setGrid(!status.showsGrid))
            }
            .accessibilityLabel(String(localized: "Grid"))
            .accessibilityValue(status.showsGrid ? String(localized: "On") : String(localized: "Off"))
            AutoCaptureMenu(mode: status.autoCapture) { send(.setAutoCapture($0)) }
                .disabled(status.isBusy)
            SettingButton(systemImage: "megaphone.fill", title: String(localized: "Look"), isOn: false) {
                send(.attention)
            }
            .accessibilityLabel(String(localized: "Ask everyone to look at the camera"))
        }
        .padding(.horizontal, 6)
        .background(Color.black.opacity(0.45), in: Capsule())
    }
}

extension EnvironmentValues {
    /// Icon-only setting controls (the camera app's viewfinder). The remote keeps the captions.
    @Entry var compactSettingControls = false
}

/// Icon over a short caption, yellow when active. Same footprint as `TimerButton`.
struct SettingLabel: View {
    let systemImage: String
    let title: String
    let isOn: Bool
    /// In compact mode, show `title` next to the icon while on (e.g. "10s", "×5") — for values the icon can't tell.
    var compactShowsTitle = false
    @Environment(\.compactSettingControls) private var compact

    var body: some View {
        if compact {
            compactBody
        } else {
            captionedBody
        }
    }

    private var compactBody: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.title3)
            if compactShowsTitle, isOn {
                Text(title)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .foregroundStyle(isOn ? Color.yellow : Color.white)
        .frame(minWidth: 38, minHeight: 44)
        .padding(.horizontal, compactShowsTitle && isOn ? 4 : 0)
        .contentShape(Rectangle())
    }

    private var captionedBody: some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(height: 28)
            Text(title)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(isOn ? Color.yellow : Color.white)
        .frame(width: 50, height: 60)
    }
}

struct SettingButton: View {
    let systemImage: String
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingLabel(systemImage: systemImage, title: title, isOn: isOn)
        }
        .buttonStyle(.plain)
    }
}

struct FlashButton: View {
    let mode: FlashMode
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        SettingButton(systemImage: icon, title: isAvailable ? title : String(localized: "Off"),
                      isOn: isAvailable && mode != .off, action: action)
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1 : 0.4)
            .accessibilityLabel(String(localized: "Flash"))
            .accessibilityValue(isAvailable ? title : String(localized: "Unavailable"))
    }

    private var icon: String {
        guard isAvailable else { return "bolt.slash" }
        switch mode {
        case .off: return "bolt.slash"
        case .auto: return "bolt.badge.automatic"
        case .on: return "bolt.fill"
        }
    }

    private var title: String {
        switch mode {
        case .off: return String(localized: "Off")
        case .auto: return String(localized: "Auto")
        case .on: return String(localized: "On")
        }
    }
}

/// Single shot, a burst of photos one second apart, or interval shooting.
struct DriveMenu: View {
    let burstCount: Int
    let intervalSeconds: Int
    let send: (RemoteCommand) -> Void

    var body: some View {
        Menu {
            Section("Burst") {
                ForEach(DriveOptions.burstCounts, id: \.self) { count in
                    Button {
                        send(.setInterval(seconds: 0))
                        send(.setBurst(count: count))
                    } label: {
                        let title = count == 1 ? String(localized: "Single photo")
                            : String(localized: "\(count) photos, best one picked")
                        if intervalSeconds == 0, burstCount == count {
                            Label(title, systemImage: "checkmark")
                        } else {
                            Text(title)
                        }
                    }
                }
            }
            Section("Interval") {
                ForEach(DriveOptions.intervals.filter { $0 > 0 }, id: \.self) { seconds in
                    Button {
                        send(.setInterval(seconds: seconds))
                    } label: {
                        let title = String(localized: "Every \(Format.interval(seconds))")
                        if intervalSeconds == seconds {
                            Label(title, systemImage: "checkmark")
                        } else {
                            Text(title)
                        }
                    }
                }
            }
        } label: {
            SettingLabel(systemImage: icon, title: title, isOn: intervalSeconds > 0 || burstCount > 1,
                         compactShowsTitle: true)
        }
        .accessibilityLabel(String(localized: "Drive mode"))
        .accessibilityValue(accessibilityValue)
    }

    private var icon: String {
        if intervalSeconds > 0 { return "clock.arrow.2.circlepath" }
        return burstCount > 1 ? "square.stack.3d.down.right" : "square"
    }

    private var title: String {
        if intervalSeconds > 0 { return Format.interval(intervalSeconds) }
        return burstCount > 1 ? "×\(burstCount)" : String(localized: "Single")
    }

    private var accessibilityValue: String {
        if intervalSeconds > 0 { return String(localized: "Every \(Format.interval(intervalSeconds))") }
        return burstCount > 1 ? String(localized: "\(burstCount) photos, best one picked") : String(localized: "Single photo")
    }
}

/// Exposure compensation in 1/3 EV steps. Tapping the value resets it.
struct ExposureControl: View {
    let value: Double
    let send: (RemoteCommand) -> Void

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", delta: -ExposureOptions.step)
                .disabled(value <= ExposureOptions.range.lowerBound + 0.01)
            Button {
                send(.setExposure(0))
            } label: {
                Label(Format.exposure(value), systemImage: "plusminus.circle")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(abs(value) < 0.01 ? Color.white : Color.yellow)
                    .frame(minWidth: 96, minHeight: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Exposure"))
            .accessibilityValue(Format.exposure(value))
            .accessibilityHint(String(localized: "Reset exposure"))
            stepButton("plus", delta: ExposureOptions.step)
                .disabled(value >= ExposureOptions.range.upperBound - 0.01)
        }
        .background(Color.black.opacity(0.45), in: Capsule())
    }

    private func stepButton(_ systemImage: String, delta: Double) -> some View {
        Button {
            send(.setExposure(value + delta))
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta < 0 ? String(localized: "Darker") : String(localized: "Brighter"))
    }
}

/// Shown while an interval run is active.
struct IntervalBadge: View {
    let nextShot: Int?

    var body: some View {
        Label(nextShot.map { String(localized: "Next shot in \($0)s") } ?? String(localized: "Interval"),
              systemImage: "clock.arrow.2.circlepath")
            .font(.body.weight(.semibold).monospacedDigit())
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.yellow, in: Capsule())
    }
}

/// Rule-of-thirds lines.
struct GridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for i in 1 ... 2 {
            let x = rect.minX + rect.width * CGFloat(i) / 3
            let y = rect.minY + rect.height * CGFloat(i) / 3
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

struct FocusReticle: View {
    var size: CGFloat = 72
    @State private var settled = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.yellow, lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(settled ? 1 : 1.4)
            .onAppear {
                withAnimation(.spring(duration: 0.3)) { settled = true }
            }
            .allowsHitTesting(false)
    }
}

/// Palm, smile or clap shutter.
struct AutoCaptureMenu: View {
    let mode: AutoCapture
    let onChange: (AutoCapture) -> Void

    var body: some View {
        Menu {
            Picker(String(localized: "Hands-free shutter"), selection: Binding(get: { mode }, set: onChange)) {
                ForEach(AutoCapture.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
        } label: {
            SettingLabel(systemImage: mode.symbol, title: shortTitle, isOn: mode != .off)
        }
        .accessibilityLabel(String(localized: "Hands-free shutter"))
        .accessibilityValue(mode.title)
    }

    private var shortTitle: String {
        switch mode {
        case .off: return String(localized: "Hands")
        case .palm: return String(localized: "Palm")
        case .smile: return String(localized: "Smile")
        case .clap: return String(localized: "Clap")
        }
    }
}

// MARK: - Group photo overlays

/// A horizon line that turns green when the phone is level.
struct LevelIndicator: View {
    let tilt: Int?

    var body: some View {
        if let tilt {
            let isLevel = abs(tilt) <= 1
            HStack(spacing: 10) {
                Capsule().frame(width: 36, height: 2)
                Text(isLevel ? String(localized: "Level") : "\(tilt)°")
                    .font(.body.weight(.semibold).monospacedDigit())
                Capsule().frame(width: 36, height: 2)
            }
            .foregroundStyle(isLevel ? Color.green : Color.white)
            .rotationEffect(.degrees(Double(-tilt)))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.35), in: Capsule())
            .animation(.easeOut(duration: 0.15), value: tilt)
            .allowsHitTesting(false)
            .accessibilityLabel(isLevel ? String(localized: "Level") : String(localized: "Tilted \(tilt) degrees"))
        }
    }
}

/// People counter and "someone is cut off" warning for group photos.
struct SceneBadges: View {
    let faces: Int
    let edgeWarning: Bool
    let autoCapture: AutoCapture

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Label(String(localized: "\(faces) in frame"), systemImage: "person.2.fill")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5), in: Capsule())
                if autoCapture != .off {
                    Label(autoCapture.title, systemImage: autoCapture.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5), in: Capsule())
                }
            }
            if edgeWarning {
                Label(String(localized: "Someone is at the edge of the frame"), systemImage: "exclamationmark.triangle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow, in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .allowsHitTesting(false)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .transition(.opacity.combined(with: .move(edge: .top)))
            .allowsHitTesting(false)
    }
}
