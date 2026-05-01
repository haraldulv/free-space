import SwiftUI

/// Profile-kalender for parking-listings. Gjenbruker wizardens
/// `WizardPricingCalendarView` slik at verten ser nøyaktig samme bånd-editor
/// som under "Ny annonse". Multi-spot-picker øverst lar verten redigere alle
/// plasser samtidig (default) eller velge én spesifikk plass.
///
/// Persistering: endringer i `form.availabilityBySpotId` autosaves med 0.8 s
/// debounce til `listing_pricing_rules` + `listing_pricing_overrides`.
/// Blokkerte datoer på en plass autosaves til `listings.spot_markers` (jsonb).
///
/// For camping-listings (per natt) er bånd-editoren foreløpig ikke tilpasset
/// sesongpriser — vi faller tilbake til den gamle `HostCalendarView`. Sesong-
/// bånd dekkes i en senere bolk (se `project_todo_kalender_overhaul.md`).
struct ProfileCalendarView: View {
    let listing: Listing

    @StateObject private var form = ListingFormModel()
    /// Tom mengde = "Alle plasser". Ellers spesifikke spotId-er.
    @State private var selectedSpotIds: Set<String> = []
    @State private var isLoading = true
    @State private var saveTask: Task<Void, Never>?
    @State private var saveStatus: SaveStatus = .idle
    /// Holder snapshot av forrige availability slik at vi kan oppdage hvilken
    /// spot som faktisk endret seg uten å skrive alle på en gang.
    @State private var previousAvailability: [String: WizardSpotAvailability] = [:]
    @State private var previousSpotMarkers: [SpotMarker] = []

    enum SaveStatus: Equatable {
        case idle, saving, saved, error(String)
    }

    private var spots: [SpotMarker] { form.spotMarkers }

    /// "Canonical" spot vi viser i kalenderen. Når flere er valgt eller alle:
    /// bruker første spot's data som mal — endringer kopieres til alle valgte.
    private var canonicalSpotId: String? {
        if let first = selectedSpotIds.sorted().first { return first }
        return spots.first?.id
    }

    /// SpotIds som mottar endringer ved save. Tom selection = alle spots.
    private var effectiveTargetIds: [String] {
        if selectedSpotIds.isEmpty {
            return spots.compactMap { $0.id }
        }
        return Array(selectedSpotIds)
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        // Fullscreen-stil: skjul navigation-bar slik at kalenderen får
        // hele skjermen og weekday-headeren låses helt øverst (matcher
        // wizardens pris-variasjon-steg).
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await load() }
        .onChange(of: form.availabilityBySpotId) { _, _ in scheduleSave() }
        .onChange(of: form.spotMarkers) { _, _ in scheduleBlockedSave() }
    }

    @ViewBuilder
    private var content: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Spacer().frame(height: 56)  // plass til topbar
                if let id = canonicalSpotId {
                    if listing.category == .camping {
                        WizardSeasonalCalendarView(form: form, spotId: id)
                    } else {
                        WizardPricingCalendarView(form: form, spotId: id)
                    }
                } else {
                    emptyState
                }
            }

            // Top-overlay: "X" + spot-pill + save-status — alle i én rad,
            // kompakt for å ikke ta plass fra kalenderen.
            HStack(alignment: .center, spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(Color.neutral200, lineWidth: 1))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lukk")

                if spots.count > 1 {
                    spotPickerPill
                }

                Spacer()

                saveIndicator
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var saveIndicator: some View {
        switch saveStatus {
        case .idle:
            EmptyView()
        case .saving:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7)
                Text("Lagrer...").font(.system(size: 11)).foregroundStyle(.neutral500)
            }
        case .saved:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Text("Lagret").font(.system(size: 11)).foregroundStyle(.neutral500)
            }
        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                Text(msg).font(.system(size: 11)).foregroundStyle(.red).lineLimit(1)
            }
        }
    }

    // MARK: - Spot-picker (kompakt pill med dropdown-meny)

    /// Sammendrag av valgte plasser: "Alle plasser" eller "Plass 1, Plass 3"
    /// eller "2 av 4 plasser" for mange. Vises i pill-en.
    private var spotPickerSummary: String {
        if selectedSpotIds.isEmpty { return "Alle plasser" }
        let labels: [String] = spots.enumerated().compactMap { idx, spot in
            guard let id = spot.id, selectedSpotIds.contains(id) else { return nil }
            return spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false
                ? spot.label!
                : "Plass \(idx + 1)"
        }
        if labels.count <= 2 { return labels.joined(separator: ", ") }
        return "\(labels.count) av \(spots.count) plasser"
    }

    private var spotPickerPill: some View {
        Menu {
            Button {
                selectedSpotIds = []
            } label: {
                Label("Alle plasser", systemImage: selectedSpotIds.isEmpty ? "checkmark" : "rectangle.3.group.fill")
            }
            Divider()
            ForEach(Array(spots.enumerated()), id: \.offset) { idx, spot in
                if let id = spot.id {
                    let label = spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false
                        ? spot.label!
                        : "Plass \(idx + 1)"
                    Button {
                        if selectedSpotIds.contains(id) {
                            selectedSpotIds.remove(id)
                        } else {
                            selectedSpotIds.insert(id)
                        }
                    } label: {
                        if selectedSpotIds.contains(id) {
                            Label(label, systemImage: "checkmark")
                        } else {
                            Text(label)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .semibold))
                Text(spotPickerSummary)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.neutral900)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().stroke(Color.neutral200, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundStyle(.neutral300)
            Text("Annonsen mangler plass-data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral600)
            Text("Gå til Rediger annonse → Plasser for å sette opp plasser før du administrerer kalenderen.")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load

    private func load() async {
        // Fyll form med listing-data slik wizardens kalender forventer.
        let markers = listing.spotMarkers ?? []
        form.spotMarkers = markers
        form.category = listing.category
        form.title = listing.title
        form.priceUnit = listing.priceUnit ?? .hour

        // Last bånd + overrides for hver plass (parallelt for fart).
        await withTaskGroup(of: (String, WizardSpotAvailability).self) { group in
            for marker in markers {
                guard let id = marker.id else { continue }
                group.addTask {
                    let avail = await PricingService.loadAvailability(listingId: listing.id, spotId: id)
                    return (id, avail)
                }
            }
            for await (id, avail) in group {
                form.setAvailability(avail, for: id)
            }
        }

        previousAvailability = form.availabilityBySpotId
        previousSpotMarkers = form.spotMarkers
        isLoading = false
    }

    // MARK: - Save (debounced)

    private func scheduleSave() {
        // Hopp første endring fra load (state init trigger onChange).
        guard !isLoading else { return }
        saveTask?.cancel()
        let snapshot = form.availabilityBySpotId
        let prev = previousAvailability
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            await persistAvailabilityChanges(current: snapshot, previous: prev)
        }
    }

    @MainActor
    private func persistAvailabilityChanges(
        current: [String: WizardSpotAvailability],
        previous: [String: WizardSpotAvailability]
    ) async {
        // Finn hvilken spot som faktisk endret seg. I "Alle plasser"-modus
        // gjelder endringer typisk kun canonical spot — derfra propagerer vi
        // til alle valgte.
        let changedIds = current.keys.filter { id in
            current[id] != previous[id]
        }
        guard !changedIds.isEmpty else { return }

        saveStatus = .saving

        // I "Alle plasser"-modus: hvis canonical-spot endret, kopier til alle
        // andre spots i form (sync), så alle spots blir like før save.
        if selectedSpotIds.isEmpty,
           let canonical = canonicalSpotId,
           changedIds.contains(canonical) {
            let template = current[canonical] ?? WizardSpotAvailability()
            for spot in spots where spot.id != canonical {
                if let otherId = spot.id {
                    form.availabilityBySpotId[otherId] = template
                }
            }
        }

        let targets = effectiveTargetIds
        let templateAvail = current[canonicalSpotId ?? ""] ?? WizardSpotAvailability()

        do {
            for spotId in targets {
                let availToSave: WizardSpotAvailability
                if selectedSpotIds.isEmpty || targets.count > 1 {
                    // "Alle plasser" eller multi-velg: alle får samme bånd-sett.
                    availToSave = templateAvail
                } else {
                    availToSave = current[spotId] ?? WizardSpotAvailability()
                }
                let basePerHour = spots.first(where: { $0.id == spotId })?.pricePerHour ?? 0
                try await PricingService.saveAvailability(
                    listingId: listing.id,
                    spotId: spotId,
                    availToSave,
                    basePerHour: basePerHour
                )
            }
            previousAvailability = form.availabilityBySpotId
            saveStatus = .saved
            // Skjul "Lagret" etter et par sekunder.
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if case .saved = saveStatus { saveStatus = .idle }
            }
        } catch {
            saveStatus = .error("Lagring feilet")
        }
    }

    // MARK: - Blocked dates persist (autosave til listings.spot_markers)

    private func scheduleBlockedSave() {
        guard !isLoading else { return }
        let current = form.spotMarkers
        let previous = previousSpotMarkers
        let blockedChanged = current.enumerated().contains { idx, spot in
            guard idx < previous.count else { return true }
            return spot.blockedDates ?? [] != previous[idx].blockedDates ?? []
        }
        guard blockedChanged else { return }

        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            await persistBlockedDates()
        }
    }

    @MainActor
    private func persistBlockedDates() async {
        saveStatus = .saving
        // I "Alle plasser"-modus: kopier canonical's blockedDates til alle valgte.
        if selectedSpotIds.isEmpty, let canonical = canonicalSpotId,
           let canonicalIdx = spots.firstIndex(where: { $0.id == canonical }) {
            let template = form.spotMarkers[canonicalIdx].blockedDates
            for i in form.spotMarkers.indices where form.spotMarkers[i].id != canonical {
                form.spotMarkers[i].blockedDates = template
            }
        }

        // Skriv hele spot_markers-arrayet tilbake (jsonb-array).
        do {
            struct SpotMarkersUpdate: Encodable {
                let spot_markers: [SpotMarker]
            }
            try await supabase
                .from("listings")
                .update(SpotMarkersUpdate(spot_markers: form.spotMarkers))
                .eq("id", value: listing.id)
                .execute()
            previousSpotMarkers = form.spotMarkers
            saveStatus = .saved
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if case .saved = saveStatus { saveStatus = .idle }
            }
        } catch {
            saveStatus = .error("Kunne ikke lagre datoer")
        }
    }
}
