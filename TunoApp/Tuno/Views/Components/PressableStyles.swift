import SwiftUI

/// For topp-nivå kort som er individuelle objekter (ProfileSummaryCard,
/// HostInntektCard, becomeHostCard, logoutRow). Krymper med en punchy
/// spring + tinter bg ved press — "zwoop"-feel: flytende og levende.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .overlay(
                Color.black
                    .opacity(configuration.isPressed ? 0.06 : 0)
                    .allowsHitTesting(false)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// For separate rad-cards (menuRow). Samme dramatiske "zwoop"-feel som
/// topp-nivå-kortene — scale 0.94 + spring + bg-tint så det er tydelig
/// at hver rad er et eget kort som krymper inn ved press.
struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .overlay(
                Color.neutral200
                    .opacity(configuration.isPressed ? 0.6 : 0)
                    .allowsHitTesting(false)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
