import SwiftUI

struct CategoryStep: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        WizardScreen(
            title: "Hva vil du leie ut?",
            subtitle: "Dette hjelper gjester å finne riktig plass for sitt behov."
        ) {
            VStack(spacing: 16) {
                CategoryCard(
                    isSelected: form.category == .camping,
                    title: "Camping",
                    subtitle: "Per natt · for bobil, campingvogn eller telt",
                    iconName: "tent.fill"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        form.setCategory(.camping)
                    }
                }

                CategoryCard(
                    isSelected: form.category == .parking,
                    title: "Parkering",
                    subtitle: "Per time eller døgn · pendlere, beboere eller lading",
                    iconName: "car.fill"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        form.setCategory(.parking)
                    }
                }

                if form.category == .parking {
                    parkingPricingPicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var parkingPricingPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hvordan vil du prise plassen?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.neutral900)
            Text("Du kan sette ulike priser for arbeidstid, kveld og helg under Kalender → Prisregler etter publisering.")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)

            HStack(spacing: 8) {
                pricingOption(unit: .hour, label: "Per time", subtitle: "Korttidsparkering")
                pricingOption(unit: .time, label: "Per døgn", subtitle: "Langtidsparkering")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200, lineWidth: 1))
    }

    private func pricingOption(unit: PriceUnit, label: String, subtitle: String) -> some View {
        let selected = form.priceUnit == unit
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                form.priceUnit = unit
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selected ? .primary700 : .neutral900)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(selected ? .primary600 : .neutral300)
                }
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.neutral500)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.primary50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryCard: View {
    let isSelected: Bool
    let title: String
    let subtitle: String
    let iconName: String
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
                        .lineLimit(2)
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
