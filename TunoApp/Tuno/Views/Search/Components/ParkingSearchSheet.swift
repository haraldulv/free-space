import SwiftUI

/// To-stegs søkeark for parkering (Kim-feedback 2026-10-12): steg 1 «Hvor?»
/// med stedfelt og Asker-forslag, steg 2 «Når?» med valgfrie fra/til-datoer
/// og Søk-knappen. Valg av sted sentrerer kartet bak arket uten å søke;
/// søket kjører først på Søk. Kjøretøytype bor i Filtre-arket.
struct ParkingSearchSheet: View {
    @Binding var query: String
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    /// Multi-velg (samme som booking-flyten): «Velg enkeltdager» toggler
    /// enkeltdager i kalenderen; checkIn/checkOut holder konvolutten.
    @Binding var multiDayMode: Bool
    @Binding var selectedDates: Set<String>
    /// Styres av arket: steg 2 (kalenderen) trenger full høyde, så vi løfter
    /// detenten til .large når brukeren går videre fra stedvalget.
    @Binding var detent: PresentationDetent
    @ObservedObject var placesService: PlacesService
    let onSelectPlace: (PlacePrediction) -> Void
    /// Områdeforslag med kjent koordinat (Asker-stasjonene): navn, lat, lng.
    /// Løses lokalt, ingen Places-rundtur.
    let onPickArea: (String, Double, Double) -> Void
    let onUseMyLocation: () -> Void
    let onSearch: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typing: String = ""
    @FocusState private var searchFocused: Bool

    private enum Step: Equatable {
        case place
        case dates
    }

    @State private var step: Step = .place

    private struct AreaSuggestion: Identifiable {
        let name: String
        let subtitle: String
        let icon: String
        let lat: Double
        let lng: Double
        var id: String { name }
    }

    /// Asker-lanseringen: stasjonsnære områder der vi starter.
    private static let areaSuggestions: [AreaSuggestion] = [
        .init(name: "Asker", subtitle: "Sentrum og stasjonen", icon: "tram.fill", lat: 59.8333, lng: 10.4356),
        .init(name: "Heggedal", subtitle: "Stasjon på Spikkestadbanen", icon: "house.fill", lat: 59.7905, lng: 10.4387),
        .init(name: "Billingstad", subtitle: "Billingstad og Slependen", icon: "car.fill", lat: 59.8655, lng: 10.4919),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch step {
                case .place:
                    placeStep
                        .transition(.move(edge: .leading).combined(with: .opacity))
                case .dates:
                    dateStep
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color.paper)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: step)
        .onAppear {
            typing = query
            // Hver presentasjon starter på steg 1 (fersk @State) — start i
            // medium så kartet fortsatt synes bak.
            detent = .medium
        }
        .onChange(of: typing) { _, newValue in
            // pick()/forslagsrader setter typing programmatisk idet vi går til
            // steg 2 — ikke start en ny autocomplete da.
            guard step == .place else { return }
            if newValue.isEmpty {
                placesService.clear()
            } else {
                placesService.autocomplete(query: newValue)
            }
        }
    }

    // MARK: - Steg 1: Hvor?

    private var placeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Hvor vil du parkere?")
                .font(.tuno(.title))
                .foregroundStyle(.neutral900)
                .padding(.top, 18)

            searchField

            if placesService.predictions.isEmpty {
                suggestionList
            } else {
                predictionList
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.neutral500)
            TextField("Søk sted eller adresse", text: $typing)
                .font(.tuno(.body))
                .autocorrectionDisabled()
                .focused($searchFocused)
                .onSubmit {
                    if let first = placesService.predictions.first {
                        pick(first)
                    }
                }
            if !typing.isEmpty {
                Button {
                    typing = ""
                    placesService.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral300)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.paperCard)
        .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous)
                .stroke(Color.paperLine, lineWidth: 1)
        )
    }

    // MARK: - Forslag

    private var suggestionList: some View {
        VStack(spacing: 0) {
            Button {
                query = "Min posisjon"
                typing = "Min posisjon"
                onUseMyLocation()
                advanceToDates()
            } label: {
                suggestionRowLabel(icon: "location.fill", title: "I nærheten", subtitle: "Bruk min posisjon")
            }
            .buttonStyle(.plain)

            ForEach(Self.areaSuggestions) { area in
                Divider().padding(.leading, 54)
                Button {
                    query = area.name
                    typing = area.name
                    onPickArea(area.name, area.lat, area.lng)
                    advanceToDates()
                } label: {
                    suggestionRowLabel(icon: area.icon, title: area.name, subtitle: area.subtitle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var predictionList: some View {
        VStack(spacing: 0) {
            ForEach(placesService.predictions) { prediction in
                Button {
                    pick(prediction)
                } label: {
                    suggestionRowLabel(
                        icon: "mappin.circle.fill",
                        title: prediction.mainText,
                        subtitle: prediction.secondaryText
                    )
                }
                .buttonStyle(.plain)
                if prediction.id != placesService.predictions.last?.id {
                    Divider().padding(.leading, 54)
                }
            }
        }
    }

    private func pick(_ prediction: PlacePrediction) {
        query = prediction.mainText
        typing = prediction.mainText
        placesService.clear()
        onSelectPlace(prediction)
        advanceToDates()
    }

    private func advanceToDates() {
        searchFocused = false
        step = .dates
        // Kalenderen trenger full høyde.
        detent = .large
    }

    private func suggestionRowLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.mintInk)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.tuno(.body))
                    .foregroundStyle(.neutral900)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.tuno(.caption))
                        .foregroundStyle(.neutral500)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Steg 2: Når?

    private var dateStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Button {
                    step = .place
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral600)
                        .frame(width: 32, height: 32)
                        .background(Color.paperCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tilbake til stedvalg")

                Text("Når vil du parkere?")
                    .font(.tuno(.title))
                    .foregroundStyle(.neutral900)
            }
            .padding(.top, 18)

            Button {
                step = .place
            } label: {
                suggestionRowLabel(
                    icon: "mappin.circle.fill",
                    title: query.isEmpty ? "Velg sted" : query,
                    subtitle: "Endre sted"
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                multiDayToggle

                Text("Valgfritt. Du kan søke uten datoer.")
                    .font(.tuno(.caption))
                    .foregroundStyle(.neutral500)

                if multiDayMode {
                    SearchDateRangePicker(
                        checkIn: $checkIn,
                        checkOut: $checkOut,
                        selectionMode: .multi,
                        selectedDates: $selectedDates,
                        paged: true
                    )
                    .padding(12)
                    .background(Color.paperCard)
                    .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous)
                            .stroke(Color.paperLine, lineWidth: 1)
                    )

                    if selectedDates.isEmpty {
                        Text("Trykk på dagene du vil parkere. Du kan velge dager i flere uker.")
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(selectedDates.count) \(selectedDates.count == 1 ? "dag" : "dager") valgt · \(multiDaySummary)")
                                .font(.system(size: 13))
                                .foregroundStyle(.neutral500)
                            Spacer()
                            Button("Nullstill") {
                                selectedDates = []
                                checkIn = nil
                                checkOut = nil
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.neutral600)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        quickDateChip("I dag", offset: 0)
                        quickDateChip("I morgen", offset: 1)
                        Spacer()
                        if checkIn != nil || checkOut != nil {
                            Button("Nullstill") {
                                checkIn = nil
                                checkOut = nil
                            }
                            .font(.tuno(.caption))
                            .foregroundStyle(.neutral600)
                        }
                    }

                    SearchDateRangePicker(
                        checkIn: $checkIn,
                        checkOut: $checkOut,
                        paged: true
                    )
                    .padding(12)
                    .background(Color.paperCard)
                    .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous)
                            .stroke(Color.paperLine, lineWidth: 1)
                    )

                    if let summary = selectionSummary {
                        Text(summary)
                            .font(.tuno(.body))
                            .foregroundStyle(.neutral700)
                    }
                }
            }
        }
    }

    /// Sammenhengende / Velg enkeltdager — samme chips som booking-flyten.
    /// Bytte nullstiller datovalget så konvolutt og dagsett aldri spriker.
    private var multiDayToggle: some View {
        HStack(spacing: 8) {
            multiDayChip("Sammenhengende", selected: !multiDayMode) { setMultiDayMode(false) }
            multiDayChip("Velg enkeltdager", selected: multiDayMode) { setMultiDayMode(true) }
            Spacer()
        }
    }

    private func multiDayChip(_ title: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Color.neutral700)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.appAccent : Color.appCard)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func setMultiDayMode(_ on: Bool) {
        guard multiDayMode != on else { return }
        multiDayMode = on
        selectedDates = []
        checkIn = nil
        checkOut = nil
    }

    /// Kort oppsummering av multi-valgte dager som perioder: «3.–5. mar, 10.–12. mar».
    private var multiDaySummary: String {
        let runs = TunoCalendar.runs(Array(selectedDates))
        let df = DateFormatter()
        df.dateFormat = "d. MMM"
        df.locale = Locale(identifier: "nb_NO")
        func short(_ key: String) -> String {
            guard let date = TunoCalendar.date(from: key) else { return key }
            return df.string(from: date)
        }
        let parts = runs.prefix(3).map { run -> String in
            if run.start == run.end { return short(run.start) }
            return "\(short(run.start))–\(short(run.end))"
        }
        let suffix = runs.count > 3 ? " …" : ""
        return parts.joined(separator: ", ") + suffix
    }

    /// «I dag»/«I morgen»: ett tap setter en éndagsperiode. Tapp på valgt
    /// chip nullstiller.
    private func quickDateChip(_ label: String, offset: Int) -> some View {
        let day = Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(offset) * 86400)
        let isSelected = checkIn == day && (checkOut == day || checkOut == nil)
        return Button {
            if isSelected {
                checkIn = nil
                checkOut = nil
            } else {
                checkIn = day
                checkOut = day
            }
        } label: {
            Text(label)
                .font(.tuno(.label))
                .foregroundStyle(isSelected ? .white : .neutral900)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.ink : Color.paperCard)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.ink : Color.paperLine, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var selectionSummary: String? {
        guard let start = checkIn else { return nil }
        let end = checkOut ?? start
        let days = (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        let df = DateFormatter()
        df.dateFormat = "d. MMM"
        df.locale = Locale(identifier: "nb_NO")
        if days == 1 {
            return "\(df.string(from: start)) · 1 dag"
        }
        return "\(df.string(from: start)) – \(df.string(from: end)) · \(days) dager"
    }

    // MARK: - Bunnbar

    private var searchButtonTitle: String {
        if multiDayMode {
            return selectedDates.isEmpty ? "Søk uten datoer" : "Søk"
        }
        return checkIn == nil && checkOut == nil ? "Søk uten datoer" : "Søk"
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch step {
        case .place:
            if !query.isEmpty {
                Button("Neste") {
                    advanceToDates()
                }
                .buttonStyle(TunoPillButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color.paper)
            }
        case .dates:
            Button(searchButtonTitle) {
                // Ett tap i kalenderen = éndagssøk: fyll ut Til-datoen.
                // (Multi-velg vedlikeholder konvolutten selv i pickeren.)
                if !multiDayMode, let ci = checkIn, checkOut == nil {
                    checkOut = ci
                }
                dismiss()
                onSearch()
            }
            .buttonStyle(TunoPillButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.paper)
        }
    }
}
