import SwiftUI
import UIKit
import CoreText
import BrainCore

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// 视频里的黑金配色
enum Palette {
    static let ink = Color(hex: 0x100D0A)
    static let ink2 = Color(hex: 0x1A1612)
    static let ink3 = Color(hex: 0x27211A)
    static let card = Color(hex: 0x1F1A15)
    static let cardHi = Color(hex: 0x2A231B)
    static let line = Color(hex: 0x3D3428)
    static let lineHi = Color(hex: 0x5A4C38)

    static let gold = Color(hex: 0xD9BC82)
    static let goldDeep = Color(hex: 0xB0925F)
    static let goldDark = Color(hex: 0x7C6440)
    static let goldBright = Color(hex: 0xF4DEAA)

    static let cream = Color(hex: 0xEFE6D4)
    static let muted = Color(hex: 0x9A8C74)
    static let faint = Color(hex: 0x62574A)

    static let red = Color(hex: 0xC8604E)
    static let green = Color(hex: 0x5F9E70)
    static let yellow = Color(hex: 0xD8B54C)
    static let blue = Color(hex: 0x5B88BE)
    static let purple = Color(hex: 0x9A78C4)
    static let orange = Color(hex: 0xD98C46)
    static let pink = Color(hex: 0xDA9BB6)
    static let gray = Color(hex: 0x9EA1A8)
    static let brown = Color(hex: 0xA57A52)

    /// 分类桶的复古底色
    static let bucketRed = Color(hex: 0x9C4C3E)
    static let bucketBlue = Color(hex: 0x3F6688)
    static let bucketGreen = Color(hex: 0x3E7457)

    static let goldGradient = LinearGradient(colors: [goldBright, gold, goldDeep],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)

    static func inkColor(_ c: InkColor) -> Color {
        switch c {
        case .red: return red
        case .green: return green
        case .yellow: return yellow
        case .blue: return blue
        case .purple: return purple
        case .orange: return orange
        }
    }

    static func hue(_ h: ItemHue) -> Color {
        switch h {
        case .gold: return gold
        case .red: return red
        case .blue: return blue
        case .green: return green
        case .purple: return purple
        case .gray: return gray
        case .orange: return orange
        case .pink: return pink
        case .brown: return brown
        case .cream: return cream
        }
    }

    static func tint(_ t: TintChoice) -> Color {
        switch t {
        case .red: return red
        case .blue: return blue
        case .green: return green
        }
    }

    static func bucket(_ i: Int) -> Color {
        [bucketRed, bucketBlue, bucketGreen][((i % 3) + 3) % 3]
    }
}

/// 宋体（思源宋体子集，CI 打包时生成）；没有就退回系统衬线体
enum AppFont {
    private(set) static var regular: String?
    private(set) static var bold: String?
    private static var registered = false

    static func register() {
        guard !registered else { return }
        registered = true
        let urls = (Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: "Fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            guard let provider = CGDataProvider(url: url as CFURL),
                  let font = CGFont(provider),
                  let cfName = font.postScriptName else { continue }
            let name = cfName as String
            if name.lowercased().contains("bold") || name.lowercased().contains("black") {
                bold = name
            } else {
                regular = name
            }
        }
    }

    static var isBundled: Bool { regular != nil }
}

extension Font {
    enum SongWeight { case regular, bold }

    static func song(_ size: CGFloat, _ weight: SongWeight = .regular) -> Font {
        switch weight {
        case .regular:
            if let n = AppFont.regular { return .custom(n, size: size) }
            return .system(size: size, weight: .regular, design: .serif)
        case .bold:
            if let n = AppFont.bold ?? AppFont.regular { return .custom(n, size: size) }
            return .system(size: size, weight: .bold, design: .serif)
        }
    }

    /// 数字用等宽衬线，计时不跳动
    static func digits(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif).monospacedDigit()
    }
}

enum Haptic {
    static var enabled = true

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func soft() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func heavy() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
