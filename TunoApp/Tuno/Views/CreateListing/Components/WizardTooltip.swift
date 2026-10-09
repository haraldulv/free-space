import SwiftUI

/// Leken bobble med info-ikon. Tap for å vise/skjule fyldig forklaring.
/// Brukt på AddressStep ("én adresse, flere plasser") + SpotCountStep.
struct WizardTooltip: View {
    let title: String
    let message: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.appTint)
                            .frame(width: 26, height: 26)
                        Image(systemName: expanded ? "chevron.up" : "lightbulb.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.appAccentDeep)
                    }
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.appAccentDeep)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color.appTintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.appTintLine, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if expanded {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral700)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appTintSoft.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
