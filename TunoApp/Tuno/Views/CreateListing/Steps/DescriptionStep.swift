import SwiftUI

struct DescriptionStep: View {
    @ObservedObject var form: ListingFormModel
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool

    /// Hvis annonsen kun har én plass blir beskrivelsen lagt inn per plass i
    /// neste steg, og speilet ned til annonse-beskrivelsen ved lagring. Da
    /// skjuler vi annonse-beskrivelsen her for å unngå dobbeltarbeid.
    private var showListingDescription: Bool { form.spots > 1 }

    var body: some View {
        WizardScreen(
            title: "Gi annonsen et navn",
            subtitle: "Tittelen er det første gjester ser i søk. Skriv noe som fanger oppmerksomhet."
        ) {
            VStack(alignment: .leading, spacing: 24) {
                titleField
                if showListingDescription {
                    descriptionField
                }
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

            // Foreslag-knapp: tap for å fylle inn forslag-teksten direkte.
            // Vises kun når feltet er tomt så den ikke surrer rundt etter
            // brukeren har skrevet noe.
            if form.title.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    form.title = suggestedTitle
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Bruk forslag: \(suggestedTitle)")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.primary700)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary50)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Text("Tips: nevn beliggenhet eller noe spesielt, f.eks. \"Sjønær plass i Lofoten\".")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Beskrivelse for hele annonsen")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("(valgfritt)")
                    .font(.system(size: 11))
                    .foregroundStyle(.neutral400)
                Spacer()
            }

            Text("Dette vises øverst på annonsen. Hver plass kan ha sin egen beskrivelse i tillegg.")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)

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
