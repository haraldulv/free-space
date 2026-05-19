import SwiftUI

/// Hub-og-spoke-redigering for en eksisterende annonse. Speiler "Ny annonse"-
/// wizarden ved å gjenbruke step-views direkte fra `Steps/`, men i stedet
/// for lineær Tilbake/Neste-flyt pusher den hvert steg via NavigationStack.
///
/// TU-61: erstatter den gamle tab-baserte EditListingView.
struct EditListingHub: View {
    let listing: Listing
    var onSaved: ((Listing) -> Void)? = nil
    var onDeleted: (() -> Void)? = nil

    @StateObject private var form = ListingFormModel()
    @StateObject private var placesService = PlacesService()
    @Environment(\.dismiss) private var dismiss

    @State private var path: [EditDestination] = []
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSavedToast = false
    @State private var showPreview = false
    /// QR-koder og slett-annonse er flyttet fra "Mine annonser"-kortet til
    /// EditListingHub-toolbaren (TU-100). Tannhjul-menyen øverst-høyre lar
    /// vert vise QR-koder eller slette annonsen herfra.
    @State private var qrTarget: Listing?
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    /// Hvilket value-card som er ekspandert inline (TU-99 Fase B). nil =
    /// alle kollapset. Bare ett kan være åpent om gangen, så åpning av et
    /// nytt kort lukker det forrige.
    @State private var expandedField: String?
    /// Snapshot av adresse + lat/lng tatt rett etter loadFromListing.
    /// Hvis brukeren endrer adressen må alle plasser re-plasseres på
    /// det nye kartet før Lagre blir aktiv (samme regel som i wizarden).
    @State private var initialLocationKey: String = ""

    /// Sant hvis vert har endret adresse/koordinater siden hub åpnet.
    private var addressChanged: Bool {
        currentLocationKey() != initialLocationKey
    }

    /// Lagre kan trykkes når noe er endret, men hvis det er adressen,
    /// må alle plasser være re-plassert på det nye kartet først.
    private var canSave: Bool {
        guard form.isDirty else { return false }
        if addressChanged {
            return form.spotMarkers.count >= form.spots
        }
        return true
    }

    private func currentLocationKey() -> String {
        "\(form.address)|\(form.city)|\(form.lat)|\(form.lng)"
    }

    var body: some View {
        NavigationStack(path: $path) {
            rootScreen
        }
        // Toast på NavigationStack-roten så den vises uansett om brukeren
        // er på hub-rot eller pushet inn på en destination.
        .overlay(alignment: .top) { savedToast }
        .onAppear {
            form.editingMode = true
            form.existingListingId = listing.id
            form.loadFromListing(listing)
            initialLocationKey = currentLocationKey()
        }
    }

    private var rootScreen: some View {
        scrollBody
            .background(Color.neutral50)
            .navigationTitle("Rediger annonse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { rootToolbar }
            .navigationDestination(for: EditDestination.self) { dest in
                destinationView(for: dest)
            }
            .overlay(alignment: .bottom) { previewPill }
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
            .sheet(item: $qrTarget) { listing in
                QRCodeModal(listing: listing)
            }
            .alert("Slett annonse?", isPresented: $showDeleteAlert) {
                Button("Slett", role: .destructive) {
                    Task { await deleteListing() }
                }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text("Denne handlingen kan ikke angres.")
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

    /// Toolbar for hub-rotnoden. X-knapp som dismisser direkte når ingen
    /// endringer; ellers åpner en kompakt iOS-Menu med Lagre/Forkast
    /// anchored rett under ikonet (TU-82). Bruker Image-label inni Menu
    /// for å unngå iOS 18 sin "Liquid Glass"-halo bak custom innhold.
    @ToolbarContentBuilder
    private var rootToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if form.isDirty {
                Menu {
                    Button {
                        Task {
                            await saveChanges()
                            if saveError == nil { dismiss() }
                        }
                    } label: {
                        Label("Lagre og lukk", systemImage: "checkmark.circle")
                    }
                    Button(role: .destructive) {
                        dismiss()
                    } label: {
                        Label("Forkast endringer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral700)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Lukk")
            } else {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral700)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
                    .accessibilityElement()
                    .accessibilityLabel("Lukk")
                    .accessibilityAddTraits(.isButton)
            }
        }
        // Tannhjul-menyen i toolbar-trailing rommer handlinger som ikke
        // hører hjemme i en redigerings-flow per se: QR-koder og slett-
        // annonse. Flyttet hit i TU-100 fra "Mine annonser"-kortets tre-
        // prikker-meny. Image + onTapGesture (i stedet for Menu(label:))
        // for å unngå iOS 18 toolbar-button-halo (feedback_ios18_toolbar_button_halo).
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    qrTarget = listing
                } label: {
                    Label("Vis QR-kode", systemImage: "qrcode")
                }
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Slett annonse", systemImage: "trash")
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral700)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Innstillinger")
        }
    }

    /// Toolbar for destination-stegene. System-back-chevron tar venstre-
    /// siden, vi tilbyr kun en standard Lagre-knapp til høyre — uten
    /// custom Capsule-bg så iOS 18 ikke legger Liquid Glass-halo bak.
    @ToolbarContentBuilder
    private var stepToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isSaving {
                ProgressView().controlSize(.small)
            } else {
                Button("Lagre") {
                    Task { await saveChanges() }
                }
                .fontWeight(.semibold)
                .tint(.primary600)
                .disabled(!canSave)
            }
        }
    }

    /// Toolbar for `.address`-destinasjonen. Når adressen er endret må
    /// vert pushe videre til `.markSpots` for re-plassering før lagring
    /// er mulig (TU-81). Lagre vises kun når adressen er uendret.
    @ToolbarContentBuilder
    private var addressToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isSaving {
                ProgressView().controlSize(.small)
            } else if addressChanged {
                Button("Neste") {
                    path.append(.markSpots)
                }
                .fontWeight(.semibold)
                .tint(.primary600)
            } else {
                Button("Lagre") {
                    Task { await saveChanges() }
                }
                .fontWeight(.semibold)
                .tint(.primary600)
                .disabled(!canSave)
            }
        }
    }

    /// Toolbar for `.markSpots`-destinasjonen. Lagre disabled inntil alle
    /// plasser er markert. Etter vellykket save popper vi helt tilbake
    /// til hub-roten — mark-spots-stepet er gjort.
    @ToolbarContentBuilder
    private var markSpotsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isSaving {
                ProgressView().controlSize(.small)
            } else {
                Button("Lagre") {
                    Task {
                        await saveChanges()
                        if saveError == nil { path.removeAll() }
                    }
                }
                .fontWeight(.semibold)
                .tint(.primary600)
                .disabled(form.spotMarkers.count < form.spots)
            }
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

    // MARK: - Section list (TU-99: Airbnb-stil valueCards)
    //
    // Hvert felt vises som sitt eget kort med felt-navn (subtittel) + nåværende
    // verdi (stor tekst). Tap åpner enten en fullskjerm-editor (push) eller
    // ekspanderer kortet inline (Fase B — Tittel, Lengde, Booking, Meldinger).

    private var sectionList: some View {
        VStack(spacing: 12) {
            valueCard(
                icon: "mappin.and.ellipse",
                title: "Adresse",
                value: form.address.isEmpty ? "Ikke satt" : form.address,
                dest: .address
            )
            expandableValueCard(
                icon: "text.alignleft",
                title: "Tittel",
                value: form.title.trimmingCharacters(in: .whitespaces).isEmpty ? "Ikke satt" : form.title,
                fieldKey: "title"
            ) {
                inlineTitleEditor
            }
            valueCard(
                icon: "photo.on.rectangle.angled",
                title: "Bilder",
                value: form.imageURLs.isEmpty ? "Ingen bilder" : "\(form.imageURLs.count) bilde\(form.imageURLs.count == 1 ? "" : "r")",
                dest: .photos
            )
            valueCard(
                icon: "wand.and.stars",
                title: "Fasiliteter",
                value: form.selectedAmenities.isEmpty ? "Ingen valgt" : "\(form.selectedAmenities.count) valgt",
                dest: .amenities
            )
            expandableValueCard(
                icon: "bubble.left.fill",
                title: "Meldinger",
                value: messagesSummary,
                fieldKey: "messages"
            ) {
                inlineMessagesEditor
            }
            expandableValueCard(
                icon: "calendar.day.timeline.left",
                title: "Lengde på opphold",
                value: stayLengthSummary,
                fieldKey: "stay"
            ) {
                inlineStayLengthEditor
            }
        }
    }

    /// Listing-nivå innstillinger som kun gjelder parkering.
    private var listingLevelSection: some View {
        VStack(spacing: 12) {
            expandableValueCard(
                icon: form.instantBooking ? "bolt.fill" : "hand.raised.fill",
                title: "Booking",
                value: form.instantBooking ? "Direktebooking" : "Godkjenn først",
                fieldKey: "booking"
            ) {
                inlineBookingEditor
            }
            // ÅPNINGSTIDER PAUSET pre-launch — re-aktiver post-launch
        }
    }

    /// Plass-kort. Én valueCard per plass — hver åpner SpotMiniHub for plassen.
    /// Spots er for komplekse til inline-expand (har 5 felter selv), så de
    /// pushes til SpotMiniHub som har sin egen valueCard-stack.
    private var spotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plasser")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 12) {
                ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { idx, spot in
                    NavigationLink(value: EditDestination.spotMiniHub(idx)) {
                        spotCard(index: idx, spot: spot)
                    }
                    .buttonStyle(.plain)
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
                .toolbar { addressToolbar }
        case .markSpots:
            markSpotsView
                .navigationTitle(form.spots == 1 ? "Marker plassen" : "Marker plassene")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { markSpotsToolbar }
        case .description:
            DescriptionStep(form: form)
                .navigationTitle("Tittel")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { stepToolbar }
        case .photos:
            PhotosStep(form: form)
                .navigationTitle("Bilder")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { stepToolbar }
        case .amenities:
            AmenitiesStep(form: form)
                .navigationTitle("Fasiliteter")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { stepToolbar }
        case .messages:
            MessagesStep(form: form)
                .navigationTitle("Meldinger")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { stepToolbar }
        case .instantBooking:
            InstantBookingStep(form: form)
                .navigationTitle("Booking")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { stepToolbar }
        case .stayLength:
            StayLengthStep(form: form)
                .navigationTitle("Lengde på opphold")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { stepToolbar }
        case .openingHours:
            OpeningHoursStep(form: form)
                .navigationTitle("Åpningstid")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { stepToolbar }
        case .spotMiniHub(let idx):
            SpotMiniHub(form: form, spotIndex: idx, onSave: { await saveChanges() })
                .toolbar { stepToolbar }
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

    /// View for `.markSpots`-destinasjonen. Speiler wizardens MarkSpotsStep-
    /// side: orange advarsel-banner øverst + fullskjerm-kart under (TU-81).
    private var markSpotsView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(form.spots == 1 ? "Plassen må re-plasseres" : "Plassene må re-plasseres")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text("Du har endret adresse. Marker \(form.spots == 1 ? "plassen" : "\(form.spots) plassene") på det nye kartet før du kan lagre.")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral600)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))

            MarkSpotsStep(form: form)
        }
        .background(Color.neutral50)
    }

    /// Spot-spesifikke steg er TabView(selection: form.currentSpotIndex) over
    /// alle plasser, så vi setter currentSpotIndex i .onAppear så TabView
    /// initialiseres på riktig plass.
    @ViewBuilder
    private func spotStepWrapper<Content: View>(idx: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        content()
            .navigationTitle("\(title) — plass \(idx + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { stepToolbar }
            .onAppear {
                if form.spotMarkers.indices.contains(idx) {
                    form.currentSpotIndex = idx
                }
            }
    }

    // MARK: - ValueCard helpers (TU-99 Airbnb-stil)
    //
    // Hvert kort står som sin egen RoundedRectangle med stroke. Titt + verdi
    // stables vertikalt: feltnavnet 13pt grå (subtittel), verdien 16pt
    // semibold (hovedtekst). Ikon ligger til venstre, chevron til høyre.
    //
    // `valueCard` = trykk pusher til fullskjerm-editor.
    // `expandableValueCard` = trykk åpner inline-edit i samme kort + viser
    // Lagre/Avbryt. Kun ett kort kan være ekspandert om gangen (driver via
    // `expandedField`-state på hub).

    private func valueCardChrome<Content: View>(
        isExpanded: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isExpanded ? Color.primary300 : Color.neutral200.opacity(0.7), lineWidth: 1)
            )
    }

    private func valueCardHeader(icon: String, title: String, value: String, isExpanded: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary50)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary600)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral400)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    private func valueCard(icon: String, title: String, value: String, dest: EditDestination) -> some View {
        NavigationLink(value: dest) {
            valueCardChrome(isExpanded: false) {
                valueCardHeader(icon: icon, title: title, value: value, isExpanded: false)
            }
        }
        .buttonStyle(.plain)
    }

    private func expandableValueCard<Content: View>(
        icon: String,
        title: String,
        value: String,
        fieldKey: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedField == fieldKey
        return valueCardChrome(isExpanded: isExpanded) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        expandedField = isExpanded ? nil : fieldKey
                    }
                } label: {
                    valueCardHeader(icon: icon, title: title, value: value, isExpanded: isExpanded)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 14) {
                        content()
                        expandedFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity)
                }
            }
        }
    }

    /// Footer i ekspandert kort. Avbryt = kollapse uten side-effekter
    /// (form.X-endringer blir i in-memory state og kan reverseres ved
    /// "Forkast endringer" i toolbar-X-menyen). Lagre = persistér via
    /// saveChanges() med en gang så det føles direkte.
    private var expandedFooter: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedField = nil
                }
            } label: {
                Text("Avbryt")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral700)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.neutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    await saveChanges()
                    withAnimation(.easeInOut(duration: 0.22)) {
                        expandedField = nil
                    }
                }
            } label: {
                Text("Lagre")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canSave ? Color.primary600 : Color.neutral300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
    }

    /// Spot-kort for hub-roten. Pushes til SpotMiniHub for å redigere
    /// detaljer/pris/tillegg/kalender/rabatter. Verdien viser sammendraget
    /// (pris + N tillegg + N blokkerte dater).
    private func spotCard(index: Int, spot: SpotMarker) -> some View {
        let label = spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? spot.label!
            : "Plass \(index + 1)"
        let unit = form.effectivePriceUnit(for: spot).displayName
        let priceText: String = {
            if let p = spot.price, p > 0 { return "\(p) kr/\(unit)" }
            if let p = spot.pricePerNight, p > 0 { return "\(p) kr/\(unit)" }
            return "Pris mangler"
        }()
        let extrasCount = spot.extras?.count ?? 0
        let blockedCount = spot.blockedDates?.count ?? 0
        var bits: [String] = [priceText]
        if extrasCount > 0 { bits.append("\(extrasCount) tillegg") }
        if blockedCount > 0 { bits.append("\(blockedCount) blokkert") }
        let summary = bits.joined(separator: " · ")
        return valueCardChrome(isExpanded: false) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.primary50).frame(width: 40, height: 40)
                    Text("\(index + 1)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary700)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                    Text(summary)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral400)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Inline editors (Fase B)

    private var inlineTitleEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("F.eks. Privat parkering i sentrum", text: $form.title)
                .textInputAutocapitalization(.sentences)
                .padding(14)
                .background(Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.neutral200, lineWidth: 1)
                )
            Text("\(form.title.count) av 60 tegn")
                .font(.system(size: 12))
                .foregroundStyle(.neutral400)
        }
    }

    private var inlineMessagesEditor: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Innsjekk-melding")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral500)
                TextField("Sendes ved bekreftet booking", text: $form.checkinMessage, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(14)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.neutral200, lineWidth: 1)
                    )
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Utsjekk-melding")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral500)
                TextField("Sendes før utsjekk", text: $form.checkoutMessage, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(14)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.neutral200, lineWidth: 1)
                    )
            }
        }
    }

    private var inlineStayLengthEditor: some View {
        let unitWord = form.category == .parking ? "dager" : "døgn"
        return VStack(spacing: 12) {
            HStack {
                Text("Min antall \(unitWord)")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral600)
                Spacer()
                TextField("Ingen", value: Binding(
                    get: { form.minStayDays ?? 0 },
                    set: { form.minStayDays = $0 > 0 ? $0 : nil }
                ), format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(10)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.neutral200, lineWidth: 1)
                    )
            }
            HStack {
                Text("Maks antall \(unitWord)")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral600)
                Spacer()
                TextField("Ingen", value: Binding(
                    get: { form.maxStayDays ?? 0 },
                    set: { form.maxStayDays = $0 > 0 ? $0 : nil }
                ), format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(10)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.neutral200, lineWidth: 1)
                    )
            }
        }
    }

    private var inlineBookingEditor: some View {
        VStack(spacing: 10) {
            bookingOption(
                isSelected: form.instantBooking,
                icon: "bolt.fill",
                title: "Direktebooking",
                subtitle: "Gjester kan booke uten godkjenning"
            ) {
                form.instantBooking = true
            }
            bookingOption(
                isSelected: !form.instantBooking,
                icon: "hand.raised.fill",
                title: "Godkjenn først",
                subtitle: "Du må godkjenne hver booking"
            ) {
                form.instantBooking = false
            }
        }
    }

    private func bookingOption(
        isSelected: Bool,
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .primary700 : .neutral500)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? .primary600 : .neutral300)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primary300 : Color.neutral200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    private var stayLengthSummary: String {
        let unit = form.category == .parking ? "dag" : "døgn"
        let unitPlural = form.category == .parking ? "dager" : "døgn"
        let minPart: String = {
            if let m = form.minStayDays, m > 0 {
                return "Min \(m) \(m == 1 ? unit : unitPlural)"
            }
            return "Min ikke satt"
        }()
        if let mx = form.maxStayDays, mx > 0 {
            return "\(minPart), maks \(mx) \(mx == 1 ? unit : unitPlural)"
        }
        return minPart
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

    /// Sletter annonsen og dismisser hub'en. Parent gjør egen re-load via
    /// `onDeleted`-callback (typisk MyListingsView som re-laster listings).
    /// Flyttet hit i TU-100 fra ProfileView.
    private func deleteListing() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await supabase
                .from("listings")
                .delete()
                .eq("id", value: listing.id)
                .execute()
            onDeleted?()
            dismiss()
        } catch {
            saveError = "Kunne ikke slette: \(error.localizedDescription)"
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
    case markSpots
    case description
    case photos
    case amenities
    case messages
    case instantBooking
    case stayLength
    case openingHours
    case spotMiniHub(Int)
    case spotDetails(Int)
    case spotPrice(Int)
    case spotExtras(Int)
    case spotCalendar(Int)
    case spotDiscounts(Int)
}

// MARK: - SpotMiniHub

/// Sub-hub for én plass. Hver felt rendres som sitt eget valueCard
/// (TU-99 Airbnb-stil). Pris-kortet ekspanderer inline; resten pusher til
/// fullskjerm-editor i hub'ens NavigationStack.
struct SpotMiniHub: View {
    @ObservedObject var form: ListingFormModel
    let spotIndex: Int
    /// Kalles fra inline-expand "Lagre" — persisterer til Supabase via
    /// EditListingHub's saveChanges. Closure passes som async fra parent.
    var onSave: (() async -> Void)? = nil

    /// Inline-expand state. Bare ett kort åpent om gangen.
    @State private var expandedField: String?

    private var spot: SpotMarker? {
        form.spotMarkers.indices.contains(spotIndex) ? form.spotMarkers[spotIndex] : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard
                valueCard(
                    dest: .spotDetails(spotIndex),
                    icon: "doc.text",
                    title: "Detaljer",
                    value: detailsSummary
                )
                expandableValueCard(
                    icon: "tag.fill",
                    title: "Pris",
                    value: priceSummary,
                    fieldKey: "price"
                ) {
                    inlinePriceEditor
                }
                valueCard(
                    dest: .spotExtras(spotIndex),
                    icon: "sparkles",
                    title: "Tillegg",
                    value: extrasSummary
                )
                valueCard(
                    dest: .spotCalendar(spotIndex),
                    icon: "calendar",
                    title: "Kalender",
                    value: calendarSummary
                )
                if form.category == .parking {
                    valueCard(
                        dest: .spotDiscounts(spotIndex),
                        icon: "calendar.badge.clock",
                        title: "Lengre opphold",
                        value: discountsSummary
                    )
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

    // MARK: - ValueCard helpers (duplisert fra EditListingHub)

    private func valueCardChrome<Content: View>(
        isExpanded: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isExpanded ? Color.primary300 : Color.neutral200.opacity(0.7), lineWidth: 1)
            )
    }

    private func valueCardHeader(icon: String, title: String, value: String, isExpanded: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary50)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary600)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral400)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    private func valueCard(dest: EditDestination, icon: String, title: String, value: String) -> some View {
        NavigationLink(value: dest) {
            valueCardChrome(isExpanded: false) {
                valueCardHeader(icon: icon, title: title, value: value, isExpanded: false)
            }
        }
        .buttonStyle(.plain)
    }

    private func expandableValueCard<Content: View>(
        icon: String,
        title: String,
        value: String,
        fieldKey: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedField == fieldKey
        return valueCardChrome(isExpanded: isExpanded) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        expandedField = isExpanded ? nil : fieldKey
                    }
                } label: {
                    valueCardHeader(icon: icon, title: title, value: value, isExpanded: isExpanded)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 14) {
                        content()
                        expandedFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity)
                }
            }
        }
    }

    private var expandedFooter: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedField = nil
                }
            } label: {
                Text("Avbryt")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral700)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.neutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    await onSave?()
                    withAnimation(.easeInOut(duration: 0.22)) {
                        expandedField = nil
                    }
                }
            } label: {
                Text("Lagre")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Inline editors (Pris)

    private var inlinePriceEditor: some View {
        guard form.spotMarkers.indices.contains(spotIndex) else {
            return AnyView(EmptyView())
        }
        let unit = form.effectivePriceUnit(for: form.spotMarkers[spotIndex]).displayName
        return AnyView(
            HStack(spacing: 8) {
                TextField("0", value: Binding(
                    get: { form.spotMarkers[spotIndex].price ?? 0 },
                    set: { form.spotMarkers[spotIndex].price = max(0, $0) }
                ), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .padding(14)
                .background(Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.neutral200, lineWidth: 1)
                )

                Text("kr/\(unit)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral500)
            }
        )
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
