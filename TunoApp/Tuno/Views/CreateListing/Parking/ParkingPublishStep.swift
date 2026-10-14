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

                // Direktebestilling vs. forespørsel
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hvordan vil du motta bestillinger?")
                        .font(.tuno(.heading))
                        .foregroundStyle(.neutral900)
                    bookingModeCard(
                        isSelected: form.instantBooking,
                        icon: "bolt.fill",
                        title: "Direktebestilling",
                        subtitle: "Leietaker booker og betaler med en gang. Gir flest bestillinger."
                    ) { form.instantBooking = true }
                    bookingModeCard(
                        isSelected: !form.instantBooking,
                        icon: "hand.raised.fill",
                        title: "På forespørsel",
                        subtitle: "Du godkjenner hver bestilling før den gjennomføres."
                    ) { form.instantBooking = false }
                }

                // Tittel (påkrevd, med forslag) + valgfri beskrivelse
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tittel")
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
                        if form.title.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    form.title = autoTitlePlaceholder
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Bruk forslag: \(autoTitlePlaceholder)")
                                        .font(.tuno(.label))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(Color.mintInk)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.mint.opacity(0.14))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
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
                            .foregroundStyle(form.hasConfirmedOwnership ? Color.mint : .neutral400)
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
                            .stroke(form.hasConfirmedOwnership ? Color.mint : Color.neutral200, lineWidth: form.hasConfirmedOwnership ? 1.5 : 1)
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
        // Uten by: ikke gjett geografi — bare plasstypen.
        return form.city.isEmpty ? typeName : "\(typeName) i \(form.city)"
    }

    /// Stort valgbart kort for bestillingsmåte — mint-markering ved valg.
    private func bookingModeCard(isSelected: Bool, icon: String, title: String, subtitle: String, onTap: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { onTap() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.mint.opacity(0.18) : Color.neutral100)
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.mintInk : Color.neutral500)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.tuno(.body))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.tuno(.caption))
                        .foregroundStyle(.neutral600)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.mint : Color.neutral300)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: TunoRadius.control)
                    .stroke(isSelected ? Color.mint : Color.neutral200, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
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
            summaryRow(label: "Bestilling", value: form.instantBooking ? "Direkte" : "På forespørsel")
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
