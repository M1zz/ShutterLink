import SwiftUI
import UIKit

// MARK: - Design model

enum BannerAspect: String, CaseIterable, Identifiable {
    case wide = "4:1"      // classic street banner
    case standard = "3:1"
    case compact = "2:1"

    var id: String { rawValue }

    /// width / height
    var ratio: Float {
        switch self {
        case .wide: return 4
        case .standard: return 3
        case .compact: return 2
        }
    }

    /// Pixel size used when rendering the texture.
    var renderSize: CGSize {
        let width: CGFloat = 2400
        return CGSize(width: width, height: width / CGFloat(ratio))
    }
}

enum BannerBackground: String, CaseIterable, Identifiable {
    case solid
    case gradient
    case stripe
    case bands
    case diagonal

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .solid: return "Solid"
        case .gradient: return "Gradient"
        case .stripe: return "Top Stripe"
        case .bands: return "Top and Bottom Bands"
        case .diagonal: return "Diagonal Stripes"
        }
    }
}

enum BannerFont: String, CaseIterable, Identifiable {
    case rounded
    case bold
    case condensed
    case serif

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .rounded: return "Rounded Sans"
        case .bold: return "Bold Sans"
        case .condensed: return "Condensed Sans"
        case .serif: return "Serif"
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .rounded: return .system(size: size, weight: .heavy, design: .rounded)
        case .bold: return .system(size: size, weight: .black, design: .default)
        case .condensed: return .system(size: size, weight: .heavy, design: .default).width(.condensed)
        case .serif: return .system(size: size, weight: .bold, design: .serif)
        }
    }
}

enum BannerDecoration: String, CaseIterable, Identifiable {
    case none
    case leaves
    case flowers
    case confetti
    case snow
    case stars
    case hearts
    case balloons
    case sea
    case sports
    case graduation
    case christmas

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .none: return "None"
        case .leaves: return "Autumn Leaves"
        case .flowers: return "Flowers"
        case .confetti: return "Celebration"
        case .snow: return "Snow"
        case .stars: return "Stars"
        case .hearts: return "Hearts"
        case .balloons: return "Balloons"
        case .sea: return "Sea"
        case .sports: return "Sports"
        case .graduation: return "Graduation"
        case .christmas: return "Christmas"
        }
    }

    var symbols: [String] {
        switch self {
        case .none: return []
        case .leaves: return ["🍂", "🍁", "🍃"]
        case .flowers: return ["🌸", "🌼", "🌷"]
        case .confetti: return ["🎉", "✨", "🎊"]
        case .snow: return ["❄️", "⛄️", "✨"]
        case .stars: return ["⭐️", "✨", "🌟"]
        case .hearts: return ["💖", "💕", "💗"]
        case .balloons: return ["🎈", "🎁", "🎈"]
        case .sea: return ["🌊", "🐚", "☀️"]
        case .sports: return ["⚽️", "🏅", "🏆"]
        case .graduation: return ["🎓", "💐", "📜"]
        case .christmas: return ["🎄", "🎁", "⭐️"]
        }
    }
}

enum BannerMaterialStyle: String, CaseIterable, Identifiable {
    case fabric
    case vinyl
    case paper

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .fabric: return "Fabric (Matte)"
        case .vinyl: return "Vinyl (Glossy)"
        case .paper: return "Paper"
        }
    }

    /// PBR roughness, 0 = mirror, 1 = fully matte
    var roughness: Float {
        switch self {
        case .fabric: return 0.92
        case .vinyl: return 0.3
        case .paper: return 0.8
        }
    }

    var clearcoat: Float {
        self == .vinyl ? 0.6 : 0
    }

    /// How much the banner droops in the middle (metres).
    var sag: Float {
        switch self {
        case .fabric: return 0.06
        case .vinyl: return 0.025
        case .paper: return 0.0
        }
    }

    /// Scale of the folds and corner pull wrinkles (0 = perfectly flat).
    var wrinkle: Float {
        switch self {
        case .fabric: return 1
        case .vinyl: return 0.35
        case .paper: return 0
        }
    }

    /// Fabric and vinyl banners have a sewn hem and metal grommets at the corners.
    var hasGrommets: Bool { self != .paper }

    /// Only cloth moves in the breeze.
    var canFlutter: Bool { self == .fabric }
}

/// A ready-made look: background, colours, typeface and decoration. The text stays the user's.
struct BannerTheme: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let background: BannerBackground
    let backgroundColor: Color
    let accentColor: Color
    let titleColor: Color
    let subtitleColor: Color
    let footerColor: Color
    let font: BannerFont
    let decoration: BannerDecoration

    static let all: [BannerTheme] = [
        BannerTheme(id: "classic", title: "Classic",
                    background: .solid, backgroundColor: .white, accentColor: rgb(0.80, 0.10, 0.12),
                    titleColor: rgb(0.80, 0.10, 0.12), subtitleColor: rgb(0.10, 0.10, 0.10), footerColor: rgb(0.30, 0.30, 0.30),
                    font: .bold, decoration: .none),
        BannerTheme(id: "autumn", title: "Autumn Outing",
                    background: .solid, backgroundColor: .white, accentColor: rgb(0.86, 0.30, 0.12),
                    titleColor: rgb(0.86, 0.30, 0.12), subtitleColor: rgb(0.12, 0.12, 0.12), footerColor: rgb(0.30, 0.30, 0.30),
                    font: .rounded, decoration: .leaves),
        BannerTheme(id: "spring", title: "Spring Blossoms",
                    background: .gradient, backgroundColor: rgb(1.00, 0.95, 0.96), accentColor: rgb(0.93, 0.42, 0.60),
                    titleColor: rgb(0.85, 0.30, 0.50), subtitleColor: rgb(0.35, 0.18, 0.26), footerColor: rgb(0.50, 0.35, 0.42),
                    font: .rounded, decoration: .flowers),
        BannerTheme(id: "summer", title: "Summer Beach",
                    background: .gradient, backgroundColor: rgb(0.88, 0.97, 1.00), accentColor: rgb(0.00, 0.55, 0.80),
                    titleColor: rgb(0.00, 0.50, 0.75), subtitleColor: rgb(0.02, 0.20, 0.35), footerColor: rgb(0.15, 0.35, 0.50),
                    font: .rounded, decoration: .sea),
        BannerTheme(id: "winter", title: "Winter",
                    background: .gradient, backgroundColor: rgb(0.93, 0.97, 1.00), accentColor: rgb(0.30, 0.55, 0.85),
                    titleColor: rgb(0.25, 0.50, 0.80), subtitleColor: rgb(0.10, 0.20, 0.40), footerColor: rgb(0.30, 0.40, 0.55),
                    font: .rounded, decoration: .snow),
        BannerTheme(id: "party", title: "Party Night",
                    background: .solid, backgroundColor: rgb(0.08, 0.10, 0.25), accentColor: rgb(0.95, 0.78, 0.30),
                    titleColor: rgb(0.95, 0.78, 0.30), subtitleColor: .white, footerColor: rgb(0.80, 0.82, 0.92),
                    font: .bold, decoration: .confetti),
        BannerTheme(id: "yearEnd", title: "Year-End Party",
                    background: .bands, backgroundColor: rgb(0.62, 0.06, 0.10), accentColor: rgb(0.93, 0.76, 0.35),
                    titleColor: rgb(0.96, 0.82, 0.45), subtitleColor: .white, footerColor: rgb(0.98, 0.88, 0.80),
                    font: .serif, decoration: .christmas),
        BannerTheme(id: "birthday", title: "Birthday",
                    background: .solid, backgroundColor: rgb(1.00, 0.97, 0.80), accentColor: rgb(0.90, 0.25, 0.55),
                    titleColor: rgb(0.90, 0.25, 0.55), subtitleColor: rgb(0.30, 0.10, 0.35), footerColor: rgb(0.45, 0.30, 0.45),
                    font: .rounded, decoration: .balloons),
        BannerTheme(id: "sports", title: "Sports Day",
                    background: .bands, backgroundColor: .white, accentColor: rgb(0.05, 0.35, 0.80),
                    titleColor: rgb(0.05, 0.35, 0.80), subtitleColor: rgb(0.05, 0.08, 0.20), footerColor: rgb(0.25, 0.30, 0.40),
                    font: .condensed, decoration: .sports),
        BannerTheme(id: "cheer", title: "Cheer",
                    background: .diagonal, backgroundColor: rgb(1.00, 0.85, 0.10), accentColor: rgb(0.10, 0.10, 0.10),
                    titleColor: rgb(0.10, 0.10, 0.10), subtitleColor: rgb(0.10, 0.10, 0.10), footerColor: rgb(0.25, 0.25, 0.25),
                    font: .condensed, decoration: .stars),
        BannerTheme(id: "graduation", title: "Graduation",
                    background: .stripe, backgroundColor: rgb(0.99, 0.97, 0.91), accentColor: rgb(0.10, 0.35, 0.25),
                    titleColor: rgb(0.10, 0.35, 0.25), subtitleColor: rgb(0.12, 0.12, 0.12), footerColor: rgb(0.35, 0.33, 0.28),
                    font: .serif, decoration: .graduation),
        BannerTheme(id: "wedding", title: "Wedding",
                    background: .solid, backgroundColor: rgb(1.00, 0.99, 0.97), accentColor: rgb(0.78, 0.62, 0.40),
                    titleColor: rgb(0.70, 0.55, 0.35), subtitleColor: rgb(0.25, 0.22, 0.20), footerColor: rgb(0.45, 0.40, 0.35),
                    font: .serif, decoration: .hearts),
        BannerTheme(id: "workshop", title: "Company Workshop",
                    background: .stripe, backgroundColor: .white, accentColor: rgb(0.06, 0.15, 0.35),
                    titleColor: rgb(0.06, 0.15, 0.35), subtitleColor: rgb(0.06, 0.15, 0.35), footerColor: rgb(0.35, 0.38, 0.45),
                    font: .condensed, decoration: .none),
    ]

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }
}

@Observable
final class BannerDesign {
    var title: String = String(localized: "2026 Our Company")
    var subtitle: String = String(localized: "Autumn Outing Together")
    var footer: String = String(localized: "Oct 24–25, 2026  Yeongildae Beach, Pohang")

    var aspect: BannerAspect = .wide
    var background: BannerBackground = .solid
    var backgroundColor: Color = .white
    var accentColor: Color = Color(red: 0.86, green: 0.30, blue: 0.12)
    var titleColor: Color = Color(red: 0.86, green: 0.30, blue: 0.12)
    var subtitleColor: Color = Color(red: 0.12, green: 0.12, blue: 0.12)
    var footerColor: Color = Color(red: 0.30, green: 0.30, blue: 0.30)

    var fontStyle: BannerFont = .rounded
    var decoration: BannerDecoration = .leaves
    var material: BannerMaterialStyle = .fabric
    var logoImage: UIImage? = nil
    var showPoles: Bool = true
    /// Fabric banners ripple gently, as if there's a light breeze.
    var flutter: Bool = true
    /// The theme last applied, for highlighting it in the picker.
    var themeID: String? = "autumn"

    /// Physical width of the banner in AR, metres.
    var widthMeters: Float = 4.0

    var heightMeters: Float { widthMeters / aspect.ratio }

    var isFluttering: Bool { flutter && material.canFlutter }

    func apply(_ theme: BannerTheme) {
        background = theme.background
        backgroundColor = theme.backgroundColor
        accentColor = theme.accentColor
        titleColor = theme.titleColor
        subtitleColor = theme.subtitleColor
        footerColor = theme.footerColor
        fontStyle = theme.font
        decoration = theme.decoration
        themeID = theme.id
    }

    /// A copy with `theme` applied, for the picker's thumbnails.
    func previewing(_ theme: BannerTheme) -> BannerDesign {
        let copy = BannerDesign()
        copy.title = title
        copy.subtitle = subtitle
        copy.footer = footer
        copy.aspect = aspect
        copy.logoImage = logoImage
        copy.material = material
        copy.apply(theme)
        return copy
    }
}
