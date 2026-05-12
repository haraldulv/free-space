import SwiftUI

/// For topp-nivå kort som er individuelle objekter (ProfileSummaryCard,
/// HostInntektCard, becomeHostCard, logoutRow). Krymper subtilt + tinter
/// bg ved press — kombinert "lift away" + "darken" feedback.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .overlay(
                Color.black
                    .opacity(configuration.isPressed ? 0.04 : 0)
                    .allowsHitTesting(false)
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// For rader inni en card-seksjon (menuRow). Skalerer IKKE — bare bg-tint
/// — fordi stablede rader som krymper ser merkelig ut. Etterligner standard
/// iOS Cell-pressed state.
struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color.neutral200.opacity(configuration.isPressed ? 0.5 : 0)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
