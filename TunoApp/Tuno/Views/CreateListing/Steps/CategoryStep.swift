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
                    subtitle: "Bobil, campingvogn eller telt",
                    assetName: "category-camping"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        form.setCategory(.camping)
                    }
                }

                CategoryCard(
                    isSelected: form.category == .parking,
                    title: "Parkering",
                    subtitle: "Pendlere, beboere eller lading",
                    assetName: "category-parking"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        form.setCategory(.parking)
                    }
                }
            }
        }
    }
}

private struct CategoryCard: View {
    let isSelected: Bool
    let title: String
    let subtitle: String
    let assetName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isSelected ? Color.primary50 : Color.neutral50)
                            .frame(width: 72, height: 72)
                        Image(assetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56, height: 56)
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
