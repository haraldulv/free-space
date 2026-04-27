import SwiftUI

struct InstantBookingStep: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        WizardScreen(
            title: "Hvordan vil du ta imot bestillinger?",
            subtitle: "Du kan endre dette senere fra Mine annonser."
        ) {
            VStack(spacing: 16) {
                BookingModeCard(
                    isSelected: form.instantBooking,
                    iconName: "bolt.fill",
                    title: "Direktebooking",
                    subtitle: "Gjester booker rett inn uten å vente på svar. Anbefales for flere bookinger."
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        form.instantBooking = true
                    }
                }

                BookingModeCard(
                    isSelected: !form.instantBooking,
                    iconName: "hand.raised.fill",
                    title: "Godkjenn først",
                    subtitle: "Du får en forespørsel og må godkjenne hver bestilling innen 24 timer."
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        form.instantBooking = false
                    }
                }
            }
        }
    }
}

private struct BookingModeCard: View {
    let isSelected: Bool
    let iconName: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isSelected ? Color.primary600 : Color.primary50)
                            .frame(width: 72, height: 72)
                        Image(systemName: iconName)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(isSelected ? .white : .primary700)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? .primary600 : .neutral300)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral500)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.primary50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? Color.primary600.opacity(0.15) : .clear, radius: 10, y: 3)
        }
        .buttonStyle(.plain)
    }
}
