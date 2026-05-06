import SwiftUI

/// Post-publisering kalender (Profil → Kalender). Bruker den samme
/// `WizardPricingCalendarView` / `WizardSeasonalCalendarView` som wizarden,
/// hooked til den nye datamodellen (per-plass blockedDates +
/// datePriceOverrides — ingen bånd).
///
/// Multi-spot-picker pill-rad øverst lar host velge "Alle plasser" eller én
/// spesifikk plass. Endringer auto-lagres til spot_markers jsonb.
struct ProfileCalendarView: View {
    let listing: Listing

    @StateObject private var form = ListingFormModel()
    @State private var focusedSpotId: String? = nil
    @State private var allSpotsMode: Bool = true
    @State private var isLoading = true
    @State private var saveTask: Task<Void, Never>?
    @State private var saveStatus: SaveStatus = .idle
    @State private var previousSpotMarkers: [SpotMarker] = []

    enum SaveStatus: Equatable {
        case idle, saving, saved, error(String)
    }

    @Environment(\.dismiss) private var dismiss

    private var spotIds: [String] {
        form.spotMarkers.compactMap { $0.id }
    }

    private var canonicalSpotId: String? {
        focusedSpotId ?? spotIds.first
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
        .onChange(of: form.spotMarkers) { _, _ in scheduleSave() }
    }

    @ViewBuilder
    private var content: some View {
        ZStack(alignment: .top) {
            calendarBody

            VStack(spacing: 8) {
                topBar
                if form.spotMarkers.count > 1 {
                    spotPickerBar
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var calendarBody: some View {
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

    private var topBar: some View {
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

            Spacer()

            saveIndicator
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

    private var spotPickerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hvilke plasser?")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    pickerPill(
                        label: "Alle plasser",
                        icon: "rectangle.3.group.fill",
                        isSelected: allSpotsMode
                    ) {
                        allSpotsMode = true
                        focusedSpotId = spotIds.first
                    }

                    ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { idx, spot in
                        if let id = spot.id {
                            let label = spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false
                                ? spot.label!
                                : "\(idx + 1)"
                            pickerPill(
                                label: label,
                                icon: nil,
                                isSelected: !allSpotsMode && focusedSpotId == id
                            ) {
                                allSpotsMode = false
                                focusedSpotId = id
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pickerPill(label: String, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : Color.neutral900)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary600 : Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundStyle(.neutral300)
            Text("Annonsen mangler plass-data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        form.spotMarkers = listing.spotMarkers ?? []
        form.category = listing.category
        form.title = listing.title
        form.priceUnit = listing.priceUnit ?? .natt
        focusedSpotId = form.spotMarkers.first?.id
        previousSpotMarkers = form.spotMarkers
        isLoading = false
    }

    // MARK: - Save (debounced)

    private func scheduleSave() {
        guard !isLoading else { return }
        let current = form.spotMarkers
        let previous = previousSpotMarkers
        let changed = current.enumerated().contains { idx, spot in
            guard idx < previous.count else { return true }
            let prev = previous[idx]
            return (spot.blockedDates ?? []) != (prev.blockedDates ?? [])
                || (spot.datePriceOverrides ?? [:]) != (prev.datePriceOverrides ?? [:])
        }
        guard changed else { return }

        // I "Alle plasser"-modus: kopier endringer til alle andre spots før save.
        if allSpotsMode, let canonical = canonicalSpotId,
           let canonicalIdx = form.spotMarkers.firstIndex(where: { $0.id == canonical }) {
            let blocked = form.spotMarkers[canonicalIdx].blockedDates
            let overrides = form.spotMarkers[canonicalIdx].datePriceOverrides
            for i in form.spotMarkers.indices where form.spotMarkers[i].id != canonical {
                form.spotMarkers[i].blockedDates = blocked
                form.spotMarkers[i].datePriceOverrides = overrides
            }
        }

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
            saveStatus = .error("Kunne ikke lagre")
        }
    }
}
