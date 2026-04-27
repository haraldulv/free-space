import SwiftUI

struct AmenitiesStep: View {
    @ObservedObject var form: ListingFormModel

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        WizardScreen(
            title: "Har du noe mer å tilby?",
            subtitle: "Velg fasiliteter som er tilgjengelige for gjester på adressen."
        ) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(form.availableAmenities, id: \.rawValue) { amenity in
                    let selected = form.selectedAmenities.contains(amenity.rawValue)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            if selected {
                                form.selectedAmenities.remove(amenity.rawValue)
                            } else {
                                form.selectedAmenities.insert(amenity.rawValue)
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: amenity.icon)
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(selected ? .white : .primary700)
                                .frame(width: 36, height: 36)
                                .background(selected ? Color.primary600 : Color.primary50)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Text(amenity.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.neutral900)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 86)
                        .background(selected ? Color.primary50 : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: selected ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
