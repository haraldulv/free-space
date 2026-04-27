import SwiftUI

struct AddressStep: View {
    @ObservedObject var form: ListingFormModel
    @ObservedObject var placesService: PlacesService

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        WizardScreen(
            title: "Hva er adressen din?",
            subtitle: "Søk etter adresse. Vi bruker dette til å vise annonsen på kartet for gjester."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                WizardTooltip(
                    title: "Tips: Én adresse, flere plasser",
                    message: "Du kan ha flere plasser på samme adresse, for eksempel 5 bobilplasser i en hage. Gjester kan reservere én plass av gangen."
                )

                // Søkefelt
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.neutral400)
                        TextField("Søk etter adresse...", text: $searchText)
                            .font(.system(size: 17))
                            .focused($isSearchFocused)
                            .textInputAutocapitalization(.words)
                            .onChange(of: searchText) { _, newValue in
                                placesService.autocomplete(query: newValue)
                            }
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                placesService.clear()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.neutral400)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.neutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if !placesService.predictions.isEmpty && isSearchFocused {
                        VStack(spacing: 0) {
                            ForEach(placesService.predictions) { prediction in
                                Button {
                                    selectPlace(prediction)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.primary600)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(prediction.mainText)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(.neutral900)
                                                .lineLimit(1)
                                            Text(prediction.secondaryText)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.neutral500)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                }
                                .buttonStyle(.plain)
                                if prediction.id != placesService.predictions.last?.id {
                                    Divider().padding(.leading, 46)
                                }
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                        .padding(.top, 4)
                    }
                }

                if !form.address.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.primary600)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(form.address)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.neutral900)
                            if !form.city.isEmpty {
                                Text("\(form.city)\(form.region.isEmpty ? "" : ", " + form.region)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.neutral500)
                            }
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary200, lineWidth: 1))
                    .transition(.opacity)
                }

                // Skjul-toggle (diskret nederst)
                Toggle(isOn: $form.hideExactLocation) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.neutral500)
                            Text("Skjul eksakt adresse")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.neutral900)
                        }
                        Text("Gjester ser et omtrentlig område. Eksakt adresse deles etter booking.")
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                            .lineSpacing(2)
                    }
                }
                .tint(.primary600)
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
            }
        }
    }

    private func selectPlace(_ prediction: PlacePrediction) {
        Task {
            if let detail = await placesService.getPlaceDetail(placeId: prediction.id) {
                form.lat = detail.lat
                form.lng = detail.lng
                form.address = prediction.mainText
                // Forsøk å parse "By, Region" fra secondary text
                let parts = prediction.secondaryText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 1 { form.city = parts[0] }
                if parts.count >= 2 { form.region = parts[1] }
                searchText = ""
                placesService.clear()
                isSearchFocused = false
            }
        }
    }
}
