import SwiftUI

extension Color {
    // Primary Tuno green palette (brand: #46C185)
    static let primary50 = Color(hex: "#ecfaf3")
    static let primary100 = Color(hex: "#d4f4e3")
    static let primary200 = Color(hex: "#a9e8c6")
    static let primary300 = Color(hex: "#7edaa7")
    static let primary400 = Color(hex: "#5fcf96")
    static let primary500 = Color(hex: "#4dc88c")
    static let primary600 = Color(hex: "#46c185")
    static let primary700 = Color(hex: "#34a06b")

    // Neutral palette
    static let neutral50 = Color(hex: "#fafafa")
    static let neutral100 = Color(hex: "#f5f5f5")
    static let neutral200 = Color(hex: "#e5e5e5")
    static let neutral300 = Color(hex: "#d4d4d4")
    static let neutral400 = Color(hex: "#a3a3a3")
    static let neutral500 = Color(hex: "#737373")
    static let neutral600 = Color(hex: "#525252")
    static let neutral700 = Color(hex: "#404040")
    static let neutral800 = Color(hex: "#262626")
    static let neutral900 = Color(hex: "#171717")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// ShapeStyle extensions so .foregroundStyle(.neutral900) works without "Color." prefix
extension ShapeStyle where Self == Color {
    static var primary50: Color { Color.primary50 }
    static var primary100: Color { Color.primary100 }
    static var primary200: Color { Color.primary200 }
    static var primary300: Color { Color.primary300 }
    static var primary400: Color { Color.primary400 }
    static var primary500: Color { Color.primary500 }
    static var primary600: Color { Color.primary600 }
    static var primary700: Color { Color.primary700 }
    static var neutral50: Color { Color.neutral50 }
    static var neutral100: Color { Color.neutral100 }
    static var neutral200: Color { Color.neutral200 }
    static var neutral300: Color { Color.neutral300 }
    static var neutral400: Color { Color.neutral400 }
    static var neutral500: Color { Color.neutral500 }
    static var neutral600: Color { Color.neutral600 }
    static var neutral700: Color { Color.neutral700 }
    static var neutral800: Color { Color.neutral800 }
    static var neutral900: Color { Color.neutral900 }
}

extension Font {
    static func dmSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
