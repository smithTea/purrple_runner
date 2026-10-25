import SwiftUI

/// Design tokens. Neutrals, spacing, radii and mini-player metrics mirror the
/// values found in the Android app's resources (Encore design system); the
/// accent green is swapped for purple.
enum Theme {
    // MARK: Colors

    static let background = Color(hex: 0x121212)
    static let surface = Color(hex: 0x181818)
    static let elevated = Color(hex: 0x282828)
    static let highlight = Color(hex: 0x333333)
    static let divider = Color(hex: 0x535353)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xB3B3B3)

    static let accent = Color(hex: 0xA855F7)
    static let accentBright = Color(hex: 0xC084FC)
    static let accentDark = Color(hex: 0x6B21A8)

    /// Tile colors for the Search "browse" grid.
    static let tileColors: [Color] = [
        Color(hex: 0x509BF5), Color(hex: 0xC87D55), Color(hex: 0x19A86A),
        Color(hex: 0xB49BC8), Color(hex: 0xFF6437), Color(hex: 0xF573A0),
        Color(hex: 0x8D67AB), Color(hex: 0x1E3264), Color(hex: 0xE8115B),
    ]

    // MARK: Spacing

    enum Spacing {
        static let tighter5: CGFloat = 2
        static let tighter4: CGFloat = 4
        static let tighter3: CGFloat = 6
        static let tighter2: CGFloat = 8
        static let tighter: CGFloat = 12
        static let base: CGFloat = 16
        static let looser: CGFloat = 20
        static let looser2: CGFloat = 24
        static let looser3: CGFloat = 32
        static let looser4: CGFloat = 40
        static let looser5: CGFloat = 48
        static let looser6: CGFloat = 64
    }

    // MARK: Corner radii

    enum Radius {
        static let smaller: CGFloat = 2
        static let base: CGFloat = 4
        static let larger: CGFloat = 6
        static let larger2: CGFloat = 8
        static let larger3: CGFloat = 16
    }

    // MARK: Floating mini player

    enum MiniPlayer {
        static let height: CGFloat = 56
        static let margin: CGFloat = 8
        static let contentPadding: CGFloat = 8
        static let artworkSize: CGFloat = 40
        static let artworkRadius: CGFloat = 4
        static let buttonSize: CGFloat = 40
        static let cornerRadius: CGFloat = 8
        static let progressHeight: CGFloat = 2
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension Font {
    static let purrTitle = Font.system(size: 24, weight: .bold)
    static let purrSection = Font.system(size: 20, weight: .bold)
    static let purrBody = Font.system(size: 15, weight: .regular)
    static let purrBodyBold = Font.system(size: 15, weight: .semibold)
    static let purrCaption = Font.system(size: 13, weight: .regular)
    static let purrCaptionBold = Font.system(size: 13, weight: .semibold)
}

func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let total = Int(seconds.rounded(.down))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}
