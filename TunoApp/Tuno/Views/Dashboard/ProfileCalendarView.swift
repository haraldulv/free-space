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
    @State private var showOpeningOverridesSheet = false

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
        .sheet(isPresented: $showOpeningOverridesSheet) {
            if let spotId = canonicalSpotId,
               let idx = form.spotMarkers.firstIndex(where: { $0.id == spotId }) {
                OpeningHoursOverridesSheet(
                    overrides: Binding(
                        get: { form.spotMarkers[idx].openingHoursOverrides ?? [:] },
                        set: { newValue in
                            // Sync til alle spots hvis allSpotsMode
                            let target = newValue.isEmpty ? nil : newValue
                            if allSpotsMode {
                                for i in form.spotMarkers.indices {
                                    form.spotMarkers[i].openingHoursOverrides = target
                                }
                            } else {
                                form.spotMarkers[idx].openingHoursOverrides = target
                            }
                        }
                    ),
                    initialDates: [],
                    onClose: { showOpeningOverridesSheet = false }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
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

            // Åpningstid-overstyring per dato (kun for parkering med åpningstid)
            if listing.category == .parking {
                Button {
                    showOpeningOverridesSheet = true
                } label: {
                    Image(systemName: "clock.badge")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(Color.neutral200, lineWidth: 1))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Åpningstid på spesifikke datoer")
            }
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

/// Sheet for å sette per-dato overstyring av åpningstid på en parkering-plass.
/// To valg per dato: helt stengt, eller annen tid (f.eks. 12:00-22:00).
/// Eksisterende overstyringer listes nederst — kan slettes med søppel-ikon.
///
/// `initialDates` brukes når sheet'en åpnes fra kalenderens action-bar med en
/// allerede-valgt range. Da skjules DatePicker og overstyringen påføres alle
/// datoer i sett. Hvis `initialDates` er tom brukes single-dato-flyten med
/// egen DatePicker (Profil-snarvei "legg til fra scratch").
struct OpeningHoursOverridesSheet: View {
    @Binding var overrides: [String: DayOpeningOverride]
    var initialDates: Set<String> = []
    let onClose: () -> Void

    @State private var selectedDate: Date = Date()
    @State private var mode: Mode = .closed
    @State private var startTime: Date = OpeningHoursOverridesSheet.defaultStart()
    @State private var endTime: Date = OpeningHoursOverridesSheet.defaultEnd()

    enum Mode: String, CaseIterable, Identifiable {
        case closed = "Stengt"
        case allDay = "Hele dagen"
        case otherTime = "Andre tider"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Sett åpningstid for spesifikke datoer som overstyrer din vanlige uke-plan.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.neutral600)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(initialDates.isEmpty ? "Dato" : "Valgte datoer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.neutral500)
                            .textCase(.uppercase)
                        if initialDates.isEmpty {
                            DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "nb_NO"))
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.neutral700)
                                Text(initialRangeLabel)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.neutral900)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.neutral50)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.neutral200, lineWidth: 1)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hva skjer denne dagen?")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.neutral500)
                            .textCase(.uppercase)
                        VStack(spacing: 8) {
                            ForEach(Mode.allCases) { m in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { mode = m }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: mode == m ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(mode == m ? Color.primary600 : Color.neutral300)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(m.rawValue)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(Color.neutral900)
                                            Text(modeSubtitle(m))
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.neutral500)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(mode == m ? Color.primary50 : Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(mode == m ? Color.primary600 : Color.neutral200, lineWidth: mode == m ? 1.5 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if mode == .otherTime {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tider")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.neutral500)
                                .textCase(.uppercase)
                            HStack(spacing: 12) {
                                timeColumn(title: "Fra", date: $startTime)
                                timeColumn(title: "Til", date: $endTime)
                            }
                        }
                    }

                    Button {
                        applyOverride()
                    } label: {
                        Text("Lagre overstyring")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.neutral900)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    if !overrides.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Aktive overstyringer (\(overrides.count))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.neutral700)
                            ForEach(sortedOverrideKeys, id: \.self) { iso in
                                if let ov = overrides[iso] {
                                    overrideRow(iso: iso, override: ov)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(20)
            }
            .navigationTitle("Åpningstid på datoer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk", action: onClose)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }

    private func timeColumn(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.neutral500)
            DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "nb_NO"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func overrideRow(iso: String, override: DayOpeningOverride) -> some View {
        let statusText: String = {
            if override.isClosed { return "Stengt" }
            if override.open == "00:00-24:00" { return "Hele dagen" }
            return override.open ?? "—"
        }()
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDateLabel(iso: iso))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.neutral900)
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.neutral500)
            }
            Spacer()
            Button {
                overrides.removeValue(forKey: iso)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var sortedOverrideKeys: [String] { overrides.keys.sorted() }

    private func applyOverride() {
        let targets: [String] = initialDates.isEmpty
            ? [isoString(from: selectedDate)]
            : Array(initialDates)
        let value: DayOpeningOverride
        switch mode {
        case .closed:
            value = DayOpeningOverride(closed: true, open: nil)
        case .allDay:
            value = DayOpeningOverride(closed: false, open: "00:00-24:00")
        case .otherTime:
            let s = formatHM(startTime)
            let e = formatHM(endTime)
            value = DayOpeningOverride(closed: false, open: "\(s)-\(e)")
        }
        for iso in targets {
            overrides[iso] = value
        }
        if !initialDates.isEmpty {
            onClose()
        }
    }

    /// Pene label for valgt range. "12. mai" eller "12. – 18. mai (7 datoer)".
    private var initialRangeLabel: String {
        let sorted = initialDates.sorted()
        guard let first = sorted.first, let last = sorted.last else { return "" }
        if first == last {
            return formatDateLabel(iso: first)
        }
        return "\(formatDateLabel(iso: first)) – \(formatDateLabel(iso: last)) (\(initialDates.count) datoer)"
    }

    private func modeSubtitle(_ m: Mode) -> String {
        switch m {
        case .closed: return "Plassen er ikke tilgjengelig denne dagen"
        case .allDay: return "Plassen er åpen 24 timer (overstyrer ukedags-tid)"
        case .otherTime: return "Sett egne tider (overstyrer ukedags-tid)"
        }
    }

    private func isoString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        return f.string(from: date)
    }

    private func formatDateLabel(iso: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let d = parser.date(from: iso) else { return iso }
        let f = DateFormatter()
        f.dateFormat = "d. MMM yyyy"
        f.locale = Locale(identifier: "nb_NO")
        return f.string(from: d)
    }

    private func formatHM(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private static func defaultStart() -> Date {
        var c = DateComponents()
        c.hour = 9
        c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }

    private static func defaultEnd() -> Date {
        var c = DateComponents()
        c.hour = 17
        c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }
}
