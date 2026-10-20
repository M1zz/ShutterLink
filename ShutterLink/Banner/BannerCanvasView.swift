import SwiftUI

/// The banner artwork itself. Rendered at `size` both for on-screen preview
/// (scaled down) and as the AR texture (full resolution via ImageRenderer).
struct BannerCanvasView: View {
    let design: BannerDesign
    let size: CGSize

    private var unit: CGFloat { size.height / 100 } // 1 unit = 1% of height

    var body: some View {
        ZStack {
            backgroundLayer
            decorationLayer
            contentLayer
            borderLayer
            if design.material.hasGrommets {
                hemLayer
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    // MARK: Layers

    @ViewBuilder
    private var backgroundLayer: some View {
        switch design.background {
        case .solid:
            design.backgroundColor
        case .gradient:
            LinearGradient(
                colors: [design.backgroundColor, design.accentColor.opacity(0.35)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .stripe:
            VStack(spacing: 0) {
                design.accentColor.frame(height: unit * 9)
                design.backgroundColor
            }
        case .bands:
            VStack(spacing: 0) {
                design.accentColor.frame(height: unit * 9)
                design.backgroundColor
                design.accentColor.frame(height: unit * 9)
            }
        case .diagonal:
            design.backgroundColor
                .overlay {
                    DiagonalStripes(spacing: unit * 14)
                        .fill(design.accentColor.opacity(0.08))
                }
        }
    }

    private var decorationLayer: some View {
        let symbols = design.decoration.symbols
        return GeometryReader { geo in
            if !symbols.isEmpty {
                ForEach(0..<10, id: \.self) { i in
                    let s = symbols[i % symbols.count]
                    let (x, y, rot, scale) = Self.slot(i, in: geo.size)
                    Text(s)
                        .font(.system(size: unit * 14 * scale))
                        .rotationEffect(.degrees(rot))
                        .position(x: x, y: y)
                        .opacity(0.9)
                }
            }
        }
    }

    private var contentLayer: some View {
        HStack(spacing: unit * 6) {
            if let logo = design.logoImage {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: unit * 52)
                    .padding(.leading, unit * 10)
            }
            VStack(spacing: unit * 4) {
                Text(design.title)
                    .font(design.fontStyle.font(size: unit * 16))
                    .foregroundStyle(design.titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(design.subtitle)
                    .font(design.fontStyle.font(size: unit * 30))
                    .foregroundStyle(design.subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(design.footer)
                    .font(.system(size: unit * 11, weight: .semibold))
                    .foregroundStyle(design.footerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, unit * 14)
        .padding(.top, design.background == .stripe || design.background == .bands ? unit * 9 : 0)
        .padding(.bottom, design.background == .bands ? unit * 9 : 0)
    }

    private var borderLayer: some View {
        Rectangle()
            .strokeBorder(design.accentColor.opacity(0.9), lineWidth: unit * 1.2)
            .padding(unit * 3)
    }

    /// A stitched hem just inside the edge and a metal grommet in each corner, like a printed cloth banner.
    private var hemLayer: some View {
        let inset = unit * 1.6
        let ring = unit * 7
        return ZStack {
            Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: unit * 0.35, dash: [unit * 1.4, unit * 0.9]))
                .foregroundStyle(Color.black.opacity(0.18))
                .padding(inset)
            GeometryReader { geo in
                ForEach(0 ..< 4, id: \.self) { corner in
                    let x = corner % 2 == 0 ? unit * 6 : geo.size.width - unit * 6
                    let y = corner < 2 ? unit * 6 : geo.size.height - unit * 6
                    Grommet(size: ring).position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Deterministic scatter positions along the top and bottom edges.
    private static func slot(_ i: Int, in size: CGSize) -> (CGFloat, CGFloat, Double, CGFloat) {
        let fractions: [CGFloat] = [0.07, 0.14, 0.23, 0.77, 0.86, 0.93, 0.10, 0.30, 0.70, 0.90]
        let x = size.width * fractions[i]
        let y = i < 6 ? size.height * (i % 2 == 0 ? 0.14 : 0.86)
                      : size.height * (i % 2 == 0 ? 0.90 : 0.10)
        let rot = Double((i * 37) % 60) - 30
        let scale: CGFloat = i % 3 == 0 ? 1.2 : 0.9
        return (x, y, rot, scale)
    }
}

#Preview {
    BannerCanvasView(design: BannerDesign(), size: CGSize(width: 800, height: 200))
}

/// Brass eyelet: a metal ring around a hole showing the backing.
private struct Grommet: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(colors: [Color(white: 0.92), Color(white: 0.55), Color(white: 0.85),
                                               Color(white: 0.5), Color(white: 0.92)],
                                      center: .center))
            Circle()
                .fill(Color(white: 0.18))
                .frame(width: size * 0.48, height: size * 0.48)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: size * 0.06, y: size * 0.04)
    }
}

/// 45° stripes across the whole banner.
struct DiagonalStripes: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let band = spacing / 2
        var x = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height + band, y: rect.minY))
            path.addLine(to: CGPoint(x: x + band, y: rect.maxY))
            path.closeSubpath()
            x += spacing
        }
        return path
    }
}
