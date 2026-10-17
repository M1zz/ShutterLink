import SwiftUI

struct ShutterButton: View {
    let mode: CaptureMode
    /// Recording a video or running an interval session.
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
                    .fill(fillColor)
                    .frame(width: isRecording ? size * 0.4 : size - 14,
                           height: isRecording ? size * 0.4 : size - 14)
                    .opacity(isCountingDown ? 0.5 : 1)
                if mode == .interval, !isRecording {
                    Image(systemName: "timer")
                        .font(.system(size: size * 0.32, weight: .bold))
                        .foregroundStyle(.black)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
    }

    private var fillColor: Color {
        switch mode {
        case .photo: return .white
        case .video: return .red
        case .interval: return .yellow
        }
    }

    private var accessibilityTitle: String {
        if isCountingDown { return String(localized: "Cancel timer") }
        if isRecording {
            return mode == .interval ? String(localized: "Stop interval shooting") : String(localized: "Stop recording")
        }
        switch mode {
        case .photo: return String(localized: "Take photo")
        case .video: return String(localized: "Start recording")
        case .interval: return String(localized: "Start interval shooting")
        }
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

// MARK: - Tool chips

/// Round icon button with an optional value, used for the camera tools row.
struct ToolChip: View {
    let systemImage: String
    var value: String?
    var isActive = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.title3)
            if let value {
                Text(value)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(isActive ? Color.yellow : Color.white)
        .frame(width: 50, height: 56)
        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct TimerButton: View {
    let seconds: Int
    let onChange: (Int) -> Void

    var body: some View {
        Menu {
            Picker(String(localized: "Timer"), selection: Binding(get: { seconds }, set: onChange)) {
                ForEach(RemoteOptions.timers, id: \.self) { option in
                    Text(Format.timer(option)).tag(option)
                }
            }
        } label: {
            ToolChip(systemImage: seconds == 0 ? "timer" : "timer.circle.fill",
                     value: Format.timer(seconds),
                     isActive: seconds > 0)
        }
        .accessibilityLabel(String(localized: "Timer"))
        .accessibilityValue(Format.timer(seconds))
    }
}

struct FlashButton: View {
    let mode: FlashMode
    let onChange: (FlashMode) -> Void

    var body: some View {
        Button {
            onChange(mode.next)
        } label: {
            ToolChip(systemImage: mode.symbol, isActive: mode != .off)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
    }
}

struct BurstButton: View {
    let count: Int
    let onChange: (Int) -> Void

    var body: some View {
        Menu {
            Picker(String(localized: "Group shot"), selection: Binding(get: { count }, set: onChange)) {
                ForEach(RemoteOptions.bursts, id: \.self) { option in
                    Text(option == 1 ? String(localized: "Single photo") : String(localized: "\(option) photos, pick best"))
                        .tag(option)
                }
            }
        } label: {
            ToolChip(systemImage: count > 1 ? "square.stack.3d.down.right.fill" : "square.stack.3d.down.right",
                     value: count > 1 ? "×\(count)" : nil,
                     isActive: count > 1)
        }
        .accessibilityLabel(String(localized: "Group shot"))
        .accessibilityValue(count == 1 ? String(localized: "Single photo") : String(localized: "\(count) photos, pick best"))
    }
}

struct IntervalButton: View {
    let seconds: Int
    let onChange: (Int) -> Void

    var body: some View {
        Menu {
            Picker(String(localized: "Interval"), selection: Binding(get: { seconds }, set: onChange)) {
                ForEach(RemoteOptions.intervals, id: \.self) { option in
                    Text(String(localized: "Every \(option)s")).tag(option)
                }
            }
        } label: {
            ToolChip(systemImage: "clock.arrow.circlepath", value: "\(seconds)s", isActive: true)
        }
        .accessibilityLabel(String(localized: "Interval"))
        .accessibilityValue(String(localized: "Every \(seconds)s"))
    }
}

struct AutoCaptureButton: View {
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
            ToolChip(systemImage: mode.symbol, isActive: mode != .off)
        }
        .accessibilityLabel(String(localized: "Hands-free shutter"))
        .accessibilityValue(mode.title)
    }
}

struct ExposureButton: View {
    let value: Double
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            ToolChip(systemImage: "plusminus.circle", value: Format.exposure(value), isActive: value != 0 || isExpanded)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Exposure"))
        .accessibilityValue(Format.exposure(value))
    }
}

struct ExposureSlider: View {
    let value: Double
    let onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.min")
            Slider(value: Binding(get: { value }, set: onChange),
                   in: RemoteOptions.exposureRange,
                   step: 0.1)
                .tint(.yellow)
            Image(systemName: "sun.max.fill")
            Button {
                onChange(0)
            } label: {
                Text(Format.exposure(value))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 52)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Reset exposure"))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5), in: Capsule())
    }
}

// MARK: - Viewfinder overlays

/// Rule-of-thirds grid.
struct GridOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let w = proxy.size.width
                let h = proxy.size.height
                for i in 1 ... 2 {
                    let x = w * CGFloat(i) / 3
                    let y = h * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                }
            }
            .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

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

struct FocusSquare: View {
    @State private var scale: CGFloat = 1.5

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 76, height: 76)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { scale = 1 }
            }
            .allowsHitTesting(false)
    }
}

struct CountdownText: View {
    let value: Int
    var size: CGFloat = 140

    var body: some View {
        Text("\(value)")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(radius: 10)
            .contentTransition(.numericText(countsDown: true))
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
