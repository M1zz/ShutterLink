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
        if isCountingDown { return "Cancel timer" }
        if isRecording { return "Stop recording" }
        return mode == .photo ? "Take photo" : "Start recording"
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
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isActive ? Color.yellow : Color.white)
                        .frame(minWidth: 40, minHeight: 32)
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

    static let options = [0, 3, 10]

    var body: some View {
        Button {
            let index = Self.options.firstIndex(of: seconds) ?? 0
            onChange(Self.options[(index + 1) % Self.options.count])
        } label: {
            VStack(spacing: 2) {
                Image(systemName: seconds == 0 ? "timer" : "timer.circle.fill")
                    .font(.title2)
                Text(seconds == 0 ? "Off" : "\(seconds)s")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(seconds == 0 ? Color.white : Color.yellow)
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Timer \(seconds == 0 ? "off" : "\(seconds) seconds")")
    }
}
