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
    /// Segmentkontroll "Annonse / Plasser" (TU-99 redux build 232).
    /// Speiler Airbnbs "Your space / Arrival guide"-pille men gir naturlig
    /// split for Tuno: listing-felter vs spot-cards.
    @State private var selectedTab: HubTab = .annonse
    /// "Folded fan"-bildene starter samlet og spring-er ut til target-state
    /// når hub-en vises (build 233 etter Harald-feedback om "stack-animasjon").
    /// Triggrer i onAppear i `photosStackCard`.
    @State private var photosSpread: Bool = false
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
        // TU-99 redux (build 232): Airbnb-stil "Listing editor"-layout.
        // Segmentkontroll "Annonse / Plasser" øverst (etter tannhjul-toolbar),
        // photosStackCard som første kort i "Annonse"-fanen, valueCards uten
        // ikoner under. Hero-kortet er fjernet — bildene ligger nå i sitt
        // eget kort med "spilkort"-preview (stacked thumbnails).
        //
        // Build 233: ScrollViewReader-wrap + scrollTo expandedField for å
        // sikre at ekspandert inline-editor blir synlig over tastaturet.
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    tabSegmentControl
                    if selectedTab == .annonse {
                        photosStackCard
                        sectionList
                        if listing.category == .parking {
                            listingLevelSection
                        }
                    } else {
                        spotsSection
                    }
                    Spacer().frame(height: 80)
                }
                .padding(16)
            }
            .onChange(of: expandedField) { _, newField in
                guard let key = newField else { return }
                // Litt delay så keyboard-avoidance settler først, ellers
                // scroller vi før layouten har stabilisert seg.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(key, anchor: .top)
                    }
                }
            }
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

    // MARK: - Segmentkontroll (TU-99 redux build 232)

    /// Capsule-pill segmentkontroll over feltene. To valg: "Annonse" =
    /// listing-felter (Adresse, Tittel, Bilder, Fasiliteter, etc.) og
    /// "Plasser" = spot-cards. Speiler Airbnbs "Your space / Arrival guide".
    private var tabSegmentControl: some View {
        HStack(spacing: 0) {
            tabSegmentButton(label: "Annonse", tab: .annonse)
            tabSegmentButton(label: "Plasser", tab: .plasser)
        }
        .padding(4)
        .background(Color.neutral100)
        .clipShape(Capsule())
        .padding(.horizontal, 40)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func tabSegmentButton(label: String, tab: HubTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .neutral900 : .neutral500)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bilder-kort (TU-99 redux build 232)

    /// Første kort i "Annonse"-fanen. Tittel "Bilder" + verdi "N bilder"
    /// over en "spilkort"-stack-preview av de 3 første bildene (ZStack med
    /// offset + rotation). Tap → ekspanderer inline med horisontal carousel.
    private var photosStackCard: some View {
        let isExpanded = expandedField == "photos"
        let imageCount = form.imageURLs.count
        let valueText = imageCount == 0
            ? "Ingen bilder"
            : "\(imageCount) bilde\(imageCount == 1 ? "" : "r")"
        return valueCardChrome(isExpanded: isExpanded) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        expandedField = isExpanded ? nil : "photos"
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bilder")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.neutral500)
                            Text(valueText)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.neutral900)
                        }
                        photosStackPreview
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableCardStyle())

                if isExpanded {
                    VStack(spacing: 14) {
                        inlinePhotosEditor
                        expandedFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                    .transition(.opacity)
                }
            }
        }
        // Stack-animasjon (build 233): bildene starter samlet og fjærer ut
        // til "fan"-state etter en kort delay så det matcher det visuelle
        // tempoet av modal-presentationen. Resettes ved onDisappear så den
        // spilles igjen neste gang hub-en åpnes.
        .onAppear {
            photosSpread = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                    photosSpread = true
                }
            }
        }
        .onDisappear { photosSpread = false }
        .id("photos")
    }

    /// "Folded fan"-stack à la Airbnb sin Listing editor (Image #22).
    /// Tre kvadratiske bilder peeker ut fra forsiden — to bakerste roteres
    /// litt og forskyves til høyre så vi får et "stack of cards"-feel.
    /// Tap åpner det store inline-carouselen.
    ///
    /// `photosSpread` styrer onAppear-spreaden: bildene starter samlet på
    /// (0,0) med scale 1 og fjærer ut til sine target-tilstander (Fase 4).
    @ViewBuilder
    private var photosStackPreview: some View {
        if form.imageURLs.isEmpty {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.neutral100)
                .frame(height: 220)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 28))
                            .foregroundStyle(.neutral400)
                        Text("Trykk for å legge til")
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                    }
                )
        } else {
            let visible = Array(form.imageURLs.prefix(3).enumerated())
            ZStack {
                ForEach(visible.reversed(), id: \.offset) { idx, urlString in
                    CachedAsyncImage(url: URL(string: urlString)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.neutral100)
                    }
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
                    .scaleEffect(photosSpread ? (1 - CGFloat(idx) * 0.05) : 1.0)
                    .offset(
                        x: photosSpread ? CGFloat(idx) * 22 : 0,
                        y: photosSpread ? CGFloat(idx) * 4 : 0
                    )
                    .rotationEffect(.degrees(photosSpread ? Double(idx) * 4 : 0))
                    .zIndex(Double(3 - idx))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
        }
    }

    /// Horisontal scroll med alle bildene + "Legg til"-knapp på slutten.
    /// Reorder pusher til PhotosStep — for kompleks for inline.
    private var inlinePhotosEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(form.imageURLs.enumerated()), id: \.offset) { idx, urlString in
                        ZStack(alignment: .topTrailing) {
                            CachedAsyncImage(url: URL(string: urlString)) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color.neutral100)
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button {
                                form.imageURLs.remove(at: idx)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white, .black.opacity(0.55))
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    NavigationLink(value: EditDestination.photos) {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.primary600)
                            Text("Endre")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary600)
                        }
                        .frame(width: 120, height: 120)
                        .background(Color.primary50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .foregroundColor(.primary300)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Section list (TU-99: Airbnb-stil valueCards)
    //
    // Hvert felt vises som sitt eget kort med felt-navn (subtittel) + nåværende
    // verdi (stor tekst). Tap åpner enten en fullskjerm-editor (push) eller
    // ekspanderer kortet inline (Fase B — Tittel, Lengde, Booking, Meldinger).

    private var sectionList: some View {
        VStack(spacing: 12) {
            expandableValueCard(
                title: "Tittel",
                value: form.title.trimmingCharacters(in: .whitespaces).isEmpty ? "Ikke satt" : form.title,
                fieldKey: "title"
            ) {
                inlineTitleEditor
            }
            valueCard(
                title: "Adresse",
                value: form.address.isEmpty ? "Ikke satt" : form.address,
                dest: .address
            )
            amenitiesValueCard
            messagesValueCard
            expandableValueCard(
                title: "Lengde på opphold",
                value: stayLengthSummary,
                fieldKey: "stay"
            ) {
                inlineStayLengthEditor
            }
            calendarValueCard
        }
    }

    /// Kalender-kort i Annonse-fanen. Med én plass linker det direkte til
    /// plassens kalender; med flere pusher det til en list-picker som lar
    /// vert velge hvilken plass. Sammendrag aggregerer blokkerte dager
    /// på tvers av alle plasser.
    @ViewBuilder
    private var calendarValueCard: some View {
        if form.spotMarkers.count <= 1 {
            valueCard(
                title: "Kalender",
                value: aggregateCalendarSummary,
                dest: .spotCalendar(0)
            )
        } else {
            NavigationLink(value: EditDestination.calendarPicker) {
                valueCardChrome(isExpanded: false) {
                    valueCardHeader(
                        title: "Kalender",
                        value: aggregateCalendarSummary
                    )
                }
            }
            .buttonStyle(PressableCardStyle())
        }
    }

    /// Summen av blokkerte dager på tvers av alle plasser, formatert som
    /// "Tilgjengelig" eller "X dager blokkert".
    private var aggregateCalendarSummary: String {
        let total = form.spotMarkers.reduce(0) { acc, spot in
            acc + (spot.blockedDates?.count ?? 0)
        }
        if total == 0 { return "Tilgjengelig" }
        return "\(total) \(total == 1 ? "dag" : "dager") blokkert"
    }

    /// Multi-spot picker — vises bare når annonsen har 2+ plasser. Hver rad
    /// pusher til SpotCalendarStep for den valgte plassen.
    private var calendarPickerView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { idx, spot in
                    NavigationLink(value: EditDestination.spotCalendar(idx)) {
                        let label = spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false
                            ? spot.label!
                            : "Plass \(idx + 1)"
                        let blockedCount = spot.blockedDates?.count ?? 0
                        let value = blockedCount == 0
                            ? "Tilgjengelig"
                            : "\(blockedCount) \(blockedCount == 1 ? "dag" : "dager") blokkert"
                        valueCardChrome(isExpanded: false) {
                            valueCardHeader(title: label, value: value)
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding(16)
        }
        .background(Color.neutral50)
    }

    /// Listing-nivå innstillinger som kun gjelder parkering.
    private var listingLevelSection: some View {
        VStack(spacing: 12) {
            bookingValueCard
            // ÅPNINGSTIDER PAUSET pre-launch — re-aktiver post-launch
        }
    }

    // MARK: - Rikere closed-state-kort (build 233)
    //
    // Harald-feedback på build 232: "vi vil ha flere ting synlig". Disse
    // helperne speiler `expandableValueCard` men erstatter den enkle
    // strengverdien med visuelt rikere innhold — ikon-rad for Fasiliteter,
    // tekstpreview for Meldinger, ikon foran for Booking.

    /// Fasiliteter-kort med horisontal mini-rad av valgte amenity-ikoner.
    /// Maks 6 ikoner + "+N" pille hvis flere. Tom-state: "Ingen valgt".
    private var amenitiesValueCard: some View {
        let isExpanded = expandedField == "amenities"
        return valueCardChrome(isExpanded: isExpanded) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        expandedField = isExpanded ? nil : "amenities"
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fasiliteter")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.neutral500)
                        if form.selectedAmenities.isEmpty {
                            Text("Ingen valgt")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.neutral900)
                        } else {
                            selectedAmenitiesRow
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableCardStyle())

                if isExpanded {
                    VStack(spacing: 14) {
                        inlineAmenitiesEditor
                        expandedFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                    .transition(.opacity)
                }
            }
        }
        .id("amenities")
    }

    /// Horisontal rad av valgte amenity-ikoner. Filterer
    /// `form.availableAmenities` på `form.selectedAmenities` så vi får
    /// AmenityType-objekter med `.icon` og bevarer category-rekkefølgen.
    @ViewBuilder
    private var selectedAmenitiesRow: some View {
        let selected = form.availableAmenities.filter { form.selectedAmenities.contains($0.rawValue) }
        let maxIcons = 6
        HStack(spacing: 8) {
            ForEach(selected.prefix(maxIcons), id: \.rawValue) { amenity in
                Image(systemName: amenity.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary700)
                    .frame(width: 30, height: 30)
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if selected.count > maxIcons {
                Text("+\(selected.count - maxIcons)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary700)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Spacer(minLength: 0)
        }
    }

    /// Meldinger-kort med tittel "Melding ved innsjekk & utsjekk" og selve
    /// tekst-previewen som verdi (lineLimit(2) i valueCardHeader).
    private var messagesValueCard: some View {
        expandableValueCard(
            title: "Melding ved innsjekk & utsjekk",
            value: messagesSummary,
            fieldKey: "messages"
        ) {
            inlineMessagesEditor
        }
    }

    /// Booking-kort med ikon foran verdien. `bolt.fill` for Direktebooking,
    /// `hand.raised.fill` for Godkjenn først.
    private var bookingValueCard: some View {
        let isExpanded = expandedField == "booking"
        let isInstant = form.instantBooking
        let icon = isInstant ? "bolt.fill" : "hand.raised.fill"
        let valueText = isInstant ? "Direktebooking" : "Godkjenn først"
        return valueCardChrome(isExpanded: isExpanded) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        expandedField = isExpanded ? nil : "booking"
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Booking")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.neutral500)
                        HStack(spacing: 8) {
                            Image(systemName: icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary600)
                            Text(valueText)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.neutral900)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableCardStyle())

                if isExpanded {
                    VStack(spacing: 14) {
                        inlineBookingEditor
                        expandedFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                    .transition(.opacity)
                }
            }
        }
        .id("booking")
    }

    /// Plasser-fanen brettet ut (build 238): hver plass viser sin tittel +
    /// alle sub-kort (Detaljer, Pris, Tillegg, Kalender, Lengre opphold)
    /// direkte under hverandre. Ingen mellomnivå-SpotMiniHub-skjerm —
    /// brukeren ser all info uten å trykke seg inn på en plass først.
    private var spotsSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { idx, spot in
                spotBlock(index: idx, spot: spot)
            }
        }
    }

    /// Render én plass som en stack med tittel + alle sub-kort.
    @ViewBuilder
    private func spotBlock(index: Int, spot: SpotMarker) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let label = spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false
                ? spot.label!
                : "Plass \(index + 1)"
            Text(label.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .padding(.leading, 4)

            VStack(spacing: 12) {
                valueCard(
                    title: "Detaljer",
                    value: spotDetailsSummary(spot: spot),
                    dest: .spotDetails(index)
                )
                valueCard(
                    title: "Pris",
                    value: spotPriceSummary(spot: spot),
                    dest: .spotPrice(index)
                )
                valueCard(
                    title: "Tillegg",
                    value: spotExtrasSummary(spot: spot),
                    dest: .spotExtras(index)
                )
                valueCard(
                    title: "Kalender",
                    value: spotCalendarSummary(spot: spot),
                    dest: .spotCalendar(index)
                )
                if form.category == .parking {
                    valueCard(
                        title: "Lengre opphold",
                        value: spotDiscountsSummary(spot: spot),
                        dest: .spotDiscounts(index)
                    )
                }
            }
        }
    }

    // MARK: - Spot-sammendrag (brukt av brettet-ut Plasser-fane).
    // Speiler logikken i SpotMiniHub sine egne summary-properties (linje
    // 1736+), så vi viser konsistent info uansett om du ser på brettet-ut
    // Plasser-fane eller SpotMiniHub-push.

    private func spotDetailsSummary(spot: SpotMarker) -> String {
        let types = spot.vehicleTypes ?? (spot.vehicleType.map { [$0] } ?? [])
        let typeText: String
        if types.isEmpty {
            typeText = "Ikke valgt"
        } else if types.count == 1 {
            typeText = types[0].displayName
        } else {
            typeText = "\(types.count) typer"
        }
        if let len = spot.vehicleMaxLength, len > 0 {
            return "\(typeText) · maks \(len) m"
        }
        return typeText
    }

    private func spotPriceSummary(spot: SpotMarker) -> String {
        let unit = form.effectivePriceUnit(for: spot).displayName
        if let p = spot.price, p > 0 { return "\(p) kr/\(unit)" }
        if let p = spot.pricePerNight, p > 0 { return "\(p) kr/\(unit)" }
        return "Pris mangler"
    }

    private func spotExtrasSummary(spot: SpotMarker) -> String {
        let count = spot.extras?.count ?? 0
        return count == 0 ? "Ingen" : "\(count) tillegg"
    }

    private func spotCalendarSummary(spot: SpotMarker) -> String {
        let blocked = spot.blockedDates?.count ?? 0
        let overrides = spot.datePriceOverrides?.count ?? 0
        if blocked == 0 && overrides == 0 { return "Alle datoer åpne" }
        var parts: [String] = []
        if blocked > 0 { parts.append("\(blocked) blokkert") }
        if overrides > 0 { parts.append("\(overrides) prisjustert") }
        return parts.joined(separator: " · ")
    }

    private func spotDiscountsSummary(spot: SpotMarker) -> String {
        let pkgCount = spot.pricePackages?.count ?? 0
        let hasLegacy = (spot.weeklyPrice ?? 0) > 0 || (spot.monthlyPrice ?? 0) > 0 || (spot.yearPrice ?? 0) > 0
        if pkgCount == 0 && !hasLegacy { return "Ingen tilbud" }
        if pkgCount > 0 { return "\(pkgCount) tilbud" }
        return "Aktive tilbud"
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
        case .calendarPicker:
            calendarPickerView
                .navigationTitle("Velg plass")
                .navigationBarTitleDisplayMode(.inline)
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

    /// Airbnb-stil kort-header: feltnavn (medium, grå) over verdi (semibold,
    /// neutral900). Ingen ikon-prefiks, ingen chevron — affordance er
    /// at hele kortet er klikkbart. Build 238: slanket ned fra 16/22 til
    /// 13/17 etter Harald-feedback om at typografien var for voldsom.
    private func valueCardHeader(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.neutral500)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.neutral900)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func valueCard(title: String, value: String, dest: EditDestination) -> some View {
        NavigationLink(value: dest) {
            valueCardChrome(isExpanded: false) {
                valueCardHeader(title: title, value: value)
            }
        }
        .buttonStyle(PressableCardStyle())
    }

    private func expandableValueCard<Content: View>(
        title: String,
        value: String,
        fieldKey: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedField == fieldKey
        // .id(fieldKey) lar ScrollViewReader (i scrollBody) finne kortet
        // og scrolle det over tastaturet når feltet ekspanderes.
        return valueCardChrome(isExpanded: isExpanded) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        expandedField = isExpanded ? nil : fieldKey
                    }
                } label: {
                    valueCardHeader(title: title, value: value)
                }
                .buttonStyle(PressableCardStyle())

                if isExpanded {
                    VStack(spacing: 14) {
                        content()
                        expandedFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                    .transition(.opacity)
                }
            }
        }
        .id(fieldKey)
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

    /// Chip-grid med alle fasiliteter. Toggle på tap. 3-kolonner for å
    /// matche AmenitiesStep-stilen, men kompakt nok for inline-kort.
    private var inlineAmenitiesEditor: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(form.availableAmenities, id: \.rawValue) { amenity in
                let selected = form.selectedAmenities.contains(amenity.rawValue)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        if selected {
                            form.selectedAmenities.remove(amenity.rawValue)
                        } else {
                            form.selectedAmenities.insert(amenity.rawValue)
                        }
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: amenity.icon)
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(selected ? .white : .primary700)
                            .frame(width: 32, height: 32)
                            .background(selected ? Color.primary600 : Color.primary50)
                            .clipShape(RoundedRectangle(cornerRadius: 9))

                        Text(amenity.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.neutral900)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(selected ? Color.primary50 : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: selected ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Build 233: Godkjenn først ØVERST (Harald-feedback), begge bokser
    /// får samme minHeight i `bookingOption` for like store proporsjoner.
    private var inlineBookingEditor: some View {
        VStack(spacing: 10) {
            bookingOption(
                isSelected: !form.instantBooking,
                icon: "hand.raised.fill",
                title: "Godkjenn først",
                subtitle: "Du må godkjenne hver booking"
            ) {
                form.instantBooking = false
            }
            bookingOption(
                isSelected: form.instantBooking,
                icon: "bolt.fill",
                title: "Direktebooking",
                subtitle: "Gjester kan booke uten godkjenning"
            ) {
                form.instantBooking = true
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
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? .primary600 : .neutral300)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
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

    /// Tekstpreview til closed-state Meldinger-kortet (build 233).
    /// Returnerer den faktiske innsjekks-meldingen hvis satt, ellers
    /// utsjekksmeldingen, ellers "Ikke satt". `valueCardHeader` har allerede
    /// lineLimit(2) så lang tekst trunceres pent.
    private var messagesSummary: String {
        let inMsg = form.checkinMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let outMsg = form.checkoutMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !inMsg.isEmpty { return inMsg }
        if !outMsg.isEmpty { return outMsg }
        return "Ikke satt"
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
    case calendarPicker
    case spotMiniHub(Int)
    case spotDetails(Int)
    case spotPrice(Int)
    case spotExtras(Int)
    case spotCalendar(Int)
    case spotDiscounts(Int)
}

/// Segmentkontroll-tabs i EditListingHub (TU-99 redux build 232).
/// Speiler Airbnbs "Your space / Arrival guide"-segmenter.
enum HubTab: Hashable {
    case annonse   // Listing-felter (Adresse, Tittel, Bilder, Fasiliteter, etc.)
    case plasser   // Spot-kort (Plass 1, Plass 2, ...)
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
                    title: "Detaljer",
                    value: detailsSummary
                )
                expandableValueCard(
                    title: "Pris",
                    value: priceSummary,
                    fieldKey: "price"
                ) {
                    inlinePriceEditor
                }
                valueCard(
                    dest: .spotExtras(spotIndex),
                    title: "Tillegg",
                    value: extrasSummary
                )
                valueCard(
                    dest: .spotCalendar(spotIndex),
                    title: "Kalender",
                    value: calendarSummary
                )
                if form.category == .parking {
                    valueCard(
                        dest: .spotDiscounts(spotIndex),
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
            VStack(alignment: .leading, spacing: 4) {
                Text(s.label?.trimmingCharacters(in: .whitespaces).isEmpty == false ? s.label! : "Plass \(spotIndex + 1)")
                    .font(.system(size: 18, weight: .semibold))
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

    /// Airbnb-stil kort-header (TU-99 redux build 232). Ingen ikoner, ingen
    /// chevron, stor verdi over liten feltnavn-subtittel.
    private func valueCardHeader(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.neutral500)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.neutral900)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func valueCard(dest: EditDestination, title: String, value: String) -> some View {
        NavigationLink(value: dest) {
            valueCardChrome(isExpanded: false) {
                valueCardHeader(title: title, value: value)
            }
        }
        .buttonStyle(.plain)
    }

    private func expandableValueCard<Content: View>(
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
                    valueCardHeader(title: title, value: value)
                }
                .buttonStyle(PressableCardStyle())

                if isExpanded {
                    VStack(spacing: 14) {
                        content()
                        expandedFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
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
