import SwiftUI

/// Redigering for parkering-annonser (Asker-pivoten), i palett C-stil med
/// seksjoner, KrStepper-priser og bilderedigering. Målrettet UPDATE som alltid
/// skriver pris-invariantene sammen (price + pakker + display_price
/// + rental_period_types) — bruker ALDRI buildUpdateInput, som ville skrevet
/// price=0 for annonser uten per-plass-pris.
struct EditParkingView: View {
    let listing: Listing
    var onSaved: ((Listing) -> Void)? = nil
    var onDeleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var descriptionText: String
    @State private var dayPrice: Int?
    @State private var monthPrice: Int?
    @State private var dailyNote: String
    @State private var packageDays: Int
    @State private var packageNote: String
    @State private var isActive: Bool
    @State private var instantBooking: Bool
    @State private var isSaving = false
    @State private var error: String?
    @State private var showDeleteConfirm = false
    @State private var showSavedToast = false
    @State private var showDiscardConfirm = false
    @State private var dayFocused = false
    @State private var monthFocused = false
    @State private var daysFocused = false

    /// Bildene redigeres via PhotoGridEditor, som binder mot en
    /// ListingFormModel (imageURLs + uploadingPhotos + spotMarkers for
    /// tagging). Endringer persisteres først ved Lagre.
    @StateObject private var photoForm: ListingFormModel

    /// Dagers-stepperen (2-30) vises kun for legacy-annonser med Kim-pakke
    /// (DAY×N, N<30). Nye annonser har alltid ren månedspakke.
    private let showLegacyPackageDays: Bool

    private let initialSnapshot: Snapshot

    /// Alt som kan endres på skjermen — brukes til dirty-guard på Avbryt.
    private struct Snapshot: Equatable {
        var title: String
        var description: String
        var dayPrice: Int?
        var monthPrice: Int?
        var dailyNote: String
        var packageDays: Int
        var packageNote: String
        var isActive: Bool
        var instantBooking: Bool
        var images: [String]
        var spotImages: [[String]?]
    }

    init(listing: Listing, onSaved: ((Listing) -> Void)? = nil, onDeleted: (() -> Void)? = nil) {
        self.listing = listing
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _title = State(initialValue: listing.title)
        _descriptionText = State(initialValue: listing.description ?? "")
        let packages = (listing.spotMarkers ?? []).flatMap { $0.pricePackages ?? [] }
        let dayPkg = packages.first(where: { $0.periodType == .day && $0.periodValue == 1 })
        let day = dayPkg?.priceNok ?? listing.price ?? 0
        let monthPkg = packages.first(where: { $0.periodType == .month && $0.periodValue == 1 })
        // Kim-pakken (DAY×N, 2-30 dager) går foran legacy MONTH-pakken.
        let customPkg = packages.first(where: { $0.periodType == .day && $0.periodValue >= 2 && $0.periodValue <= 30 })
        let pkgPrice = customPkg?.priceNok ?? monthPkg?.priceNok
        _dayPrice = State(initialValue: day > 0 ? day : nil)
        _dailyNote = State(initialValue: dayPkg?.note ?? "")
        _monthPrice = State(initialValue: pkgPrice)
        _packageDays = State(initialValue: customPkg?.periodValue ?? 30)
        _packageNote = State(initialValue: customPkg?.note ?? monthPkg?.note ?? "")
        _isActive = State(initialValue: listing.isActive ?? true)
        _instantBooking = State(initialValue: listing.instantBooking ?? true)
        showLegacyPackageDays = (customPkg?.periodValue ?? 30) < 30

        let form = ListingFormModel()
        form.category = .parking
        form.imageURLs = listing.images ?? []
        form.spotMarkers = listing.spotMarkers ?? []
        _photoForm = StateObject(wrappedValue: form)

        initialSnapshot = Snapshot(
            title: listing.title,
            description: listing.description ?? "",
            dayPrice: day > 0 ? day : nil,
            monthPrice: pkgPrice,
            dailyNote: dayPkg?.note ?? "",
            packageDays: customPkg?.periodValue ?? 30,
            packageNote: customPkg?.note ?? monthPkg?.note ?? "",
            isActive: listing.isActive ?? true,
            instantBooking: listing.instantBooking ?? true,
            images: listing.images ?? [],
            spotImages: (listing.spotMarkers ?? []).map(\.images)
        )
    }

    private var currentSnapshot: Snapshot {
        Snapshot(
            title: title,
            description: descriptionText,
            dayPrice: dayPrice,
            monthPrice: monthPrice,
            dailyNote: dailyNote,
            packageDays: packageDays,
            packageNote: packageNote,
            isActive: isActive,
            instantBooking: instantBooking,
            images: photoForm.imageURLs,
            spotImages: photoForm.spotMarkers.map(\.images)
        )
    }

    private var hasChanges: Bool { currentSnapshot != initialSnapshot }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let error {
                        errorBanner(error)
                            .padding(.top, 12)
                    }

                    sectionHeader("Om plassen")
                    VStack(spacing: 14) {
                        fieldCard(label: "Tittel") {
                            TextField("Tittel", text: $title)
                                .font(.tuno(.body))
                                .foregroundStyle(.neutral900)
                        }
                        fieldCard(label: "Beskrivelse") {
                            TextField("Beskrivelse", text: $descriptionText, axis: .vertical)
                                .font(.tuno(.body))
                                .foregroundStyle(.neutral900)
                                .lineLimit(3...8)
                        }
                        fieldCard(label: "Bilder") {
                            PhotoGridEditor(form: photoForm)
                        }
                    }

                    sectionHeader("Pris")
                    VStack(spacing: 14) {
                        fieldCard(label: "Dagsleie", caption: "Leietaker betaler per dag. Vises som pris i søket.") {
                            KrStepper(
                                value: $dayPrice,
                                step: 5,
                                unitLabel: "kr per dag",
                                placeholder: "0",
                                onFocusChange: { dayFocused = $0 }
                            )
                        }
                        fieldCard(label: "Melding ved dagsleie (valgfritt)", caption: "Vises til leietaker før betaling av dagsleie.") {
                            TextField("F.eks. Parker helt inntil veggen.", text: $dailyNote, axis: .vertical)
                                .font(.tuno(.body))
                                .foregroundStyle(.neutral900)
                                .lineLimit(2...4)
                        }
                        fieldCard(
                            label: showLegacyPackageDays ? "Pakkepris (valgfritt)" : "Månedspris (valgfritt)",
                            caption: showLegacyPackageDays
                                ? "Leietaker får fast plass i \(packageDays) dager til denne prisen."
                                : "Leietaker får fast plass i 30 dager til denne prisen."
                        ) {
                            KrStepper(
                                value: $monthPrice,
                                step: 50,
                                unitLabel: showLegacyPackageDays ? "kr" : "kr per måned",
                                placeholder: "0",
                                onFocusChange: { monthFocused = $0 }
                            )
                        }
                        if (monthPrice ?? 0) > 0 {
                            if showLegacyPackageDays {
                                fieldCard(label: "Antall dager i pakken", caption: "30 dager blir vist som månedsplass.") {
                                    KrStepper(
                                        value: Binding(
                                            get: { packageDays },
                                            set: { packageDays = $0 ?? packageDays }
                                        ),
                                        step: 1,
                                        minValue: 2,
                                        maxValue: 30,
                                        unitLabel: "dager",
                                        placeholder: "30",
                                        onFocusChange: { daysFocused = $0 }
                                    )
                                }
                            }
                            fieldCard(label: "Melding ved månedsleie (valgfritt)", caption: "Vises til leietaker før betaling av månedsleie.") {
                                TextField("F.eks. Plassen kan brukes man-fre 08-18.", text: $packageNote, axis: .vertical)
                                    .font(.tuno(.body))
                                    .foregroundStyle(.neutral900)
                                    .lineLimit(2...4)
                            }
                        }
                    }

                    sectionHeader("Booking")
                    fieldCard {
                        Toggle(isOn: $instantBooking) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Direktebestilling")
                                    .font(.tuno(.body))
                                    .foregroundStyle(.neutral900)
                                Text("Leietaker booker og betaler med en gang. Slå av for å godkjenne hver bestilling selv.")
                                    .font(.tuno(.caption))
                                    .foregroundStyle(.neutral500)
                            }
                        }
                        .tint(.appAccent)
                    }

                    sectionHeader("Annonse")
                    VStack(spacing: 14) {
                        fieldCard {
                            Toggle(isOn: $isActive) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Annonsen er aktiv")
                                        .font(.tuno(.body))
                                        .foregroundStyle(.neutral900)
                                    Text("Slå av for å pause nye bestillinger.")
                                        .font(.tuno(.caption))
                                        .foregroundStyle(.neutral500)
                                }
                            }
                            .tint(.appAccent)
                        }

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Slett annonsen")
                                .font(.tuno(.body))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.appCard)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.red.opacity(0.4), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background(Color.paper)
            .navigationTitle("Rediger annonse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") {
                        if hasChanges {
                            showDiscardConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(.neutral700)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Lagre")
                                .font(.app(size: 16, weight: .semibold))
                                .foregroundStyle(saveEnabled ? Color.appAccent : .neutral400)
                        }
                    }
                    .disabled(!saveEnabled || isSaving)
                }
            }
            .confirmationDialog("Slette annonsen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Slett permanent", role: .destructive) {
                    Task { await deleteListing() }
                }
                Button("Avbryt", role: .cancel) { }
            } message: {
                Text("Dette kan ikke angres. Eksisterende bestillinger påvirkes ikke.")
            }
            .confirmationDialog("Forkaste endringene?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Forkast endringer", role: .destructive) { dismiss() }
                Button("Fortsett å redigere", role: .cancel) { }
            }
            .safeAreaInset(edge: .bottom) {
                if dayFocused || monthFocused || daysFocused {
                    keyboardBar
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text("Lagret")
                        .font(.tuno(.body))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.ink)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && (dayPrice ?? 0) > 0
    }

    /// Lagre sperres også mens bilder laster opp, så vi aldri persisterer et
    /// halvferdig bildesett.
    private var saveEnabled: Bool {
        canSave && photoForm.uploadingPhotos.isEmpty
    }

    // MARK: - Byggeklosser

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.app(size: 22, weight: .bold))
            .foregroundStyle(.neutral900)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 26)
            .padding(.bottom, 12)
            .padding(.horizontal, 4)
    }

    private func fieldCard<Content: View>(label: String? = nil, caption: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                Text(label)
                    .font(.tuno(.label))
                    .foregroundStyle(.neutral600)
            }
            content()
            if let caption {
                Text(caption)
                    .font(.tuno(.caption))
                    .foregroundStyle(.neutral500)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appLine, lineWidth: 1)
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.red)
            Text(message)
                .font(.tuno(.body))
                .foregroundStyle(.neutral900)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control))
    }

    private var keyboardBar: some View {
        HStack {
            Spacer()
            Button("Ferdig") {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .font(.tuno(.label))
            .foregroundStyle(.neutral900)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Save

    /// Kun feltene denne skjermen eier. Pris-invariantene skrives alltid
    /// sammen i samme payload.
    private struct ParkingUpdatePayload: Encodable {
        let title: String
        let description: String
        let price: Int
        let isActive: Bool
        let instantBooking: Bool
        let images: [String]
        let spotMarkers: [SpotMarker]
        let rentalPeriodTypes: [String]
        let displayPrice: Int
        let displayPriceSuffix: String

        enum CodingKeys: String, CodingKey {
            case title, description, price, images
            case isActive = "is_active"
            case instantBooking = "instant_booking"
            case spotMarkers = "spot_markers"
            case rentalPeriodTypes = "rental_period_types"
            case displayPrice = "display_price"
            case displayPriceSuffix = "display_price_suffix"
        }
    }

    private func save() async {
        guard let day = dayPrice, day > 0 else { return }
        let month = (monthPrice ?? 0) > 0 ? monthPrice : nil
        isSaving = true
        error = nil

        let trimmedDayNote = dailyNote.trimmingCharacters(in: .whitespacesAndNewlines)
        var packages: [PricePackage] = [PricePackage(
            periodType: .day,
            periodValue: 1,
            priceNok: day,
            note: trimmedDayNote.isEmpty ? nil : trimmedDayNote
        )]
        let trimmedNote = packageNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let pkgDays = min(30, max(2, packageDays))
        if let month {
            if pkgDays == 30 {
                // Ren månedsplass («kr/mnd»-visning) — meldingen følger pakken.
                packages.append(PricePackage(
                    periodType: .month,
                    periodValue: 1,
                    priceNok: month,
                    note: trimmedNote.isEmpty ? nil : trimmedNote
                ))
            } else {
                packages.append(PricePackage(
                    periodType: .day,
                    periodValue: pkgDays,
                    priceNok: month,
                    note: trimmedNote.isEmpty ? nil : trimmedNote
                ))
            }
        }

        // Markørene tas fra photoForm slik at bilde-tagging overlever.
        // Pris-modellen skrives på nytt: price=nil + ferske pakker. Spot-tags
        // som peker på fjernede bilder prunes (grid-en rydder selv, dette er
        // et sikkerhetsnett).
        var markers = photoForm.spotMarkers
        for i in markers.indices {
            markers[i].price = nil
            markers[i].pricePerNight = nil
            markers[i].pricePackages = packages
            if let imgs = markers[i].images {
                let kept = imgs.filter { photoForm.imageURLs.contains($0) }
                markers[i].images = kept.isEmpty ? nil : kept
            }
        }

        var periods = ["DAY"]
        if month != nil && pkgDays == 30 { periods.append("MONTH") }

        let payload = ParkingUpdatePayload(
            title: title.trimmingCharacters(in: .whitespaces),
            description: descriptionText.trimmingCharacters(in: .whitespaces),
            price: day,
            isActive: isActive,
            instantBooking: instantBooking,
            images: photoForm.imageURLs,
            spotMarkers: markers,
            rentalPeriodTypes: periods.sorted(),
            displayPrice: day,
            displayPriceSuffix: ""
        )

        do {
            let updated: [Listing] = try await supabase
                .from("listings")
                .update(payload)
                .eq("id", value: listing.id)
                .select()
                .execute()
                .value

            isSaving = false
            if let fresh = updated.first {
                onSaved?(fresh)
            }
            withAnimation { showSavedToast = true }
            try? await Task.sleep(nanoseconds: 800_000_000)
            dismiss()
        } catch {
            self.error = "Kunne ikke lagre: \(error.localizedDescription)"
            isSaving = false
        }
    }

    private func deleteListing() async {
        isSaving = true
        do {
            try await supabase
                .from("listings")
                .delete()
                .eq("id", value: listing.id)
                .execute()
            isSaving = false
            onDeleted?()
            dismiss()
        } catch {
            self.error = "Kunne ikke slette: \(error.localizedDescription)"
            isSaving = false
        }
    }
}
