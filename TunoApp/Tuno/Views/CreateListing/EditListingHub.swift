import SwiftUI

/// Hub-og-spoke-redigering for en eksisterende annonse. Speiler "Ny annonse"-
/// wizarden ved å gjenbruke step-views direkte fra `Steps/`, men i stedet
/// for lineær Tilbake/Neste-flyt pusher den hvert steg via NavigationStack.
///
/// TU-61: erstatter den gamle tab-baserte EditListingView.
struct EditListingHub: View {
    let listing: Listing
    var onSaved: ((Listing) -> Void)? = nil

    @StateObject private var form = ListingFormModel()
    @StateObject private var placesService = PlacesService()
    @Environment(\.dismiss) private var dismiss

    @State private var path: [EditDestination] = []
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSavedToast = false
    @State private var showDiscardConfirm = false
    @State private var showPreview = false

    var body: some View {
        NavigationStack(path: $path) {
            rootScreen
        }
        .onAppear {
            form.editingMode = true
            form.existingListingId = listing.id
            form.loadFromListing(listing)
        }
    }

    private var rootScreen: some View {
        scrollBody
            .background(Color.neutral50)
            .navigationTitle("Rediger annonse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar { hubToolbar }
            .navigationDestination(for: EditDestination.self) { dest in
                destinationView(for: dest)
            }
            .overlay(alignment: .bottom) { previewPill }
            .overlay(alignment: .top) { savedToast }
            .confirmationDialog(
                "Forkast endringer?",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Forkast", role: .destructive) { dismiss() }
                Button("Fortsett å redigere", role: .cancel) { }
            } message: {
                Text("Endringene du har gjort er ikke lagret.")
            }
            .alert("Kunne ikke lagre", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Ukjent feil")
            }
            .fullScreenCover(isPresented: $showPreview) {
                NavigationStack {
                    ListingDetailView(listingId: listing.id)
                }
            }
    }

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                sectionList
                if listing.category == .parking {
                    listingLevelSection
                }
                spotsSection
                Spacer().frame(height: 60)
            }
            .padding(16)
        }
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var hubToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                if form.isDirty {
                    showDiscardConfirm = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral700)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Lukk")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await saveChanges() }
            } label: {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.primary600.opacity(0.6))
                        .clipShape(Capsule())
                } else {
                    Text("Lagre")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(form.isDirty ? .white : Color.neutral500)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(form.isDirty ? Color.primary600 : Color.neutral200)
                        .clipShape(Capsule())
                }
            }
            .disabled(!form.isDirty || isSaving)
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: URL(string: form.imageURLs.first ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.neutral100)
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)

            VStack(alignment: .leading, spacing: 4) {
                Text(form.title.isEmpty ? "Uten tittel" : form.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(form.city)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Section list

    /// Felles seksjoner som gjelder hele annonsen (ikke per plass).
    private var sectionList: some View {
        rowGroup {
            row(
                dest: .address,
                icon: "mappin.and.ellipse",
                title: "Adresse",
                subtitle: form.address.isEmpty ? "Ikke satt" : form.address
            )
            divider
            row(
                dest: .description,
                icon: "text.alignleft",
                title: "Beskrivelse",
                subtitle: descriptionSummary
            )
            divider
            row(
                dest: .photos,
                icon: "photo.on.rectangle.angled",
                title: "Bilder",
                subtitle: form.imageURLs.isEmpty ? "Ingen bilder" : "\(form.imageURLs.count) bilde\(form.imageURLs.count == 1 ? "" : "r")"
            )
            divider
            row(
                dest: .amenities,
                icon: "wand.and.stars",
                title: "Fasiliteter",
                subtitle: form.selectedAmenities.isEmpty ? "Ingen valgt" : "\(form.selectedAmenities.count) valgt"
            )
            divider
            row(
                dest: .messages,
                icon: "bubble.left.fill",
                title: "Meldinger",
                subtitle: messagesSummary
            )
        }
    }

    /// Listing-nivå innstillinger som kun gjelder parkering (åpningstid).
    private var listingLevelSection: some View {
        rowGroup {
            row(
                dest: .instantBooking,
                icon: form.instantBooking ? "bolt.fill" : "hand.raised.fill",
                title: "Booking",
                subtitle: form.instantBooking ? "Direktebooking" : "Godkjenn først"
            )
            divider
            row(
                dest: .openingHours,
                icon: "clock.fill",
                title: "Åpningstid",
                subtitle: OpeningHoursService.compactLabel(form.openingHours) ?? "Hele dagen"
            )
        }
    }

    /// Plass-rader. Én rad per plass — hver åpner SpotMiniHub for den plassen.
    private var spotsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plasser")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
                .padding(.leading, 4)

            rowGroup {
                ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { idx, spot in
                    NavigationLink(value: EditDestination.spotMiniHub(idx)) {
                        spotRow(index: idx, spot: spot)
                    }
                    .buttonStyle(.plain)
                    if idx < form.spotMarkers.count - 1 {
                        Divider().padding(.leading, 60).opacity(0.5)
                    }
                }
            }
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destinationView(for dest: EditDestination) -> some View {
        switch dest {
        case .address:
            AddressStep(form: form, placesService: placesService)
                .navigationTitle("Adresse")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { hubToolbar }
        case .description:
            DescriptionStep(form: form)
                .navigationTitle("Beskrivelse")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { hubToolbar }
        case .photos:
            PhotosStep(form: form)
                .navigationTitle("Bilder")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { hubToolbar }
        case .amenities:
            AmenitiesStep(form: form)
                .navigationTitle("Fasiliteter")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { hubToolbar }
        case .messages:
            MessagesStep(form: form)
                .navigationTitle("Meldinger")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { hubToolbar }
        case .instantBooking:
            InstantBookingStep(form: form)
                .navigationTitle("Booking")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { hubToolbar }
        case .openingHours:
            OpeningHoursStep(form: form)
                .navigationTitle("Åpningstid")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { hubToolbar }
        case .spotMiniHub(let idx):
            SpotMiniHub(form: form, spotIndex: idx)
                .toolbar { hubToolbar }
        case .spotDetails(let idx):
            spotStepWrapper(idx: idx, title: "Detaljer") {
                SpotDetailsStep(form: form)
            }
        case .spotPrice(let idx):
            spotStepWrapper(idx: idx, title: "Pris") {
                SpotPriceStep(form: form)
            }
        case .spotExtras(let idx):
            spotStepWrapper(idx: idx, title: "Tillegg") {
                SpotExtrasStep(form: form)
            }
        case .spotCalendar(let idx):
            spotStepWrapper(idx: idx, title: "Kalender") {
                SpotCalendarStep(form: form)
            }
        case .spotDiscounts(let idx):
            spotStepWrapper(idx: idx, title: "Rabatter") {
                SpotDiscountsStep(form: form)
            }
        }
    }

    /// Spot-spesifikke steg er TabView(selection: form.currentSpotIndex) over
    /// alle plasser, så vi setter currentSpotIndex i .onAppear så TabView
    /// initialiseres på riktig plass.
    @ViewBuilder
    private func spotStepWrapper<Content: View>(idx: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        content()
            .navigationTitle("\(title) — plass \(idx + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { hubToolbar }
            .onAppear {
                if form.spotMarkers.indices.contains(idx) {
                    form.currentSpotIndex = idx
                }
            }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func rowGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200.opacity(0.6), lineWidth: 1))
    }

    private var divider: some View {
        Divider().padding(.leading, 60).opacity(0.5)
    }

    private func row(dest: EditDestination, icon: String, title: String, subtitle: String) -> some View {
        NavigationLink(value: dest) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary50)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary600)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral400)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func spotRow(index: Int, spot: SpotMarker) -> some View {
        let label = spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? spot.label!
            : "Plass \(index + 1)"
        let unit = form.effectivePriceUnit(for: spot).displayName
        let priceText: String = {
            if let p = spot.price, p > 0 { return "\(p) kr/\(unit)" }
            if let p = spot.pricePerNight, p > 0 { return "\(p) kr/\(unit)" }
            return "Pris mangler"
        }()
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.primary50).frame(width: 40, height: 40)
                Text("\(index + 1)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary700)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text(priceText)
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral400)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Computed strings

    private var descriptionSummary: String {
        let d = form.description.trimmingCharacters(in: .whitespaces)
        if d.isEmpty { return "Ikke satt" }
        return d.count > 40 ? String(d.prefix(40)) + "…" : d
    }

    private var messagesSummary: String {
        let hasIn = !form.checkinMessage.trimmingCharacters(in: .whitespaces).isEmpty
        let hasOut = !form.checkoutMessage.trimmingCharacters(in: .whitespaces).isEmpty
        if hasIn && hasOut { return "Innsjekk + utsjekk" }
        if hasIn { return "Innsjekk" }
        if hasOut { return "Utsjekk" }
        return "Ingen"
    }

    // MARK: - Save

    private func saveChanges() async {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let input = form.buildUpdateInput()
        do {
            let updated: [Listing] = try await supabase
                .from("listings")
                .update(input)
                .eq("id", value: listing.id)
                .select()
                .execute()
                .value
            guard let l = updated.first else {
                saveError = "Fikk ikke lov til å oppdatere annonsen."
                return
            }
            form.initialEditHash = form.currentEditHash()
            onSaved?(l)
            withAnimation { showSavedToast = true }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { showSavedToast = false }
        } catch {
            saveError = "Kunne ikke lagre: \(error.localizedDescription)"
        }
    }

    // MARK: - Toast + preview pill

    @ViewBuilder
    private var savedToast: some View {
        if showSavedToast {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
                Text("Endringer lagret")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary600)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var previewPill: some View {
        Button {
            showPreview = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Vis")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.neutral900)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.neutral200, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.18), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }
}

// MARK: - Destinations

enum EditDestination: Hashable {
    case address
    case description
    case photos
    case amenities
    case messages
    case instantBooking
    case openingHours
    case spotMiniHub(Int)
    case spotDetails(Int)
    case spotPrice(Int)
    case spotExtras(Int)
    case spotCalendar(Int)
    case spotDiscounts(Int)
}

// MARK: - SpotMiniHub

/// Sub-hub for én plass. Renderer rader for spot-spesifikke steg.
/// Pushes resolves i hub-en's NavigationStack via `.navigationDestination`.
struct SpotMiniHub: View {
    @ObservedObject var form: ListingFormModel
    let spotIndex: Int

    private var spot: SpotMarker? {
        form.spotMarkers.indices.contains(spotIndex) ? form.spotMarkers[spotIndex] : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                rowGroup {
                    row(
                        dest: .spotDetails(spotIndex),
                        icon: "doc.text",
                        title: "Detaljer",
                        subtitle: detailsSummary
                    )
                    divider
                    row(
                        dest: .spotPrice(spotIndex),
                        icon: "tag.fill",
                        title: "Pris",
                        subtitle: priceSummary
                    )
                    divider
                    row(
                        dest: .spotExtras(spotIndex),
                        icon: "sparkles",
                        title: "Tillegg",
                        subtitle: extrasSummary
                    )
                    divider
                    row(
                        dest: .spotCalendar(spotIndex),
                        icon: "calendar",
                        title: "Kalender",
                        subtitle: calendarSummary
                    )
                    if form.category == .parking {
                        divider
                        row(
                            dest: .spotDiscounts(spotIndex),
                            icon: "calendar.badge.clock",
                            title: "Lengre opphold",
                            subtitle: discountsSummary
                        )
                    }
                }
                Spacer().frame(height: 24)
            }
            .padding(16)
        }
        .background(Color.neutral50)
        .navigationTitle("Plass \(spotIndex + 1)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerCard: some View {
        if let s = spot {
            VStack(alignment: .leading, spacing: 6) {
                Text(s.label?.trimmingCharacters(in: .whitespaces).isEmpty == false ? s.label! : "Plass \(spotIndex + 1)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.neutral900)
                if let desc = s.description?.trimmingCharacters(in: .whitespaces), !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral600)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200.opacity(0.6), lineWidth: 1))
        }
    }

    // MARK: - Row helpers (duplisert fra EditListingHub for å unngå internal-API)

    @ViewBuilder
    private func rowGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200.opacity(0.6), lineWidth: 1))
    }

    private var divider: some View {
        Divider().padding(.leading, 60).opacity(0.5)
    }

    private func row(dest: EditDestination, icon: String, title: String, subtitle: String) -> some View {
        NavigationLink(value: dest) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary50)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary600)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral400)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summaries

    private var detailsSummary: String {
        guard let s = spot else { return "—" }
        let types = s.effectiveVehicleTypes
        if types.isEmpty { return "Ingen biltype" }
        let typeText = types.map { $0.displayName }.joined(separator: " · ")
        if let len = s.vehicleMaxLength, len > 0 {
            return "\(typeText) · maks \(len) m"
        }
        return typeText
    }

    private var priceSummary: String {
        guard let s = spot else { return "—" }
        let unit = form.effectivePriceUnit(for: s).displayName
        if let p = s.price, p > 0 { return "\(p) kr/\(unit)" }
        if let p = s.pricePerNight, p > 0 { return "\(p) kr/\(unit)" }
        return "Pris mangler"
    }

    private var extrasSummary: String {
        guard let s = spot else { return "—" }
        let count = s.extras?.count ?? 0
        return count == 0 ? "Ingen" : "\(count) tillegg"
    }

    private var calendarSummary: String {
        guard let s = spot else { return "—" }
        let blocked = s.blockedDates?.count ?? 0
        let overrides = s.datePriceOverrides?.count ?? 0
        if blocked == 0 && overrides == 0 { return "Alle datoer åpne" }
        var parts: [String] = []
        if blocked > 0 { parts.append("\(blocked) blokkert") }
        if overrides > 0 { parts.append("\(overrides) prisjustert") }
        return parts.joined(separator: " · ")
    }

    private var discountsSummary: String {
        guard let s = spot else { return "—" }
        let pkgCount = s.pricePackages?.count ?? 0
        let hasLegacy = (s.weeklyPrice ?? 0) > 0 || (s.monthlyPrice ?? 0) > 0 || (s.yearPrice ?? 0) > 0
        if pkgCount == 0 && !hasLegacy { return "Ingen tilbud" }
        if pkgCount > 0 { return "\(pkgCount) tilbud" }
        return "Aktive tilbud"
    }
}
