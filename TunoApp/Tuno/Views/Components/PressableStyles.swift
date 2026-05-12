import SwiftUI

/// For topp-nivå kort som er individuelle objekter (ProfileSummaryCard,
/// HostInntektCard, becomeHostCard, logoutRow). Krymper med en punchy
/// spring + tinter bg ved press — "zwoop"-feel: flytende og levende.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .overlay(
                Color.black
                    .opacity(configuration.isPressed ? 0.04 : 0)
                    .allowsHitTesting(false)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// For rader inni en gruppert container (menuRow). Kombinerer subtil scale
/// + bg-tint overlay for "zwoop inn"-feedback. Overlay (ikke background)
/// så tinten respekterer containerens clipShape og ikke lekker utenfor.
struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .overlay(
                Color.neutral200
                    .opacity(configuration.isPressed ? 0.45 : 0)
                    .allowsHitTesting(false)
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}
