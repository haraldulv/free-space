import SwiftUI

/// Steg 4 i parkering-wizarden: oppsummering, valgfri tittel/beskrivelse,
/// obligatorisk «jeg har rett til å leie ut»-bekreftelse og praktiske noter.
struct ParkingPublishStep: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Klar til å publisere?")
                        .font(.tuno(.title))
                        .foregroundStyle(.neutral900)
                    Text("Sjekk at alt stemmer. Du kan endre alt senere.")
                        .font(.tuno(.body))
                        .foregroundStyle(.neutral600)
                }

                summaryCard

                // Valgfri tittel + beskrivelse
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tittel (valgfritt)")
                            .font(.tuno(.label))
                            .foregroundStyle(.neutral600)
                        TextField(autoTitlePlaceholder, text: $form.title)
                            .font(.tuno(.body))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: TunoRadius.control)
                                    .stroke(Color.neutral200, lineWidth: 1)
                            )
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Beskrivelse (valgfritt)")
                            .font(.tuno(.label))
                            .foregroundStyle(.neutral600)
                        TextField("F.eks. innkjøring fra gaten, lys og kamera", text: $form.description, axis: .vertical)
                            .font(.tuno(.body))
                            .lineLimit(3...6)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: TunoRadius.control)
                                    .stroke(Color.neutral200, lineWidth: 1)
                            )
                    }
                }

                // Obligatorisk eierskap-bekreftelse
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        form.hasConfirmedOwnership.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: form.hasConfirmedOwnership ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .foregroundStyle(form.hasConfirmedOwnership ? Color.primary600 : .neutral400)
                        Text("Jeg har rett til å leie ut denne plassen")
                            .font(.tuno(.body))
                            .foregroundStyle(.neutral900)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: TunoRadius.control)
                            .stroke(form.hasConfirmedOwnership ? Color.primary600 : Color.neutral200, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Praktiske noter
                VStack(alignment: .leading, spacing: 10) {
                    if form.hideExactLocation {
                        noteRow(icon: "lock.fill", text: "Eksakt adresse deles først etter bekreftet booking.")
                    }
                    noteRow(icon: "snowflake", text: "Du har ansvar for snømåking og tilgang til plassen.")
                    noteRow(icon: "checkmark.shield.fill", text: "Annonsen godkjennes av Tuno før den blir synlig.")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private var autoTitlePlaceholder: String {
        let typeName: String = {
            switch form.parkingType {
            case .garage: return "Garasjeplass"
            case .parkingHouse: return "P-husplass"
            default: return "Parkeringsplass"
            }
        }()
        let place = form.city.isEmpty ? "Asker" : form.city
        return "\(typeName) i \(place)"
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow(label: "Adresse", value: form.address)
            Divider()
            summaryRow(label: "Type", value: form.parkingType?.displayName ?? "Utendørs")
            Divider()
            summaryRow(label: "Plasser", value: "\(form.spots)")
            Divider()
            summaryRow(label: "Dagsleie", value: form.parkingDailyPrice.map { "\($0) kr" } ?? "")
            Divider()
            summaryRow(label: "Månedsplass", value: form.parkingMonthlyPrice.map { "\($0) kr" } ?? "")
            Divider()
            summaryRow(label: "Bilder", value: "\(form.imageURLs.count)")
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: TunoRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: TunoRadius.card)
                .stroke(Color.neutral200, lineWidth: 1)
        )
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.tuno(.body))
                .foregroundStyle(.neutral500)
            Spacer()
            Text(value)
                .font(.tuno(.body))
                .foregroundStyle(.neutral900)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func noteRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .frame(width: 20)
            Text(text)
                .font(.tuno(.caption))
                .foregroundStyle(.neutral600)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
