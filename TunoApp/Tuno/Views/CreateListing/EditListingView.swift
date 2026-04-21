import SwiftUI
import PhotosUI

struct EditListingView: View {
    let listing: Listing
    var onSaved: ((Listing) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var isSaving = false
    @State private var savedMessage = false
    @State private var error: String?

    // Editable fields
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var spots: Int = 1
    @State private var maxVehicleLength: Int?
    @State private var checkInTime: String = "15:00"
    @State private var checkOutTime: String = "11:00"
    @State private var checkinMessage: String = ""
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var region: String = ""
    @State private var lat: Double = 0
    @State private var lng: Double = 0
    @State private var spotMarkers: [SpotMarker] = []
    @State private var isSpotMode = false
    @State private var sendCheckinMessage = false
    @State private var showSpotPlacementSheet = false
    @State private var mapUpdateTrigger = UUID()
    @State private var perSpotPricing: Bool = false
    @State private var perSpotCheckinMessage: Bool = false
    @State private var customSpotExtraName: [String: String] = [:]
    @State private var customSpotExtraPrice: [String: String] = [:]
    @State private var customSpotExtraPerNight: [String: Bool] = [:]
    @State private var showBackAlert = false
    @State private var keyboardVisible = false
    @State private var price: String = ""
    @State private var priceUnit: PriceUnit = .natt
    @State private var instantBooking: Bool = false
    @State private var selectedAmenities: Set<String> = []
    @State private var imageURLs: [String] = []
    @State private var blockedDates: Set<String> = []
    @State private var hideExactLocation: Bool = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var uploadingPhotos: [UploadingPhoto] = []
    @State private var selectedExtras: [ListingExtra] = []
    @State private var isActive: Bool = true
    @State private var customExtraName: String = ""
    @State private var customExtraPrice: String = ""
    @State private var customExtraPerNight: Bool = false

    private let tabs = ["Detaljer", "Plasser", "Bilder", "Fasiliteter", "Felles tillegg", "Tilgjengelighet"]

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button {
                            withAnimation { selectedTab = index }
                        } label: {
                            Text(tab)
                                .font(.system(size: 14, weight: selectedTab == index ? .semibold : .regular))
                                .foregroundStyle(selectedTab == index ? .primary600 : .neutral500)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .overlay(alignment: .bottom) {
                            if selectedTab == index {
                                Rectangle()
                                    .fill(Color.primary600)
                                    .frame(height: 2)
                            }
                        }
                    }
                }
            }
            .background(Color.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.neutral200).frame(height: 1)
            }

            // Error/success banner
            if let error {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red)
            }
            if savedMessage {
                Text("Lagret!")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green)
            }

            // Tab content
            TabView(selection: $selectedTab) {
                detailsTab.tag(0)
                locationTab.tag(1)
                imagesTab.tag(2)
                amenitiesTab.tag(3)
                extrasTab.tag(4)
                availabilityTab.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Save button — skjult når tastaturet er oppe
            if !keyboardVisible {
                Button {
                    saveChanges()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Lagre endringer")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSaving ? Color.primary400 : Color.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSaving)
                .padding()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
        .navigationTitle("Rediger annonse")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if savedMessage { dismiss() }
                    else { showBackAlert = true }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(savedMessage ? "Ferdig" : "Avbryt")
                    }
                    .foregroundStyle(Color.primary600)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Forkast endringer?", isPresented: $showBackAlert) {
            Button("Forkast", role: .destructive) { dismiss() }
            Button("Fortsett å redigere", role: .cancel) {}
        } message: {
            Text("Endringene dine blir ikke lagret.")
        }
        .onAppear { populateFields() }
    }

    // MARK: - Tab Views

    private var detailsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: isActive ? "eye.fill" : "eye.slash.fill")
                        .foregroundStyle(isActive ? Color.green : .neutral400)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isActive ? "Annonsen er aktiv" : "Annonsen er inaktiv")
                            .font(.system(size: 15, weight: .semibold))
                        Text(isActive ? "Synlig i søk" : "Skjult fra søk")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral500)
                    }
                    Spacer()
                    Toggle("", isOn: $isActive).labelsHidden()
                }
                .padding(12)
                .background(Color.neutral100)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                field("Tittel") {
                    TextField("Tittel", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                field("Beskrivelse") {
                    TextEditorWithCounter(
                        text: $description,
                        maxLength: 2000,
                        minHeight: 140,
                        placeholder: "Beskriv plassen — hva kjennetegner den, hva er i nærheten, hva bør gjesten vite?"
                    )
                }
                HStack(spacing: 16) {
                    field("Antall plasser") {
                        Stepper("\(spots)", value: $spots, in: 1...100)
                    }
                    if listing.category == .camping {
                        field("Maks lengde (m)") {
                            TextField("Meter", value: $maxVehicleLength, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                    }
                }
                HStack(spacing: 16) {
                    field("Innsjekk") {
                        TimePickerField(timeString: $checkInTime, defaultTime: "15:00")
                    }
                    field("Utsjekk") {
                        TimePickerField(timeString: $checkOutTime, defaultTime: "11:00")
                    }
                }

                Toggle(isOn: $instantBooking) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Umiddelbar booking")
                            .font(.system(size: 15, weight: .medium))
                        Text("Gjester kan reservere uten bekreftelse.")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral500)
                    }
                }
                .tint(.primary600)
            }
            .padding()
        }
    }

    private var locationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                field("Adresse") {
                    TextField("Adresse", text: $address)
                        .textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 16) {
                    field("By") {
                        TextField("By", text: $city)
                            .textFieldStyle(.roundedBorder)
                    }
                    field("Region") {
                        TextField("Region", text: $region)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // Map + Marker plasser-knapp
                if lat != 0 || lng != 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Button {
                                showSpotPlacementSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse")
                                    Text(spotMarkers.isEmpty ? "Marker plasser" : "Rediger plasser")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary600)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.primary50)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.primary600, lineWidth: 1))
                            }

                            Spacer()

                            if spots > 0 {
                                Text("\(spotMarkers.count) / \(spots)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.neutral500)
                                    .monospacedDigit()
                            }
                        }

                        LocationPickerMapView(
                            lat: $lat,
                            lng: $lng,
                            spotMarkers: $spotMarkers,
                            isSpotMode: false,
                            maxSpots: spots,
                            updateTrigger: mapUpdateTrigger,
                            onMaxReached: nil
                        )
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Tap på kartet for å justere hovedposisjon. Bruk \"Marker plasser\" for å plassere individuelle plass-markører.")
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral500)
                    }
                    .sheet(isPresented: $showSpotPlacementSheet) {
                        SpotPlacementSheet(
                            spotMarkers: $spotMarkers,
                            mainLat: lat,
                            mainLng: lng,
                            maxSpots: spots
                        )
                    }
                }

                // Pris-seksjon
                editLocationPricingSection

                // Utbrettede plass-kort (før velkomstmelding)
                if !spotMarkers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Plasser (\(spotMarkers.count))")
                            .font(.system(size: 18, weight: .semibold))
                        ForEach(Array(spotMarkers.enumerated()), id: \.offset) { index, _ in
                            editInlineSpotCard(index: index)
                        }
                    }
                }

                // Velkomstmelding-seksjon (etter plasser så pris-flyten ikke brytes)
                editCheckinMessageSection

                Toggle(isOn: $hideExactLocation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Skjul eksakt adresse")
                            .font(.system(size: 15, weight: .medium))
                        Text("Eksakt adresse deles etter booking.")
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                    }
                }
                .tint(.primary600)
            }
            .padding()
        }
    }

    // MARK: - Location pricing + inline spot cards (Edit)

    private var editLocationPricingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pris").font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(perSpotPricing ? "Standardpris per natt" : "Pris per natt")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.neutral600)
                HStack(spacing: 8) {
                    TextField("F.eks. 150", text: $price)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Text("kr").font(.system(size: 14)).foregroundStyle(.neutral500)
                }
                if perSpotPricing {
                    Text("Brukes som standard hvis en plass ikke har egen pris.")
                        .font(.system(size: 12)).foregroundStyle(.neutral500)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                editPricingModeRow(
                    title: "Samme pris for alle plasser",
                    subtitle: "Enkelt: alle plasser koster det samme.",
                    isSelected: !perSpotPricing,
                    onSelect: { setEditPerSpotPricing(false) }
                )
                editPricingModeRow(
                    title: "Individuell pris per plass",
                    subtitle: "Sett ulik pris for ulike plasser.",
                    isSelected: perSpotPricing,
                    onSelect: { setEditPerSpotPricing(true) }
                )
            }
        }
    }

    private func editPricingModeRow(title: String, subtitle: String, isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.primary600 : Color.neutral300, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle().fill(Color.primary600).frame(width: 10, height: 10)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(.neutral900)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.neutral500)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.primary50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func setEditPerSpotPricing(_ enabled: Bool) {
        perSpotPricing = enabled
        let defaultPrice = Int(price)
        if enabled {
            for i in spotMarkers.indices where spotMarkers[i].price == nil {
                spotMarkers[i].price = defaultPrice
            }
        } else {
            for i in spotMarkers.indices {
                spotMarkers[i].price = nil
            }
        }
    }

    private var editCheckinMessageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Velkomstmelding ved innsjekk")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Sendes automatisk til gjesten ved innsjekk-tid på ankomstdagen.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { sendCheckinMessage },
                    set: { newValue in
                        sendCheckinMessage = newValue
                        if !newValue {
                            checkinMessage = ""
                            perSpotCheckinMessage = false
                            for i in spotMarkers.indices {
                                spotMarkers[i].checkinMessage = nil
                            }
                        }
                    }
                ))
                .labelsHidden()
                .tint(.primary600)
            }

            if sendCheckinMessage {
                VStack(alignment: .leading, spacing: 10) {
                    editPricingModeRow(
                        title: "Samme melding for alle plasser",
                        subtitle: "Én felles velkomstmelding til alle gjester.",
                        isSelected: !perSpotCheckinMessage,
                        onSelect: { setEditPerSpotCheckinMessage(false) }
                    )
                    editPricingModeRow(
                        title: "Individuell melding per plass",
                        subtitle: "Sett ulik melding per plass (f.eks. ulike port-koder).",
                        isSelected: perSpotCheckinMessage,
                        onSelect: { setEditPerSpotCheckinMessage(true) }
                    )
                }

                if !perSpotCheckinMessage {
                    TextEditorWithCounter(
                        text: $checkinMessage,
                        maxLength: 600,
                        minHeight: 90,
                        placeholder: "F.eks. Hei! Port-kode er 1234. Plassen din er ved ladepunktet."
                    )
                } else {
                    Text("Skriv individuell melding på hver plass nedenfor.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
            }
        }
        .onAppear {
            let hasMsg = !checkinMessage.isEmpty
                || spotMarkers.contains(where: { !($0.checkinMessage?.isEmpty ?? true) })
            sendCheckinMessage = hasMsg
        }
    }

    private func setEditPerSpotCheckinMessage(_ enabled: Bool) {
        perSpotCheckinMessage = enabled
        if enabled {
            checkinMessage = ""
        } else {
            for i in spotMarkers.indices {
                spotMarkers[i].checkinMessage = nil
            }
        }
    }

    private func editInlineSpotCard(index: Int) -> some View {
        let spot = spotMarkers[index]
        let spotId = spot.id ?? ""

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.primary600)
                    .frame(width: 28, height: 28)
                    .overlay(Text("\(index + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(.white))
                TextField("Navn på plassen", text: Binding(
                    get: { spotMarkers[index].label ?? "" },
                    set: { spotMarkers[index].label = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Button {
                    spotMarkers.remove(at: index)
                    mapUpdateTrigger = UUID()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            if perSpotPricing {
                HStack(spacing: 8) {
                    Text("Pris").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral600).frame(width: 60, alignment: .leading)
                    TextField("", value: Binding(
                        get: { spotMarkers[index].price ?? Int(price) ?? 0 },
                        set: { spotMarkers[index].price = max(0, $0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 100)
                    Text("kr/natt").font(.system(size: 12)).foregroundStyle(.neutral500)
                    Spacer()
                }
            }

            let siteSpecific = ExtraType.available(for: listing.category ?? .camping, scope: .siteSpecific)
            if !siteSpecific.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tillegg på denne plassen")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral700)
                    ForEach(siteSpecific, id: \.rawValue) { preset in
                        editSiteExtraToggleRow(preset: preset, spotIndex: index)
                    }
                }
            }

            editCustomSpotExtrasSection(spotIndex: index, spotId: spotId)

            if perSpotCheckinMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Velkomstmelding for denne plassen")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral700)
                    TextEditor(text: Binding(
                        get: { spotMarkers[index].checkinMessage ?? "" },
                        set: { spotMarkers[index].checkinMessage = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 60)
                    .padding(6)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            SpotBlockedDatesSection(
                spotId: spotId,
                blockedDates: Binding(
                    get: { spotMarkers[index].blockedDates ?? [] },
                    set: { spotMarkers[index].blockedDates = $0.isEmpty ? nil : $0 }
                )
            )
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    private func editSiteExtraToggleRow(preset: ExtraType, spotIndex: Int) -> some View {
        let current = spotMarkers[spotIndex].extras ?? []
        let isSelected = current.contains(where: { $0.id == preset.rawValue })

        return VStack(spacing: 0) {
            Button {
                var extras = spotMarkers[spotIndex].extras ?? []
                if let idx = extras.firstIndex(where: { $0.id == preset.rawValue }) {
                    extras.remove(at: idx)
                } else {
                    extras.append(ListingExtra(
                        id: preset.rawValue,
                        name: preset.name,
                        price: preset.defaultPrice,
                        perNight: preset.perNight
                    ))
                }
                spotMarkers[spotIndex].extras = extras.isEmpty ? nil : extras
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: preset.icon)
                        .foregroundStyle(isSelected ? Color.primary600 : Color.neutral400)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(preset.name).font(.system(size: 13, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(.neutral900)
                        Text(preset.perNight ? "per natt" : "engangspris")
                            .font(.system(size: 10)).foregroundStyle(.neutral400)
                    }
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.primary600 : Color.neutral300, lineWidth: 2)
                            .frame(width: 18, height: 18)
                        if isSelected {
                            RoundedRectangle(cornerRadius: 4).fill(Color.primary600).frame(width: 18, height: 18)
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isSelected,
               let extras = spotMarkers[spotIndex].extras,
               let idx = extras.firstIndex(where: { $0.id == preset.rawValue }) {
                Divider().padding(.horizontal, 10)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Pris").font(.system(size: 12)).foregroundStyle(.neutral600)
                        TextField("", value: Binding(
                            get: { extras[idx].price },
                            set: { newVal in
                                var updated = spotMarkers[spotIndex].extras ?? []
                                if let i = updated.firstIndex(where: { $0.id == preset.rawValue }) {
                                    updated[i].price = max(0, newVal)
                                    spotMarkers[spotIndex].extras = updated
                                }
                            },
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        Text(preset.perNight ? "kr/natt" : "kr").font(.system(size: 11)).foregroundStyle(.neutral400)
                        Spacer()
                    }
                    TextField(
                        "Melding til gjest (valgfri)",
                        text: Binding(
                            get: { extras[idx].message ?? "" },
                            set: { newMsg in
                                var updated = spotMarkers[spotIndex].extras ?? []
                                if let i = updated.firstIndex(where: { $0.id == preset.rawValue }) {
                                    updated[i].message = newMsg.isEmpty ? nil : newMsg
                                    spotMarkers[spotIndex].extras = updated
                                }
                            },
                        ),
                        axis: .vertical,
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .lineLimit(2...3)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
            }
        }
        .background(isSelected ? Color.primary50 : Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func editCustomSpotExtrasSection(spotIndex: Int, spotId: String) -> some View {
        let presetIds = Set(ExtraType.allCases.map { $0.rawValue })
        let customExtras = (spotMarkers[spotIndex].extras ?? []).filter { !presetIds.contains($0.id) }

        VStack(alignment: .leading, spacing: 6) {
            if !customExtras.isEmpty {
                ForEach(customExtras) { extra in
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(.primary600).font(.system(size: 12))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(extra.name).font(.system(size: 12, weight: .medium))
                            Text("\(extra.price) \(extra.perNight ? "kr/natt" : "kr")")
                                .font(.system(size: 10)).foregroundStyle(.neutral500)
                        }
                        Spacer()
                        Button {
                            var updated = spotMarkers[spotIndex].extras ?? []
                            updated.removeAll { $0.id == extra.id }
                            spotMarkers[spotIndex].extras = updated.isEmpty ? nil : updated
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.neutral400)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack(spacing: 6) {
                TextField("Egendefinert tillegg", text: Binding(
                    get: { customSpotExtraName[spotId] ?? "" },
                    set: { customSpotExtraName[spotId] = $0 }
                )).textFieldStyle(.roundedBorder).font(.system(size: 12))
                TextField("Pris", text: Binding(
                    get: { customSpotExtraPrice[spotId] ?? "" },
                    set: { customSpotExtraPrice[spotId] = $0 }
                )).textFieldStyle(.roundedBorder).keyboardType(.numberPad).frame(width: 60).font(.system(size: 12))
                Toggle("", isOn: Binding(
                    get: { customSpotExtraPerNight[spotId] ?? false },
                    set: { customSpotExtraPerNight[spotId] = $0 }
                )).labelsHidden().scaleEffect(0.8)
                Button {
                    let name = (customSpotExtraName[spotId] ?? "").trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, let p = Int(customSpotExtraPrice[spotId] ?? ""), p > 0 else { return }
                    let pn = customSpotExtraPerNight[spotId] ?? false
                    var updated = spotMarkers[spotIndex].extras ?? []
                    updated.append(ListingExtra(id: UUID().uuidString.lowercased(), name: name, price: p, perNight: pn))
                    spotMarkers[spotIndex].extras = updated
                    customSpotExtraName[spotId] = ""
                    customSpotExtraPrice[spotId] = ""
                    customSpotExtraPerNight[spotId] = false
                } label: {
                    Text("+").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white).frame(width: 28, height: 28)
                        .background(Color.primary600).clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var imagesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10 - imageURLs.count,
                    matching: .images
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                        Text("Legg til bilder")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary600)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary200, style: StrokeStyle(lineWidth: 2, dash: [8])))
                }
                .onChange(of: selectedPhotos) { _, items in
                    uploadPhotos(items)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Rectangle().fill(Color.neutral100)
                                }
                            }
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button { imageURLs.remove(at: index) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                            .padding(4)
                        }
                    }

                    ForEach(uploadingPhotos) { photo in
                        ZStack {
                            if let uiImage = UIImage(data: photo.data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Rectangle().fill(Color.neutral100).frame(height: 100)
                            }
                            Rectangle()
                                .fill(Color.black.opacity(0.35))
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            ProgressView().tint(.white)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var amenitiesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let available: [AmenityType] = {
                    switch listing.category {
                    case .parking:
                        return [.evCharging, .covered, .securityCamera, .gated, .lighting, .handicapAccessible]
                    case .camping:
                        return [.electricity, .water, .wasteDisposal, .toilets, .showers, .wifi, .campfire, .lakeAccess, .mountainView, .petsAllowed, .handicapAccessible]
                    case nil:
                        return AmenityType.allCases
                    }
                }()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(available, id: \.rawValue) { amenity in
                        let selected = selectedAmenities.contains(amenity.rawValue)
                        Button {
                            if selected { selectedAmenities.remove(amenity.rawValue) }
                            else { selectedAmenities.insert(amenity.rawValue) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: amenity.icon).font(.system(size: 16))
                                Text(amenity.label).font(.system(size: 14, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(selected ? .primary600 : .neutral600)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14).padding(.horizontal, 8)
                            .background(selected ? Color.primary50 : Color.neutral50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: selected ? 2 : 1))
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var extrasTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Felles tillegg for hele plassen. Strøm, EV-lading og septik setter du per plass i Lokasjon-tabben.")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)

                let available = ExtraType.available(for: listing.category ?? .camping, scope: .areaWide)

                VStack(spacing: 10) {
                    ForEach(available, id: \.rawValue) { extra in
                        let isSelected = selectedExtras.contains(where: { $0.id == extra.rawValue })
                        let selectedExtra = selectedExtras.first(where: { $0.id == extra.rawValue })

                        VStack(spacing: 0) {
                            Button {
                                if let index = selectedExtras.firstIndex(where: { $0.id == extra.rawValue }) {
                                    selectedExtras.remove(at: index)
                                } else {
                                    selectedExtras.append(ListingExtra(
                                        id: extra.rawValue,
                                        name: extra.name,
                                        price: extra.defaultPrice,
                                        perNight: extra.perNight
                                    ))
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: extra.icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(isSelected ? .primary600 : .neutral400)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(extra.name)
                                            .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                                            .foregroundStyle(isSelected ? .neutral900 : .neutral600)
                                        Text(extra.perNight ? "per natt" : "engangspris")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.neutral400)
                                    }

                                    Spacer()

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(isSelected ? Color.primary600 : Color.neutral300, lineWidth: 2)
                                            .frame(width: 22, height: 22)
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.primary600)
                                                .frame(width: 22, height: 22)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }

                            if isSelected, let currentExtra = selectedExtra {
                                Divider().padding(.horizontal, 14)

                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 12) {
                                        Text("Pris (kr)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.neutral600)

                                        TextField("Pris", value: Binding(
                                            get: { currentExtra.price },
                                            set: { newPrice in
                                                if let idx = selectedExtras.firstIndex(where: { $0.id == extra.rawValue }) {
                                                    selectedExtras[idx].price = max(0, newPrice)
                                                }
                                            }
                                        ), format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                        .frame(width: 100)

                                        Text(extra.perNight ? "kr/natt" : "kr")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.neutral400)

                                        Spacer()
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Melding til gjest (valgfri)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.neutral600)
                                        TextField(
                                            "F.eks. Elbil-laderen har type 2-kontakt",
                                            text: Binding(
                                                get: { currentExtra.message ?? "" },
                                                set: { newMsg in
                                                    if let idx = selectedExtras.firstIndex(where: { $0.id == extra.rawValue }) {
                                                        selectedExtras[idx].message = newMsg.isEmpty ? nil : newMsg
                                                    }
                                                },
                                            ),
                                            axis: .vertical,
                                        )
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(2...4)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                        }
                        .background(isSelected ? Color.primary50 : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: isSelected ? 2 : 1)
                        )
                    }
                }

                customExtrasSection
            }
            .padding()
        }
    }

    private var customExtrasSection: some View {
        let presetIds = Set(ExtraType.allCases.map { $0.rawValue })
        let customExtras = selectedExtras.filter { !presetIds.contains($0.id) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Egendefinert tillegg")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 8)

            ForEach(customExtras) { extra in
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").foregroundStyle(.primary600)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(extra.name).font(.system(size: 14, weight: .medium))
                        Text("\(extra.price) \(extra.perNight ? "kr/natt" : "kr")")
                            .font(.system(size: 12)).foregroundStyle(.neutral500)
                    }
                    Spacer()
                    Button {
                        selectedExtras.removeAll { $0.id == extra.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.neutral400)
                    }
                }
                .padding(10)
                .background(Color.primary50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 8) {
                TextField("Navn", text: $customExtraName)
                    .textFieldStyle(.roundedBorder)
                TextField("Pris", text: $customExtraPrice)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
            }
            HStack {
                Toggle("Per natt", isOn: $customExtraPerNight).labelsHidden()
                Text(customExtraPerNight ? "per natt" : "engangspris")
                    .font(.system(size: 13)).foregroundStyle(.neutral500)
                Spacer()
                Button {
                    let name = customExtraName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, let price = Int(customExtraPrice), price > 0 else { return }
                    selectedExtras.append(ListingExtra(
                        id: UUID().uuidString.lowercased(),
                        name: name, price: price, perNight: customExtraPerNight
                    ))
                    customExtraName = ""
                    customExtraPrice = ""
                    customExtraPerNight = false
                } label: {
                    Text("Legg til")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.primary600).clipShape(Capsule())
                }
            }
        }
    }

    private var pricingTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                field("Pris (kr)") {
                    TextField("F.eks. 150", text: $price)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
                field("Prisenhet") {
                    HStack(spacing: 10) {
                        ForEach([PriceUnit.time, .natt], id: \.self) { unit in
                            let sel = priceUnit == unit
                            Button { priceUnit = unit } label: {
                                Text(unit == .time ? "Per time" : "Per natt")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(sel ? .primary600 : .neutral600)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(sel ? Color.primary50 : Color.neutral50)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(sel ? Color.primary600 : Color.neutral200, lineWidth: sel ? 2 : 1))
                            }
                        }
                    }
                }
                Toggle(isOn: $instantBooking) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill").foregroundStyle(.green)
                        Text("Direktebooking").font(.system(size: 15, weight: .semibold))
                    }
                }
                .tint(.primary600)
            }
            .padding()
        }
    }

    private var availabilityTab: some View {
        // Reuse the same calendar from create wizard
        AvailabilityStepView(form: availabilityFormProxy)
    }

    // MARK: - Helpers

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.neutral600)
            content()
        }
    }

    private func populateFields() {
        title = listing.title
        description = listing.description ?? ""
        spots = listing.spots ?? 1
        maxVehicleLength = listing.maxVehicleLength.map { Int($0) }
        checkInTime = listing.checkInTime ?? "15:00"
        checkOutTime = listing.checkOutTime ?? "11:00"
        checkinMessage = listing.checkinMessage ?? ""
        address = listing.address ?? ""
        city = listing.city ?? ""
        region = listing.region ?? ""
        lat = listing.lat ?? 0
        lng = listing.lng ?? 0
        spotMarkers = listing.spotMarkers ?? []
        price = listing.price.map { "\($0)" } ?? ""
        priceUnit = listing.priceUnit ?? .natt
        instantBooking = listing.instantBooking ?? false
        selectedAmenities = Set(listing.amenities ?? [])
        imageURLs = listing.images ?? []
        blockedDates = Set(listing.blockedDates ?? [])
        hideExactLocation = listing.hideExactLocation ?? false
        selectedExtras = listing.extras ?? []
        isActive = listing.isActive ?? true
        // Set perSpotPricing om noen spot har egen pris
        perSpotPricing = (listing.spotMarkers ?? []).contains { $0.price != nil }
        // Set perSpotCheckinMessage om noen spot har egen melding
        perSpotCheckinMessage = (listing.spotMarkers ?? []).contains { ($0.checkinMessage?.isEmpty == false) }
    }

    // Proxy form model for AvailabilityStepView reuse
    private var availabilityFormProxy: ListingFormModel {
        let model = ListingFormModel()
        model.blockedDates = blockedDates
        return model
    }

    private func saveChanges() {
        isSaving = true
        error = nil
        savedMessage = false

        Task {
            do {
                let updates = UpdateListingInput(
                    title: title,
                    description: description,
                    spots: spots,
                    checkInTime: checkInTime,
                    checkOutTime: checkOutTime,
                    checkinMessage: checkinMessage.trimmingCharacters(in: .whitespaces).isEmpty ? nil : checkinMessage,
                    address: address,
                    city: city,
                    region: region,
                    lat: lat,
                    lng: lng,
                    price: Int(price) ?? 0,
                    priceUnit: priceUnit.rawValue,
                    instantBooking: instantBooking,
                    amenities: Array(selectedAmenities),
                    images: imageURLs,
                    blockedDates: Array(blockedDates).sorted(),
                    hideExactLocation: hideExactLocation,
                    spotMarkers: spotMarkers,
                    extras: selectedExtras,
                    maxVehicleLength: listing.category == .camping ? maxVehicleLength : nil,
                    isActive: isActive
                )

                let updated: [Listing] = try await supabase
                    .from("listings")
                    .update(updates)
                    .eq("id", value: listing.id)
                    .select()
                    .execute()
                    .value

                guard let updatedListing = updated.first else {
                    self.error = "Fikk ikke lov til å oppdatere annonsen. Er du pålogget som eier?"
                    isSaving = false
                    return
                }

                isSaving = false
                savedMessage = true
                onSaved?(updatedListing)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            } catch {
                self.error = "Kunne ikke lagre: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }

    private func uploadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        selectedPhotos = []

        Task {
            guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

            var pending: [(UploadingPhoto, Data)] = []
            for item in items {
                guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
                let compressed = ImageCompression.compressForUpload(raw) ?? raw
                let photo = UploadingPhoto(data: compressed)
                pending.append((photo, compressed))
                uploadingPhotos.append(photo)
            }

            await withTaskGroup(of: (UUID, String?).self) { group in
                for (photo, data) in pending {
                    group.addTask {
                        let fileName = "\(userId)/\(UUID().uuidString.lowercased()).jpg"
                        do {
                            try await supabase.storage
                                .from("listing-images")
                                .upload(fileName, data: data, options: .init(contentType: "image/jpeg"))
                            let publicURL = try supabase.storage
                                .from("listing-images")
                                .getPublicURL(path: fileName)
                            return (photo.id, publicURL.absoluteString)
                        } catch {
                            print("Image upload failed: \(error)")
                            return (photo.id, nil)
                        }
                    }
                }

                for await (photoId, url) in group {
                    uploadingPhotos.removeAll { $0.id == photoId }
                    if let url = url {
                        imageURLs.append(url)
                    }
                }
            }
        }
    }
}

// MARK: - Update payload

private struct UpdateListingInput: Encodable {
    let title: String
    let description: String
    let spots: Int
    let checkInTime: String
    let checkOutTime: String
    let checkinMessage: String?
    let address: String
    let city: String
    let region: String
    let lat: Double
    let lng: Double
    let price: Int
    let priceUnit: String
    let instantBooking: Bool
    let amenities: [String]
    let images: [String]
    let blockedDates: [String]
    let hideExactLocation: Bool
    let spotMarkers: [SpotMarker]
    let extras: [ListingExtra]
    let maxVehicleLength: Int?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case title, description, spots, address, city, region, lat, lng, price, amenities, images, extras
        case checkInTime = "check_in_time"
        case checkOutTime = "check_out_time"
        case checkinMessage = "checkin_message"
        case priceUnit = "price_unit"
        case instantBooking = "instant_booking"
        case blockedDates = "blocked_dates"
        case hideExactLocation = "hide_exact_location"
        case spotMarkers = "spot_markers"
        case maxVehicleLength = "max_vehicle_length"
        case isActive = "is_active"
    }
}
