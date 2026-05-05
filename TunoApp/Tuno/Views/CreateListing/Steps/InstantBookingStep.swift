import SwiftUI

struct InstantBookingStep: View {
    @ObservedObject var form: ListingFormModel

    @FocusState private var focusedField: StayField?

    private enum StayField { case min, max }

    private var unitWord: String {
        // dag for parkering, døgn for camping. Brukes i hjelpe-tekster.
        form.category == .parking ? "dag" : "døgn"
    }

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

                stayLengthCard
            }
        }
        .safeAreaInset(edge: .bottom) {
            if focusedField != nil {
                doneBar
            }
        }
    }

    /// Min/maks antall dager-card.
    private var stayLengthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary600)
                Text("Lengde på opphold")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.neutral900)
            }
            Text("Du kan kreve at gjester booker minst eller høyst et visst antall \(unitWord). La være tom hvis ingen grense.")
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)

            HStack(spacing: 12) {
                stayField(label: "Minimum", binding: $form.minStayDays, focus: .min)
                stayField(label: "Maksimum", binding: $form.maxStayDays, focus: .max)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.neutral200, lineWidth: 1))
    }

    @ViewBuilder
    private func stayField(label: String, binding: Binding<Int?>, focus: StayField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
            HStack(spacing: 8) {
                TextField("Ingen", value: binding, format: .number)
                    .focused($focusedField, equals: focus)
                    .keyboardType(.numberPad)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text(unitWord)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Floating "Ferdig"-knapp for tallpaddet (samme mønster som CreateListingView).
    private var doneBar: some View {
        HStack {
            Spacer()
            Button {
                focusedField = nil
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.primary600)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 8)
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
