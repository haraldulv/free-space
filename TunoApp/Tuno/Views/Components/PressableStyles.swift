import SwiftUI

// MARK: - CardPosition

/// Posisjon av et kort innen en seksjon med flere kort. Bestemmer
/// hjørne-radius for `UnevenRoundedRectangle`. Kortene er separate views
/// med 2pt gap mellom — det er kantet-stilen som lager den visuelle
/// seksjonen, ikke at de er joined i én container.
enum CardPosition {
    case only       // alene i sin seksjon — alle 4 hjørner 12pt
    case first      // øverste av flere — top 12pt, bottom 2pt
    case middle     // i midten — alle hjørner 2pt
    case last       // nederste av flere — top 2pt, bottom 12pt

    /// Returnerer riktig CardPosition for et kort basert på indeks og total
    /// antall kort i seksjonen.
    static func at(index: Int, total: Int) -> CardPosition {
        if total <= 1 { return .only }
        if index == 0 { return .first }
        if index == total - 1 { return .last }
        return .middle
    }

    var topRadius: CGFloat {
        switch self {
        case .only, .first: return 12
        case .middle, .last: return 2
        }
    }

    var bottomRadius: CGFloat {
        switch self {
        case .only, .last: return 12
        case .first, .middle: return 2
        }
    }

    /// Den faktiske Shape-en — UnevenRoundedRectangle med riktig kombinasjon
    /// av runde og nesten-firkantede hjørner.
    var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: .init(
            topLeading: topRadius,
            bottomLeading: bottomRadius,
            bottomTrailing: bottomRadius,
            topTrailing: topRadius
        ))
    }
}

// MARK: - GroupedCardButtonStyle

/// ButtonStyle for trykkbare kort i en seksjon. Bakgrunn er konstant —
/// kun scale gir press-feedback. Begge retninger bruker spring slik at
/// effekten føles smooth (ikke hakket). Inn-spring er kort uten overshoot
/// så det svarer raskt; ut-spring er lengre med liten bounce som matcher
/// NT-feelen. Effekten forblir aktiv så lenge fingeren er nede via
/// configuration.isPressed.
struct GroupedCardButtonStyle: ButtonStyle {
    let position: CardPosition

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(position.shape)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.2, dampingFraction: 0.75)
                    : .spring(response: 0.4, dampingFraction: 0.55),
                value: configuration.isPressed
            )
    }
}

// MARK: - PressableCardStyle

/// Brukes på topp-nivå-kort som IKKE er del av en seksjon med flere kort
/// (ProfileSummaryCard, HostInntektCard, becomeHostCard, logoutRow). Disse
/// har egen bakgrunn/shape fra eksisterende komponenter — denne stilen
/// gir kun press-feedback uten å overskrive layout.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .overlay(
                Color.black
                    .opacity(configuration.isPressed ? 0.04 : 0)
                    .allowsHitTesting(false)
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
