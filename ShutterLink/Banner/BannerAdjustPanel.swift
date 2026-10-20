import SwiftUI

/// Fine positioning for a placed banner: a pad to slide it over the floor, sliders for height, turn and size.
/// Dragging and pinching the banner itself still works; the sliders follow those gestures.
struct BannerAdjustPanel: View {
    let controller: BannerARController

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                MovePad { right, away in controller.nudge(right: right, away: away) }
                VStack(spacing: 2) {
                    if controller.isOnFloor {
                        sliderRow(systemImage: "arrow.up.and.down",
                                  label: String(localized: "Height above floor"),
                                  value: Binding(get: { controller.holdHeight },
                                                 set: { controller.updateHoldHeight($0) }),
                                  range: 0.3 ... 2.0,
                                  text: String(format: "%.1fm", controller.holdHeight))
                    }
                    sliderRow(systemImage: "arrow.triangle.2.circlepath",
                              label: String(localized: "Direction"),
                              value: Binding(get: { controller.turnDegrees }, set: { controller.setTurn($0) }),
                              range: BannerARController.turnRange,
                              text: "\(Int(controller.turnDegrees.rounded()))°")
                    sliderRow(systemImage: "arrow.left.and.right",
                              label: String(localized: "Width"),
                              value: Binding(get: { controller.sizeScale }, set: { controller.setSize($0) }),
                              range: BannerARController.sizeRange,
                              text: String(format: "%.1fm", controller.widthMeters))
                }
            }
            HStack {
                Button {
                    controller.faceCamera()
                } label: {
                    Label("Face Me", systemImage: "camera.viewfinder")
                        .font(.body.weight(.semibold))
                }
                Spacer()
                Button {
                    controller.isAdjusting = false
                } label: {
                    Text("Done")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.yellow, in: Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(maxWidth: 380)
    }

    private func sliderRow(systemImage: String, label: String, value: Binding<Float>,
                           range: ClosedRange<Float>, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.body)
                .frame(width: 24)
            Slider(value: value, in: range)
                .tint(.yellow)
            Text(text)
                .font(.body.monospacedDigit())
                .frame(minWidth: 52, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(text)
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            let current = value.wrappedValue
            value.wrappedValue = direction == .increment ? min(current + step, range.upperBound)
                                                         : max(current - step, range.lowerBound)
        }
    }
}

/// A round pad: drag the knob and the banner slides that way across the floor (up = farther away).
private struct MovePad: View {
    let onMove: (_ right: Float, _ away: Float) -> Void
    @State private var knob: CGSize = .zero
    @State private var last: CGSize = .zero

    private let size: CGFloat = 88
    /// Metres per point of finger travel.
    private let speed: Float = 0.004

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.12))
            Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
            ForEach(0 ..< 4, id: \.self) { i in
                Image(systemName: "chevron.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .offset(y: -size / 2 + 12)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
            Circle()
                .fill(Color.yellow)
                .frame(width: 34, height: 34)
                .offset(knob)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let dx = drag.translation.width - last.width
                    let dy = drag.translation.height - last.height
                    last = drag.translation
                    onMove(Float(dx) * speed, Float(-dy) * speed)
                    let limit = size / 2 - 17
                    let distance = max(hypot(drag.translation.width, drag.translation.height), 0.001)
                    let clamp = min(1, limit / distance)
                    knob = CGSize(width: drag.translation.width * clamp, height: drag.translation.height * clamp)
                }
                .onEnded { _ in
                    last = .zero
                    withAnimation(.spring(duration: 0.25)) { knob = .zero }
                }
        )
        .accessibilityLabel(String(localized: "Move banner"))
        .accessibilityHint(String(localized: "Drag to slide the banner across the floor."))
    }
}
