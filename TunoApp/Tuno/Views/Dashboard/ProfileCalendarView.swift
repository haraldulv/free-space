import SwiftUI

/// Profile-kalender for både parking og camping. Bruker den nye
/// `SpotCalendarEditor` som erstatter den tidligere bånd-baserte kalenderen.
///
/// Modell: per-plass `blockedDates` + per-plass `datePriceOverrides`. Ingen
/// bånd, ingen ukedags-mønster, ingen åpningstid (åpningstid er listing-level
/// og redigeres i egen Rediger-tab).
///
/// Multi-spot-picker øverst lar verten redigere alle plasser samtidig
/// (default) eller velge én eller flere spesifikke. Endringer på den
/// "kanoniske" plassen propagerer til alle valgte før save.
struct ProfileCalendarView: View {
    let listing: Listing

    @State private var spotMarkers: [SpotMarker] = []
    /// Tom mengde = "Alle plasser". Ellers spesifikke spotId-er.
    @State private var selectedSpotIds: Set<String> = []
    @State private var isLoading = true
    @State private var saveTask: Task<Void, Never>?
    @State private var saveStatus: SaveStatus = .idle
    @State private var previousSpotMarkers: [SpotMarker] = []

    enum SaveStatus: Equatable {
        case idle, saving, saved, error(String)
    }

    @Environment(\.dismiss) private var dismiss

    /// Indeks for den "kanoniske" plassen som vises i editor'en. Endringer
    /// her propageres til alle andre valgte plasser før save.
    private var canonicalIndex: Int? {
        if let firstSelected = selectedSpotIds.sorted().first,
           let idx = spotMarkers.firstIndex(where: { $0.id == firstSelected }) {
            return idx
        }
        return spotMarkers.indices.first
    }

    /// SpotIds som mottar endringer ved save. Tom selection = alle spots.
    private var effectiveTargetIds: [String] {
        if selectedSpotIds.isEmpty {
            return spotMarkers.compactMap { $0.id }
        }
        return Array(selectedSpotIds)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await load() }
        .onChange(of: spotMarkers) { _, _ in scheduleSave() }
    }

    @ViewBuilder
    private var content: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Spacer().frame(height: 56)
                if let idx = canonicalIndex {
                    SpotCalendarEditor(
                        blockedDates: blockedDatesBinding(for: idx),
                        datePriceOverrides: overridesBinding(for: idx),
                        basePrice: spotMarkers[idx].pricePerNight ?? spotMarkers[idx].price ?? 0
                    )
                } else {
                    emptyState
                }
            }

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

                if spotMarkers.count > 1 {
                    spotPickerPill
                }

                Spacer()

                saveIndicator
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - Bindings

    private func blockedDatesBinding(for index: Int) -> Binding<[String]> {
        Binding(
            get: {
                guard spotMarkers.indices.contains(index) else { return [] }
                return spotMarkers[index].blockedDates ?? []
            },
            set: { newValue in
                guard spotMarkers.indices.contains(index) else { return }
                let value = newValue.isEmpty ? nil : newValue
                spotMarkers[index].blockedDates = value
                propagateToOtherTargets(canonicalIndex: index, blocked: value, overrides: nil)
            }
        )
    }

    private func overridesBinding(for index: Int) -> Binding<[String: Int]> {
        Binding(
            get: {
                guard spotMarkers.indices.contains(index) else { return [:] }
                return spotMarkers[index].datePriceOverrides ?? [:]
            },
            set: { newValue in
                guard spotMarkers.indices.contains(index) else { return }
                let value = newValue.isEmpty ? nil : newValue
                spotMarkers[index].datePriceOverrides = value
                propagateToOtherTargets(canonicalIndex: index, blocked: nil, overrides: value)
            }
        )
    }

    private func propagateToOtherTargets(
        canonicalIndex: Int,
        blocked: [String]??,
        overrides: [String: Int]??
    ) {
        let targets = effectiveTargetIds
        guard targets.count > 1 else { return }
        let canonicalId = spotMarkers[canonicalIndex].id
        for i in spotMarkers.indices where spotMarkers[i].id != canonicalId {
            if let id = spotMarkers[i].id, targets.contains(id) {
                if let blocked { spotMarkers[i].blockedDates = blocked }
                if let overrides { spotMarkers[i].datePriceOverrides = overrides }
            }
        }
    }

    // MARK: - Save indicator

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

    // MARK: - Spot-picker

    private var spotPickerSummary: String {
        if selectedSpotIds.isEmpty { return "Alle plasser" }
        let labels: [String] = spotMarkers.enumerated().compactMap { idx, spot in
            guard let id = spot.id, selectedSpotIds.contains(id) else { return nil }
            return spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false
                ? spot.label!
                : "Plass \(idx + 1)"
        }
        if labels.count <= 2 { return labels.joined(separator: ", ") }
        return "\(labels.count) av \(spotMarkers.count) plasser"
    }

    private var spotPickerPill: some View {
        Menu {
            Button {
                selectedSpotIds = []
            } label: {
                Label("Alle plasser", systemImage: selectedSpotIds.isEmpty ? "checkmark" : "rectangle.3.group.fill")
            }
            Divider()
            ForEach(Array(spotMarkers.enumerated()), id: \.offset) { idx, spot in
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

    @MainActor
    private func load() async {
        spotMarkers = listing.spotMarkers ?? []
        previousSpotMarkers = spotMarkers
        isLoading = false
    }

    // MARK: - Save (debounced)

    private func scheduleSave() {
        guard !isLoading else { return }
        let current = spotMarkers
        let previous = previousSpotMarkers
        let changed = current.enumerated().contains { idx, spot in
            guard idx < previous.count else { return true }
            let prev = previous[idx]
            return (spot.blockedDates ?? []) != (prev.blockedDates ?? [])
                || (spot.datePriceOverrides ?? [:]) != (prev.datePriceOverrides ?? [:])
        }
        guard changed else { return }

        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            await persist()
        }
    }

    @MainActor
    private func persist() async {
        saveStatus = .saving
        do {
            struct SpotMarkersUpdate: Encodable {
                let spot_markers: [SpotMarker]
            }
            try await supabase
                .from("listings")
                .update(SpotMarkersUpdate(spot_markers: spotMarkers))
                .eq("id", value: listing.id)
                .execute()
            previousSpotMarkers = spotMarkers
            saveStatus = .saved
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if case .saved = saveStatus { saveStatus = .idle }
            }
        } catch {
            saveStatus = .error("Kunne ikke lagre")
        }
    }
}
