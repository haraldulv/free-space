import SwiftUI

/// Mini-wizard for tilgjengelighets-bånd per plass (steg 6 — kun parkering).
/// Brukeren velger "Alltid ledig" eller setter ukedags-bånd som man-fre 9-17.
/// Båndene lagres i ListingFormModel.availabilityBySpotId og persisteres som
/// listing_pricing_rules (kind='hourly') med spot_id ved publisering.
struct SpotAvailabilityStep: View {
    @ObservedObject var form: ListingFormModel
    @State private var showAddBandSheet = false
    @State private var bandSheetPrefill: BandPrefill?

    private var spot: SpotMarker? {
        form.spotMarkers.indices.contains(form.currentSpotIndex)
            ? form.spotMarkers[form.currentSpotIndex]
            : nil
    }

    private var spotId: String? { spot?.id }

    private var availability: WizardSpotAvailability {
        guard let id = spotId else { return WizardSpotAvailability() }
        return form.availability(for: id)
    }

    var body: some View {
        TabView(selection: $form.currentSpotIndex) {
            ForEach(Array(form.spotMarkers.indices), id: \.self) { index in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header(index: index)
                        modeCards(spotIndex: index)
                        if !availability.alwaysAvailable {
                            bandsSection(spotIndex: index)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.28), value: form.currentSpotIndex)
        .sheet(isPresented: $showAddBandSheet) {
            AddHourlyBandSheet(
                basePrice: 0,
                prefill: bandSheetPrefill,
                mode: .availability
            ) { dayMask, startHour, endHour, _ in
                addBand(dayMask: dayMask, startHour: startHour, endHour: endHour)
            }
            .id(bandSheetPrefill?.id ?? "blank")
        }
    }

    @ViewBuilder
    private func header(index: Int) -> some View {
        let total = form.spotMarkers.count
        VStack(alignment: .leading, spacing: 6) {
            Text(total == 1 ? "Når er plassen ledig?" : "Når er plass \(index + 1) ledig?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Velg om plassen alltid er ledig, eller sett bestemte tider den kan leies ut.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
        }
    }

    @ViewBuilder
    private func modeCards(spotIndex: Int) -> some View {
        let isAlways = availability.alwaysAvailable
        VStack(spacing: 12) {
            modeCard(
                isSelected: isAlways,
                icon: "clock.fill",
                title: "Alltid ledig",
                subtitle: "Plassen er åpen 24/7. Gjester kan booke når som helst."
            ) {
                setAlwaysAvailable(true, spotIndex: spotIndex)
            }
            modeCard(
                isSelected: !isAlways,
                icon: "calendar.badge.clock",
                title: "Sett tider",
                subtitle: "Velg hvilke ukedager og klokkeslett plassen er åpen."
            ) {
                setAlwaysAvailable(false, spotIndex: spotIndex)
            }
        }
    }

    @ViewBuilder
    private func modeCard(
        isSelected: Bool,
        icon: String,
        title: String,
        subtitle: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.primary600 : Color.neutral100)
                        .frame(width: 40, height: 40)
                    Image(systemName: isSelected ? "checkmark" : icon)
                        .font(.system(size: isSelected ? 17 : 16, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .neutral500)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral600)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.neutral400)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func bandsSection(spotIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Åpningstider")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.neutral900)

            // Eksisterende bånd
            ForEach(availability.bands) { band in
                bandRow(band: band, spotIndex: spotIndex)
            }

            // Hurtigvalg
            VStack(alignment: .leading, spacing: 8) {
                Text("Legg til")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral500)
                    .textCase(.uppercase)
                ForEach(prefills) { prefill in
                    Button {
                        bandSheetPrefill = prefill
                        showAddBandSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.primary600)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prefill.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.neutral900)
                                Text(prefill.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.neutral500)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.neutral50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    bandSheetPrefill = nil
                    showAddBandSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text("Eget bånd")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.primary700)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func bandRow(band: WizardPricingBand, spotIndex: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 16))
                .foregroundStyle(.primary600)
                .frame(width: 36, height: 36)
                .background(Color.primary50)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(daysLabel(mask: band.dayMask))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("\(twoDigit(band.startHour)):00 – \(twoDigit(band.endHour)):00")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }
            Spacer()
            Button {
                removeBand(id: band.id, spotIndex: spotIndex)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.neutral400)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    // MARK: - Helpers

    private var prefills: [BandPrefill] {
        [
            BandPrefill(id: "weekday-work", label: "Hverdager 09–17", subtitle: "Mandag–Fredag", dayMask: 0b0011111, startHour: 9, endHour: 17),
            BandPrefill(id: "weekday-evening", label: "Hverdager kveld", subtitle: "Mandag–Fredag, 17–22", dayMask: 0b0011111, startHour: 17, endHour: 22),
            BandPrefill(id: "weekend-day", label: "Helg dag", subtitle: "Lør–Søn, 09–22", dayMask: 0b1100000, startHour: 9, endHour: 22),
        ]
    }

    private func setAlwaysAvailable(_ value: Bool, spotIndex: Int) {
        guard let id = form.spotMarkers[safe: spotIndex]?.id else { return }
        var avail = form.availability(for: id)
        avail.alwaysAvailable = value
        if value { avail.bands = [] }
        form.setAvailability(avail, for: id)
    }

    private func addBand(dayMask: Int, startHour: Int, endHour: Int) {
        guard let id = spotId else { return }
        var avail = form.availability(for: id)
        avail.bands.append(WizardPricingBand(
            dayMask: dayMask,
            startHour: startHour,
            endHour: endHour,
            price: 0,
            weekScope: .allWeeks
        ))
        avail.alwaysAvailable = false
        form.setAvailability(avail, for: id)
    }

    private func removeBand(id bandId: UUID, spotIndex: Int) {
        guard let id = form.spotMarkers[safe: spotIndex]?.id else { return }
        var avail = form.availability(for: id)
        avail.bands.removeAll { $0.id == bandId }
        form.setAvailability(avail, for: id)
    }

    private func daysLabel(mask: Int) -> String {
        let names = ["Man", "Tir", "Ons", "Tor", "Fre", "Lør", "Søn"]
        let selected = (0..<7).filter { (mask & (1 << $0)) != 0 }
        if selected == [0, 1, 2, 3, 4] { return "Hverdager" }
        if selected == [5, 6] { return "Helg" }
        if selected == [0, 1, 2, 3, 4, 5, 6] { return "Alle dager" }
        return selected.map { names[$0] }.joined(separator: ", ")
    }

    private func twoDigit(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
