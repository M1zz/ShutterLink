#if DEBUG
import SwiftUI

/// App Store screenshot mode (Debug builds only). The simulator has no camera or Bluetooth,
/// so launch with `-screenshots <screen>` to fill the UI with an illustrated scene and sample state.
enum DemoMode {
    static var screen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screenshots") else { return nil }
        return args.indices.contains(index + 1) ? args[index + 1] : "main"
    }

    static var isOn: Bool { screen != nil }

    @MainActor
    static func sceneImage(width: CGFloat = 900, variant: Int = 0) -> UIImage {
        let renderer = ImageRenderer(content: DemoScene(variant: variant)
            .frame(width: width, height: width * 4 / 3))
        renderer.scale = 1
        return renderer.uiImage ?? UIImage()
    }

    @MainActor
    static func sceneJPEG(variant: Int = 0) -> Data {
        sceneImage(variant: variant).jpegData(compressionQuality: 0.85) ?? Data()
    }
}

/// Illustrated group photo: five friends in a park.
/// `variant`: odd values show two people blinking; `variant / 2` picks the time of day.
struct DemoScene: View {
    var variant = 0

    private var isBlinking: Bool { variant % 2 == 1 }
    private var sky: [Color] {
        switch (variant / 2) % 3 {
        case 1: return [Color(red: 0.98, green: 0.55, blue: 0.40), Color(red: 1, green: 0.85, blue: 0.62)]
        case 2: return [Color(red: 0.36, green: 0.42, blue: 0.80), Color(red: 0.78, green: 0.70, blue: 0.92)]
        default: return [Color(red: 0.45, green: 0.72, blue: 0.98), Color(red: 0.82, green: 0.92, blue: 1)]
        }
    }

    private let shirts: [Color] = [.orange, .teal, .pink, .indigo, .green]
    private let skins: [Color] = [
        Color(red: 0.96, green: 0.80, blue: 0.67), Color(red: 0.80, green: 0.60, blue: 0.45),
        Color(red: 0.98, green: 0.85, blue: 0.74), Color(red: 0.62, green: 0.44, blue: 0.32),
        Color(red: 0.90, green: 0.72, blue: 0.58)
    ]
    private let hair: [Color] = [.black, .brown, Color(red: 0.35, green: 0.2, blue: 0.1), .black, .gray]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                LinearGradient(colors: sky, startPoint: .top, endPoint: .center)
                Circle().fill(Color.yellow.opacity(0.9)).frame(width: w * 0.16).position(x: w * 0.82, y: h * 0.12)
                Ellipse().fill(Color(red: 0.42, green: 0.66, blue: 0.40)).frame(width: w * 1.6, height: h * 0.5)
                    .position(x: w * 0.2, y: h * 0.58)
                Ellipse().fill(Color(red: 0.36, green: 0.60, blue: 0.36)).frame(width: w * 1.4, height: h * 0.45)
                    .position(x: w * 0.95, y: h * 0.62)
                Rectangle().fill(Color(red: 0.48, green: 0.74, blue: 0.42)).frame(height: h * 0.4)
                    .position(x: w / 2, y: h * 0.8)
                tree.frame(width: w * 0.3, height: h * 0.45).position(x: w * 0.12, y: h * 0.42)

                HStack(alignment: .bottom, spacing: w * 0.01) {
                    ForEach(0 ..< 5, id: \.self) { i in
                        person(i, width: w * 0.18, tall: [0.95, 1.05, 0.9, 1.1, 1.0][i])
                    }
                }
                .position(x: w / 2, y: h * 0.68)
            }
        }
    }

    private var tree: some View {
        VStack(spacing: -20) {
            Circle().fill(Color(red: 0.25, green: 0.52, blue: 0.3))
            Rectangle().fill(Color.brown).frame(width: 24, height: 120)
        }
    }

    private func person(_ i: Int, width: CGFloat, tall: CGFloat) -> some View {
        let head = width * 0.62
        let blinking = isBlinking && (i == 1 || i == 3)
        return VStack(spacing: -head * 0.08) {
            ZStack {
                Circle().fill(hair[i]).frame(width: head * 1.06).offset(y: -head * 0.06)
                Circle().fill(skins[i]).frame(width: head)
                HStack(spacing: head * 0.26) {
                    eye(blinking, size: head)
                    eye(blinking, size: head)
                }
                .offset(y: -head * 0.04)
                Group {
                    if blinking {
                        Capsule().fill(Color.black.opacity(0.75)).frame(width: head * 0.3, height: head * 0.05)
                    } else {
                        SmilePath()
                            .stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: head * 0.05, lineCap: .round))
                            .frame(width: head * 0.4, height: head * 0.16)
                    }
                }
                .offset(y: head * 0.2)
            }
            UnevenRoundedRectangle(topLeadingRadius: width * 0.4, topTrailingRadius: width * 0.4)
                .fill(shirts[i])
                .frame(width: width, height: width * 1.25 * tall)
        }
    }

    @ViewBuilder
    private func eye(_ closed: Bool, size: CGFloat) -> some View {
        if closed {
            Capsule().fill(Color.black.opacity(0.8)).frame(width: size * 0.18, height: size * 0.05)
        } else {
            Circle().fill(Color.black.opacity(0.8)).frame(width: size * 0.1)
        }
    }
}

private struct SmilePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2))
        return path
    }
}
#endif
