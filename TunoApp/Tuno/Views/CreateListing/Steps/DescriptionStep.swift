import SwiftUI

struct DescriptionStep: View {
    @ObservedObject var form: ListingFormModel
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool

    var body: some View {
        WizardScreen(
            title: "Gi annonsen et navn",
            subtitle: "Tittelen er det første gjester ser i søk. Skriv noe som fanger oppmerksomhet."
        ) {
            VStack(alignment: .leading, spacing: 24) {
                titleField
                descriptionField
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Tittel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Spacer()
                Text("\(form.title.count)/50")
                    .font(.system(size: 11))
                    .foregroundStyle(form.title.count > 50 ? .red : .neutral400)
            }

            TextField(suggestedTitle, text: $form.title, axis: .vertical)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.neutral900)
                .lineLimit(1...3)
                .focused($titleFocused)
                .submitLabel(.next)
                .onSubmit { descriptionFocused = true }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(titleFocused ? Color.primary600 : Color.neutral200,
                                lineWidth: titleFocused ? 1.5 : 1)
                )

            Text("Tips: nevn beliggenhet eller noe spesielt, f.eks. \"Sjønær plass i Lofoten\".")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Beskrivelse")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("(valgfritt)")
                    .font(.system(size: 11))
                    .foregroundStyle(.neutral400)
                Spacer()
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $form.description)
                    .focused($descriptionFocused)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(descriptionFocused ? Color.primary600 : Color.neutral200,
                                    lineWidth: descriptionFocused ? 1.5 : 1)
                    )

                if form.description.isEmpty {
                    Text("Hva gjør plassen din spesiell? Utsikt, omgivelser, fasiliteter, tips til gjester …")
                        .font(.system(size: 15))
                        .foregroundStyle(.neutral400)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    /// Smart fallback når brukeren ikke har skrevet tittel selv. Speiler
    /// `buildInput`-strategien så placeholder = lagret fallback-tittel.
    private var suggestedTitle: String {
        let category = form.category?.displayName ?? "Plass"
        let location = !form.address.isEmpty ? form.address
            : !form.city.isEmpty ? form.city
            : !form.region.isEmpty ? form.region
            : "Norge"
        return "\(category) i \(location)"
    }
}
