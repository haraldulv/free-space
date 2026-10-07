import SwiftUI
import UIKit

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

// MARK: - Tuno designtokens (Asker-pivoten 2026-10-07)

/// Palett C «Kontrast» (Harald valgte 2026-10-07): svarte markedsflater
/// (hero, onboarding, booking-bar) med mint-CTA, varme papirflater der man
/// leser og blar. Tuno-grønn #46C185 beholdes som aksent/suksess, aldri
/// som stor flate.
extension Color {
    /// Mørk markedsflate (hero, booking-bar, onboarding).
    static let ink = Color(hex: "#121412")
    /// Kort/element oppå ink.
    static let inkElevated = Color(hex: "#1b1e1b")
    static let inkText = Color(hex: "#f5f6f4")
    static let inkMuted = Color(hex: "#a8afaa")
    /// Varm papirbakgrunn for innholdsflater (erstatter ren hvit/neutral50).
    static let paper = Color(hex: "#f4f1ea")
    /// Kort på papir.
    static let paperCard = Color(hex: "#fdfcf9")
    static let paperLine = Color(hex: "#e8e5dc")
    /// CTA-farge på mørke flater (SeniorSupport-mint).
    static let mint = Color(hex: "#37caa4")
    /// Tekst på mint.
    static let mintInk = Color(hex: "#13201c")
}

/// Typografi-skalaen for det nye parkering-designet. Schibsted Grotesk bundles via
/// UIAppFonts (project.yml). KUN nye/omskrevne flater bruker Font.tuno —
/// de gamle .font(.system(...))-kallene konverteres opportunistisk, aldri
/// med global erstatning.
enum TunoTextStyle {
    case display    // store hero-tall/-titler
    case title      // skjermtitler
    case heading    // seksjonsoverskrifter
    case body       // brødtekst
    case label      // knapper, chips
    case caption    // småtekst

    var size: CGFloat {
        switch self {
        case .display: return 34
        case .title: return 24
        case .heading: return 18
        case .body: return 15
        case .label: return 13
        case .caption: return 12
        }
    }

    var fontName: String {
        switch self {
        case .display, .title: return "SchibstedGrotesk-Bold"
        case .heading: return "SchibstedGrotesk-SemiBold"
        case .body: return "SchibstedGrotesk-Medium"
        case .label: return "SchibstedGrotesk-SemiBold"
        case .caption: return "SchibstedGrotesk-Medium"
        }
    }
}

extension Font {
    /// Schibsted Grotesk i fast skala. Bruk denne på alle nye flater.
    static func tuno(_ style: TunoTextStyle) -> Font {
        .custom(style.fontName, size: style.size)
    }

    /// Schibsted Grotesk med eksplisitt størrelse der skalaen ikke passer.
    static func tuno(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "SchibstedGrotesk-Bold"
        case .semibold: name = "SchibstedGrotesk-SemiBold"
        case .regular, .light, .thin, .ultraLight: name = "SchibstedGrotesk-Regular"
        default: name = "SchibstedGrotesk-Medium"
        }
        return .custom(name, size: size)
    }
}

/// Hjørneradier for det nye designet.
enum TunoRadius {
    static let control: CGFloat = 12
    static let card: CGFloat = 20
    static let pill: CGFloat = 100
}

enum TunoShadow {
    /// Standard kort-skygge: myk, lav.
    static let cardColor = Color.black.opacity(0.08)
    static let cardRadius: CGFloat = 10
    static let cardY: CGFloat = 3
}

/// Rund knapp i palett C. `ink` (standard) på lyse flater, `mint` som CTA
/// på mørke flater, `outline` som sekundær.
struct TunoPillButtonStyle: ButtonStyle {
    enum Variant { case ink, mint, outline }
    var variant: Variant = .ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tuno(size: 16, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(background)
            .overlay(
                Capsule().stroke(variant == .outline ? Color.neutral900 : .clear, lineWidth: 1.5)
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .ink: return .white
        case .mint: return .mintInk
        case .outline: return .neutral900
        }
    }

    private var background: Color {
        switch variant {
        case .ink: return .ink
        case .mint: return .mint
        case .outline: return .white
        }
    }
}

#if DEBUG
/// Fanger en glemt UIAppFonts-linje umiddelbart i stedet for stille
/// systemfont-fallback. Kalles fra TunoApp.init.
func assertTunoFontsLoaded() {
    for name in ["SchibstedGrotesk-Regular", "SchibstedGrotesk-Medium", "SchibstedGrotesk-SemiBold", "SchibstedGrotesk-Bold"] {
        assert(UIFont(name: name, size: 12) != nil, "Mangler font \(name) — sjekk UIAppFonts i project.yml + xcodegen generate")
    }
}
#endif