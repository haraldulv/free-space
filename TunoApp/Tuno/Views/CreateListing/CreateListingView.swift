import SwiftUI
import PhotosUI
import GoogleMaps

struct CreateListingView: View {
    var onCreated: ((Listing) -> Void)? = nil
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var form = ListingFormModel()
    @StateObject private var placesService = PlacesService()
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccess = false
    @State private var showBackAlert = false
    @State private var keyboardVisible = false

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            StepIndicatorBar(currentStep: form.currentStep, totalSteps: form.totalSteps, labels: form.stepLabels)
                .padding(.horizontal)
                .padding(.top, 8)

            // Error banner
            if let error = form.error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal)
                .background(Color.red)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Step content
            TabView(selection: $form.currentStep) {
                CategoryStepView(form: form).tag(0)
                BasicInfoStepView(form: form).tag(1)
                LocationStepView(form: form, placesService: placesService).tag(2)
                ImageUploadStepView(form: form).tag(3)
                AmenitiesStepView(form: form).tag(4)
                ExtrasStepView(form: form).tag(5)
                AvailabilityStepView(form: form).tag(6)
                ReviewStepView(form: form).tag(7)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: form.currentStep)

            // Navigation buttons — skjult når tastaturet er oppe, siden "Ferdig" i keyboard-toolbar tar den plassen
            if !keyboardVisible {
            HStack(spacing: 12) {
                if form.currentStep > 0 {
                    Button {
                        form.goBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Tilbake")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.neutral700)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.neutral100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button {
                    if form.currentStep == form.totalSteps - 1 {
                        submitListing()
                    } else {
                        form.goNext()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if form.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text(form.currentStep == form.totalSteps - 1 ? "Publiser annonse" : "Neste")
                            if form.currentStep < form.totalSteps - 1 {
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(form.isSubmitting ? Color.primary400 : Color.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(form.isSubmitting)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            } // end if !keyboardVisible
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
        .navigationTitle("Ny annonse")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showBackAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Avbryt")
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
        .alert("Forkast ny annonse?", isPresented: $showBackAlert) {
            Button("Forkast", role: .destructive) { dismiss() }
            Button("Fortsett å redigere", role: .cancel) {}
        } message: {
            Text("Du mister alt du har skrevet inn.")
        }
        .alert("Annonse opprettet!", isPresented: $showSuccess) {
            Button("Flott") { dismiss() }
        } message: {
            Text("Annonsen din er nå publisert og synlig for gjester.")
        }
    }

    private func submitListing() {
        guard let userId = authManager.currentUser?.id else { return }
        form.isSubmitting = true
        form.error = nil

        Task {
            do {
                let input = form.buildInput(hostId: userId.uuidString.lowercased(), profile: authManager.profile)
                let inserted: [Listing] = try await supabase
                    .from("listings")
                    .insert(input)
                    .select()
                    .execute()
                    .value

                // Reload profile to update isHost if needed
                await authManager.loadProfile()
                form.isSubmitting = false
                if let newListing = inserted.first {
                    onCreated?(newListing)
                }
                showSuccess = true
            } catch {
                form.error = "Kunne ikke opprette annonse: \(error.localizedDescription)"
                form.isSubmitting = false
            }
        }
    }
}

// MARK: - Step Indicator Bar

struct StepIndicatorBar: View {
    let currentStep: Int
    let totalSteps: Int
    let labels: [String]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step <= currentStep ? Color.primary600 : Color.neutral200)
                        .frame(height: 3)
                }
            }

            Text(labels[currentStep])
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.neutral500)
        }
    }
}

// MARK: - Step 0: Category & Vehicle Type

struct CategoryStepView: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Hva slags plass leier du ut?")
                    .font(.system(size: 22, weight: .bold))

                // Category cards
                HStack(spacing: 12) {
                    categoryCard(
                        category: .camping,
                        icon: "tent.fill",
                        title: "Camping / Bobil"
                    )
                    categoryCard(
                        category: .parking,
                        icon: "car.fill",
                        title: "Parkering"
                    )
                }

                // Vehicle type
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hvilken kjøretøytype passer?")
                        .font(.system(size: 17, weight: .semibold))

                    HStack(spacing: 10) {
                        ForEach([VehicleType.motorhome, .car], id: \.self) { type in
                            vehicleButton(type: type)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func categoryCard(category: ListingCategory, icon: String, title: String) -> some View {
        let selected = form.category == category
        return Button {
            form.category = category
            form.selectedAmenities = []
            if category == .parking {
                form.priceUnit = .time
            }
        } label: {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(selected ? .primary600 : .neutral600)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(selected ? Color.primary50 : Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: selected ? 2 : 1)
            )
        }
    }

    private func vehicleButton(type: VehicleType) -> some View {
        let selected = form.vehicleType == type
        return Button {
            form.vehicleType = type
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                Text(type.displayName)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(selected ? .primary600 : .neutral500)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? Color.primary50 : Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: selected ? 2 : 1)
            )
        }
    }
}

// MARK: - Step 1: Basic Info

struct BasicInfoStepView: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Fortell om plassen din")
                    .font(.system(size: 22, weight: .bold))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tittel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral600)
                    TextField("F.eks. Sentral parkering ved Oslo S", text: $form.title)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Beskrivelse")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral600)
                    TextEditorWithCounter(
                        text: $form.description,
                        maxLength: 2000,
                        minHeight: 140,
                        placeholder: "Beskriv plassen — hva kjennetegner den, hva er i nærheten, hva bør gjesten vite?"
                    )
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Antall plasser")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.neutral600)
                        Stepper("\(form.spots)", value: $form.spots, in: 1...100)
                            .padding(8)
                            .background(Color.neutral50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if form.category == .camping {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Maks lengde (m)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.neutral600)
                            TextField("F.eks. 10", value: $form.maxVehicleLength, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                    }
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Innsjekk")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.neutral600)
                        TimePickerField(timeString: $form.checkInTime, defaultTime: "15:00")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Utsjekk")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.neutral600)
                        TimePickerField(timeString: $form.checkOutTime, defaultTime: "11:00")
                    }
                }

                Toggle(isOn: $form.instantBooking) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Umiddelbar booking")
                            .font(.system(size: 15, weight: .medium))
                        Text("Gjester kan reservere uten å vente på bekreftelse fra deg.")
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                    }
                }
                .tint(.primary600)
            }
            .padding()
        }
    }
}

// MARK: - Step 2: Location

struct LocationStepView: View {
    @ObservedObject var form: ListingFormModel
    @ObservedObject var placesService: PlacesService
    @State private var searchText = ""
    @State private var isSpotMode = false
    @State private var mapUpdateTrigger = UUID()
    @State private var sendCheckinMessage = false
    @State private var showSpotPlacementSheet = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Hvor er plassen?")
                    .font(.system(size: 22, weight: .bold))

                // Address search
                VStack(alignment: .leading, spacing: 6) {
                    Text("Adresse")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral600)

                    TextField("Søk etter adresse...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _, newValue in
                            placesService.autocomplete(query: newValue)
                        }

                    // Predictions dropdown
                    if !placesService.predictions.isEmpty && isSearchFocused {
                        VStack(spacing: 0) {
                            ForEach(placesService.predictions) { prediction in
                                Button {
                                    selectPlace(prediction)
                                } label: {
                                    HStack {
                                        Image(systemName: "mappin")
                                            .foregroundStyle(.neutral400)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(prediction.mainText)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.neutral900)
                                            Text(prediction.secondaryText)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.neutral500)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                }
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    }
                }

                if !form.address.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(form.address)
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral600)
                    }
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("By")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.neutral600)
                        TextField("By", text: $form.city)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Region")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.neutral600)
                        TextField("Region", text: $form.region)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // Map + Marker plasser-knapp
                if form.lat != 0 || form.lng != 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Button {
                                showSpotPlacementSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse")
                                    Text(form.spotMarkers.isEmpty ? "Marker plasser" : "Rediger plasser")
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

                            if form.spots > 0 {
                                Text("\(form.spotMarkers.count) / \(form.spots)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.neutral500)
                                    .monospacedDigit()
                            }
                        }

                        LocationPickerMapView(
                            lat: $form.lat,
                            lng: $form.lng,
                            spotMarkers: $form.spotMarkers,
                            isSpotMode: false,
                            maxSpots: form.spots,
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
                            spotMarkers: $form.spotMarkers,
                            mainLat: form.lat,
                            mainLng: form.lng,
                            maxSpots: form.spots
                        )
                    }
                }

                // Pris-seksjon — settes sammen med plassene
                if form.lat != 0 || form.lng != 0 {
                    pricingSection
                }

                // Utbrettede plass-editors (før velkomstmelding så pris-flyten ikke brytes)
                if !form.spotMarkers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Plasser (\(form.spotMarkers.count))")
                            .font(.system(size: 18, weight: .semibold))

                        ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { index, _ in
                            inlineSpotCard(index: index)
                        }
                    }
                }

                // Velkomstmelding-seksjon — etter plasser så pris-flyten ikke brytes
                if form.lat != 0 || form.lng != 0 {
                    checkinMessageSection
                }

                // Privacy toggle
                Toggle(isOn: $form.hideExactLocation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Skjul eksakt adresse")
                            .font(.system(size: 15, weight: .medium))
                        Text("Gjester ser omtrentlig område. Eksakt adresse deles etter booking.")
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                    }
                }
                .tint(.primary600)
            }
            .padding()
        }
    }

    // MARK: - Pricing section

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pris")
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(form.perSpotPricing ? "Standardpris per natt" : "Pris per natt")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.neutral600)
                HStack(spacing: 8) {
                    TextField("F.eks. 150", text: $form.price)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Text("kr")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral500)
                }
                if form.perSpotPricing {
                    Text("Brukes som standard hvis en plass ikke har egen pris.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                pricingModeRow(
                    title: "Samme pris for alle plasser",
                    subtitle: "Enkelt: alle plasser koster det samme.",
                    isSelected: !form.perSpotPricing,
                    onSelect: { setPerSpotPricing(false) }
                )
                pricingModeRow(
                    title: "Individuell pris per plass",
                    subtitle: "Sett ulik pris for ulike plasser (f.eks. sjøutsikt vs bakrekke).",
                    isSelected: form.perSpotPricing,
                    onSelect: { setPerSpotPricing(true) }
                )
            }
        }
    }

    private func pricingModeRow(title: String, subtitle: String, isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
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
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
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

    private func setPerSpotPricing(_ enabled: Bool) {
        form.perSpotPricing = enabled
        let defaultPrice = Int(form.price)
        if enabled {
            // Pre-fyll alle spots med listing.price om de ikke har egen
            for i in form.spotMarkers.indices where form.spotMarkers[i].price == nil {
                form.spotMarkers[i].price = defaultPrice
            }
        } else {
            // Clear alle individuelle priser — fall tilbake til listing.price
            for i in form.spotMarkers.indices {
                form.spotMarkers[i].price = nil
            }
        }
    }

    // MARK: - Check-in message section

    private var checkinMessageSection: some View {
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
                            form.checkinMessage = ""
                            form.perSpotCheckinMessage = false
                            for i in form.spotMarkers.indices {
                                form.spotMarkers[i].checkinMessage = nil
                            }
                        }
                    }
                ))
                .labelsHidden()
                .tint(.primary600)
            }

            if sendCheckinMessage {
                VStack(alignment: .leading, spacing: 10) {
                    pricingModeRow(
                        title: "Samme melding for alle plasser",
                        subtitle: "Én felles velkomstmelding til alle gjester.",
                        isSelected: !form.perSpotCheckinMessage,
                        onSelect: { setPerSpotCheckinMessage(false) }
                    )
                    pricingModeRow(
                        title: "Individuell melding per plass",
                        subtitle: "Sett ulik melding per plass (f.eks. ulike port-koder).",
                        isSelected: form.perSpotCheckinMessage,
                        onSelect: { setPerSpotCheckinMessage(true) }
                    )
                }

                if !form.perSpotCheckinMessage {
                    TextEditorWithCounter(
                        text: $form.checkinMessage,
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
            let hasMsg = !form.checkinMessage.isEmpty
                || form.spotMarkers.contains(where: { !($0.checkinMessage?.isEmpty ?? true) })
            sendCheckinMessage = hasMsg
        }
    }

    private func setPerSpotCheckinMessage(_ enabled: Bool) {
        form.perSpotCheckinMessage = enabled
        if enabled {
            form.checkinMessage = ""
        } else {
            for i in form.spotMarkers.indices {
                form.spotMarkers[i].checkinMessage = nil
            }
        }
    }

    // MARK: - Inline spot card

    private func inlineSpotCard(index: Int) -> some View {
        let spot = form.spotMarkers[index]
        let spotId = spot.id ?? ""

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.primary600)
                    .frame(width: 28, height: 28)
                    .overlay(Text("\(index + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(.white))
                TextField("Navn på plassen", text: Binding(
                    get: { form.spotMarkers[index].label ?? "" },
                    set: { form.spotMarkers[index].label = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Button {
                    form.spotMarkers.remove(at: index)
                    mapUpdateTrigger = UUID()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            if form.perSpotPricing {
                HStack(spacing: 8) {
                    Text("Pris")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral600)
                        .frame(width: 60, alignment: .leading)
                    TextField("", value: Binding(
                        get: { form.spotMarkers[index].price ?? Int(form.price) ?? 0 },
                        set: { form.spotMarkers[index].price = max(0, $0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 100)
                    Text("kr/natt")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                    Spacer()
                }
            }

            let siteSpecific = ExtraType.available(for: form.category ?? .camping, scope: .siteSpecific)
            if !siteSpecific.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tillegg på denne plassen")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral700)
                    ForEach(siteSpecific, id: \.rawValue) { preset in
                        siteExtraToggleRow(preset: preset, spotIndex: index)
                    }
                }
            }

            customSpotExtrasSection(spotIndex: index, spotId: spotId)

            if form.perSpotCheckinMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Velkomstmelding for denne plassen")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral700)
                    TextEditor(text: Binding(
                        get: { form.spotMarkers[index].checkinMessage ?? "" },
                        set: { form.spotMarkers[index].checkinMessage = $0.isEmpty ? nil : $0 }
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
                    get: { form.spotMarkers[index].blockedDates ?? [] },
                    set: { form.spotMarkers[index].blockedDates = $0.isEmpty ? nil : $0 }
                )
            )
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    private func siteExtraToggleRow(preset: ExtraType, spotIndex: Int) -> some View {
        let current = form.spotMarkers[spotIndex].extras ?? []
        let isSelected = current.contains(where: { $0.id == preset.rawValue })

        return VStack(spacing: 0) {
            Button {
                var extras = form.spotMarkers[spotIndex].extras ?? []
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
                form.spotMarkers[spotIndex].extras = extras.isEmpty ? nil : extras
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
               let extras = form.spotMarkers[spotIndex].extras,
               let idx = extras.firstIndex(where: { $0.id == preset.rawValue }) {
                Divider().padding(.horizontal, 10)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Pris").font(.system(size: 12)).foregroundStyle(.neutral600)
                        TextField("", value: Binding(
                            get: { extras[idx].price },
                            set: { newVal in
                                var updated = form.spotMarkers[spotIndex].extras ?? []
                                if let i = updated.firstIndex(where: { $0.id == preset.rawValue }) {
                                    updated[i].price = max(0, newVal)
                                    form.spotMarkers[spotIndex].extras = updated
                                }
                            },
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        Text(preset.perNight ? "kr/natt" : "kr").font(.system(size: 11)).foregroundStyle(.neutral400)
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Melding til gjest (valgfri)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.neutral600)
                        TextField(
                            "Sendes ved booking",
                            text: Binding(
                                get: { extras[idx].message ?? "" },
                                set: { newMsg in
                                    var updated = form.spotMarkers[spotIndex].extras ?? []
                                    if let i = updated.firstIndex(where: { $0.id == preset.rawValue }) {
                                        updated[i].message = newMsg.isEmpty ? nil : newMsg
                                        form.spotMarkers[spotIndex].extras = updated
                                    }
                                },
                            ),
                            axis: .vertical,
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .lineLimit(2...3)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
            }
        }
        .background(isSelected ? Color.primary50 : Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @State private var customSpotExtraName: [String: String] = [:]
    @State private var customSpotExtraPrice: [String: String] = [:]
    @State private var customSpotExtraPerNight: [String: Bool] = [:]

    @ViewBuilder
    private func customSpotExtraCard(spotIndex: Int, extra: ListingExtra) -> some View {
        let extraId = extra.id
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(.primary600).font(.system(size: 12))
                TextField("Navn", text: Binding(
                    get: { extra.name },
                    set: { newName in
                        var updated = form.spotMarkers[spotIndex].extras ?? []
                        if let i = updated.firstIndex(where: { $0.id == extraId }) {
                            updated[i].name = newName
                            form.spotMarkers[spotIndex].extras = updated
                        }
                    },
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, weight: .medium))
                Spacer()
                Button {
                    var updated = form.spotMarkers[spotIndex].extras ?? []
                    updated.removeAll { $0.id == extraId }
                    form.spotMarkers[spotIndex].extras = updated.isEmpty ? nil : updated
                } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                TextField("Pris", value: Binding(
                    get: { extra.price },
                    set: { newPrice in
                        var updated = form.spotMarkers[spotIndex].extras ?? []
                        if let i = updated.firstIndex(where: { $0.id == extraId }) {
                            updated[i].price = max(0, newPrice)
                            form.spotMarkers[spotIndex].extras = updated
                        }
                    },
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(width: 80)
                Toggle("Per natt", isOn: Binding(
                    get: { extra.perNight },
                    set: { newPN in
                        var updated = form.spotMarkers[spotIndex].extras ?? []
                        if let i = updated.firstIndex(where: { $0.id == extraId }) {
                            updated[i].perNight = newPN
                            form.spotMarkers[spotIndex].extras = updated
                        }
                    },
                ))
                .font(.system(size: 11))
                .tint(.primary600)
            }

            TextField(
                "Melding til gjest (valgfri)",
                text: Binding(
                    get: { extra.message ?? "" },
                    set: { newMsg in
                        var updated = form.spotMarkers[spotIndex].extras ?? []
                        if let i = updated.firstIndex(where: { $0.id == extraId }) {
                            updated[i].message = newMsg.isEmpty ? nil : newMsg
                            form.spotMarkers[spotIndex].extras = updated
                        }
                    },
                ),
                axis: .vertical,
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12))
            .lineLimit(2...3)
        }
        .padding(10)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func customSpotExtrasSection(spotIndex: Int, spotId: String) -> some View {
        let presetIds = Set(ExtraType.allCases.map { $0.rawValue })
        let customExtras = (form.spotMarkers[spotIndex].extras ?? []).filter { !presetIds.contains($0.id) }

        VStack(alignment: .leading, spacing: 6) {
            if !customExtras.isEmpty {
                ForEach(customExtras) { extra in
                    customSpotExtraCard(spotIndex: spotIndex, extra: extra)
                }
            }

            HStack(spacing: 6) {
                TextField("Egendefinert tillegg", text: Binding(
                    get: { customSpotExtraName[spotId] ?? "" },
                    set: { customSpotExtraName[spotId] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                TextField("Pris", text: Binding(
                    get: { customSpotExtraPrice[spotId] ?? "" },
                    set: { customSpotExtraPrice[spotId] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(width: 60)
                .font(.system(size: 12))
                Toggle("", isOn: Binding(
                    get: { customSpotExtraPerNight[spotId] ?? false },
                    set: { customSpotExtraPerNight[spotId] = $0 }
                )).labelsHidden().scaleEffect(0.8)
                Button {
                    let name = (customSpotExtraName[spotId] ?? "").trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, let price = Int(customSpotExtraPrice[spotId] ?? ""), price > 0 else { return }
                    let perNight = customSpotExtraPerNight[spotId] ?? false
                    var updated = form.spotMarkers[spotIndex].extras ?? []
                    updated.append(ListingExtra(
                        id: UUID().uuidString.lowercased(),
                        name: name, price: price, perNight: perNight
                    ))
                    form.spotMarkers[spotIndex].extras = updated
                    customSpotExtraName[spotId] = ""
                    customSpotExtraPrice[spotId] = ""
                    customSpotExtraPerNight[spotId] = false
                } label: {
                    Text("+").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.primary600)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func selectPlace(_ prediction: PlacePrediction) {
        isSearchFocused = false
        searchText = prediction.description
        form.address = prediction.description

        // Extract city from secondary text
        let parts = prediction.secondaryText.components(separatedBy: ", ")
        if let cityPart = parts.first {
            form.city = cityPart
        }
        if parts.count > 1 {
            form.region = parts.last ?? ""
        }

        Task {
            if let detail = await placesService.getPlaceDetail(placeId: prediction.id) {
                form.lat = detail.lat
                form.lng = detail.lng
                mapUpdateTrigger = UUID()
            }
            placesService.clear()
        }
    }
}

// MARK: - Step 3: Image Upload

struct ImageUploadStepView: View {
    @ObservedObject var form: ListingFormModel
    @State private var showPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Legg til bilder")
                    .font(.system(size: 22, weight: .bold))

                Text("JPG, PNG — maks 10 bilder")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)

                // Add photos button
                PhotosPicker(
                    selection: $form.selectedPhotos,
                    maxSelectionCount: 10 - form.imageURLs.count,
                    matching: .images
                ) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 36))
                            .foregroundStyle(.primary500)
                        Text("Velg bilder")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary600)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary200, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    )
                }
                .onChange(of: form.selectedPhotos) { _, newItems in
                    uploadPhotos(newItems)
                }

                // Image grid
                if !form.imageURLs.isEmpty || !form.uploadingPhotos.isEmpty {
                    Text("Første bilde er forsidebilde. Bruk pilene for å endre rekkefølge.")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(Array(form.imageURLs.enumerated()), id: \.offset) { index, url in
                            imageCell(index: index, url: url)
                        }

                        ForEach(form.uploadingPhotos) { photo in
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
            }
            .padding()
        }
    }

    @ViewBuilder
    private func imageCell(index: Int, url: String) -> some View {
        let isCover = index == 0
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
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isCover ? Color.primary600 : Color.clear, lineWidth: 2),
            )

            // Remove button — top right
            Button {
                form.imageURLs.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            .padding(4)

            // Cover badge — top left
            if isCover {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 8))
                    Text("Forside").font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary600)
                .clipShape(Capsule())
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            // Move controls — bottom bar
            HStack(spacing: 4) {
                Button {
                    moveImage(from: index, to: index - 1)
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(index == 0 ? .neutral300 : .neutral700)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.95))
                        .clipShape(Circle())
                }
                .disabled(index == 0)

                if !isCover {
                    Button {
                        moveImage(from: index, to: 0)
                    } label: {
                        Text("Sett som forside")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.neutral700)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Capsule())
                    }
                }

                Button {
                    moveImage(from: index, to: index + 1)
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(index == form.imageURLs.count - 1 ? .neutral300 : .neutral700)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.95))
                        .clipShape(Circle())
                }
                .disabled(index == form.imageURLs.count - 1)
            }
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func moveImage(from: Int, to: Int) {
        guard from >= 0, from < form.imageURLs.count else { return }
        let target = max(0, min(form.imageURLs.count - 1, to))
        if target == from { return }
        let item = form.imageURLs.remove(at: from)
        form.imageURLs.insert(item, at: target)
    }

    private func uploadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        form.selectedPhotos = []

        Task {
            guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

            // 1) Load data locally, compress (iPhone photos are >5 MB), show previews
            var pending: [(UploadingPhoto, Data)] = []
            for item in items {
                guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
                let compressed = ImageCompression.compressForUpload(raw) ?? raw
                let photo = UploadingPhoto(data: compressed)
                pending.append((photo, compressed))
                form.uploadingPhotos.append(photo)
            }

            // 2) Upload in parallel
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
                    form.uploadingPhotos.removeAll { $0.id == photoId }
                    if let url = url {
                        form.imageURLs.append(url)
                    }
                }
            }
        }
    }
}

// MARK: - Step 4: Amenities

struct AmenitiesStepView: View {
    @ObservedObject var form: ListingFormModel

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Hvilke fasiliteter tilbyr du?")
                    .font(.system(size: 22, weight: .bold))

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(form.availableAmenities, id: \.rawValue) { amenity in
                        let selected = form.selectedAmenities.contains(amenity.rawValue)
                        Button {
                            if selected {
                                form.selectedAmenities.remove(amenity.rawValue)
                            } else {
                                form.selectedAmenities.insert(amenity.rawValue)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: amenity.icon)
                                    .font(.system(size: 16))
                                Text(amenity.label)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(selected ? .primary600 : .neutral600)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 8)
                            .background(selected ? Color.primary50 : Color.neutral50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: selected ? 2 : 1)
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Step 5: Extras

struct ExtrasStepView: View {
    @ObservedObject var form: ListingFormModel
    @State private var customName: String = ""
    @State private var customPrice: String = ""
    @State private var customPerNight: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Felles tillegg")
                    .font(.system(size: 22, weight: .bold))

                Text("Noe som er tilgjengelig for alle gjester, uansett hvilken plass de velger — f.eks. sauna, kajakk eller grillpakke. Plass-spesifikke tillegg (strøm, EV-lading, septik) setter du på hver enkelt plass i Lokasjon-steget.")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)

                let available = ExtraType.available(for: form.category ?? .camping, scope: .areaWide)

                if available.isEmpty {
                    Text("Ingen tilleggstjenester tilgjengelig for denne kategorien")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                } else {
                    VStack(spacing: 10) {
                        ForEach(available, id: \.rawValue) { extra in
                            let isSelected = form.selectedExtras.contains(where: { $0.id == extra.rawValue })
                            let selectedExtra = form.selectedExtras.first(where: { $0.id == extra.rawValue })

                            VStack(spacing: 0) {
                                Button {
                                    toggleExtra(extra)
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

                                        // Checkbox
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

                                // Price + message input when selected
                                if isSelected, let currentExtra = selectedExtra {
                                    Divider()
                                        .padding(.horizontal, 14)

                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 12) {
                                            Text("Pris (kr)")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.neutral600)

                                            TextField("Pris", value: Binding(
                                                get: { currentExtra.price },
                                                set: { newPrice in updateExtraPrice(extra.rawValue, price: newPrice) }
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
                                                "F.eks. Elbil-laderen har type 2-kontakt, passord TUNO123",
                                                text: Binding(
                                                    get: { currentExtra.message ?? "" },
                                                    set: { updateExtraMessage(extra.rawValue, message: $0) }
                                                ),
                                                axis: .vertical,
                                            )
                                            .textFieldStyle(.roundedBorder)
                                            .lineLimit(2...4)
                                            Text("Sendes sammen med velkomstmeldingen hvis tillegget blir booket.")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.neutral400)
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
                }

                customExtrasSection
            }
            .padding()
        }
    }

    private var customExtrasSection: some View {
        let presetIds = Set(ExtraType.allCases.map { $0.rawValue })
        let customExtras = form.selectedExtras.filter { !presetIds.contains($0.id) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Egendefinert tillegg")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 8)

            Text("Har du noe unikt du vil tilby? Gi det et navn og sett pris.")
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)

            ForEach(customExtras) { extra in
                customListingExtraCard(extra: extra)
            }

            HStack(spacing: 8) {
                TextField("Navn (f.eks. Vedfyrt badstue)", text: $customName)
                    .textFieldStyle(.roundedBorder)
                TextField("Pris", text: $customPrice)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
            }
            HStack {
                Toggle("Per natt", isOn: $customPerNight).labelsHidden()
                Text(customPerNight ? "per natt" : "engangspris")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
                Spacer()
                Button {
                    addCustomExtra()
                } label: {
                    Text("Legg til")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(canAddCustom ? Color.primary600 : Color.neutral300)
                        .clipShape(Capsule())
                }
                .disabled(!canAddCustom)
            }
        }
    }

    private var canAddCustom: Bool {
        !customName.trimmingCharacters(in: .whitespaces).isEmpty && Int(customPrice) ?? 0 > 0
    }

    private func updateExtraMessage(_ id: String, message: String) {
        guard let idx = form.selectedExtras.firstIndex(where: { $0.id == id }) else { return }
        form.selectedExtras[idx].message = message.isEmpty ? nil : message
    }

    @ViewBuilder
    private func customListingExtraCard(extra: ListingExtra) -> some View {
        let idxOpt = form.selectedExtras.firstIndex(where: { $0.id == extra.id })
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(.primary600)
                TextField("Navn", text: Binding(
                    get: { extra.name },
                    set: { newName in
                        if let i = idxOpt { form.selectedExtras[i].name = newName }
                    },
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14, weight: .medium))
                Spacer()
                Button {
                    form.selectedExtras.removeAll { $0.id == extra.id }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.7))
                }
            }

            HStack(spacing: 10) {
                TextField("Pris", value: Binding(
                    get: { extra.price },
                    set: { newPrice in
                        if let i = idxOpt { form.selectedExtras[i].price = max(0, newPrice) }
                    },
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(width: 100)
                Toggle("Per natt", isOn: Binding(
                    get: { extra.perNight },
                    set: { newPN in
                        if let i = idxOpt { form.selectedExtras[i].perNight = newPN }
                    },
                ))
                .font(.system(size: 13))
                .tint(.primary600)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Melding til gjest (valgfri)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.neutral600)
                TextField(
                    "F.eks. Badstuen er klar fra 16:00, nøkkel ligger i postkassen.",
                    text: Binding(
                        get: { extra.message ?? "" },
                        set: { newMsg in
                            if let i = idxOpt {
                                form.selectedExtras[i].message = newMsg.isEmpty ? nil : newMsg
                            }
                        },
                    ),
                    axis: .vertical,
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            }
        }
        .padding(12)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func addCustomExtra() {
        let name = customName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let price = Int(customPrice), price > 0 else { return }
        form.selectedExtras.append(ListingExtra(
            id: UUID().uuidString.lowercased(),
            name: name,
            price: price,
            perNight: customPerNight
        ))
        customName = ""
        customPrice = ""
        customPerNight = false
    }

    private func toggleExtra(_ extra: ExtraType) {
        if let index = form.selectedExtras.firstIndex(where: { $0.id == extra.rawValue }) {
            form.selectedExtras.remove(at: index)
        } else {
            form.selectedExtras.append(ListingExtra(
                id: extra.rawValue,
                name: extra.name,
                price: extra.defaultPrice,
                perNight: extra.perNight
            ))
        }
    }

    private func updateExtraPrice(_ extraId: String, price: Int) {
        if let index = form.selectedExtras.firstIndex(where: { $0.id == extraId }) {
            form.selectedExtras[index].price = max(0, price)
        }
    }
}

// MARK: - Step 6: Pricing

struct PricingStepView: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Sett pris")
                    .font(.system(size: 22, weight: .bold))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Pris (kr)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral600)
                    TextField("F.eks. 150", text: $form.price)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Prisenhet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral600)

                    HStack(spacing: 10) {
                        priceUnitButton(unit: .time, label: "Per time")
                        priceUnitButton(unit: .natt, label: "Per natt")
                    }
                }

                // Instant booking toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $form.instantBooking) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.green)
                                Text("Direktebooking")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text("Gjester kan booke umiddelbart uten å vente på godkjenning")
                                .font(.system(size: 13))
                                .foregroundStyle(.neutral500)
                        }
                    }
                    .tint(.primary600)
                }
                .padding()
                .background(Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    private func priceUnitButton(unit: PriceUnit, label: String) -> some View {
        let selected = form.priceUnit == unit
        return Button {
            form.priceUnit = unit
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(selected ? .primary600 : .neutral600)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.primary50 : Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: selected ? 2 : 1)
                )
        }
    }
}

// MARK: - Step 6: Availability

struct AvailabilityStepView: View {
    @ObservedObject var form: ListingFormModel
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    // Bruker TunoCalendar.dateKey(_:) — DateFormatter med eksplisitt timeZone
    // for å unngå off-by-one-bugs som har plaget tidligere kalender-kode.

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tilgjengelighet")
                    .font(.system(size: 22, weight: .bold))

                Text("Trykk på datoer for å blokkere eller åpne dem. Blokkerte datoer vises i rødt.")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)

                // Month navigation
                HStack {
                    Button {
                        moveMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.neutral600)
                    }

                    Spacer()
                    Text(monthFormatter.string(from: displayedMonth).capitalized)
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()

                    Button {
                        moveMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.neutral600)
                    }
                }
                .padding(.horizontal)

                // Weekday headers
                let weekdays = ["Ma", "Ti", "On", "To", "Fr", "Lo", "So"]
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.neutral500)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar grid
                let days = daysInMonth()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        if let day {
                            let dateStr = TunoCalendar.dateKey(day)
                            let isBlocked = form.blockedDates.contains(dateStr)
                            let isPast = day < calendar.startOfDay(for: Date())

                            Button {
                                guard !isPast else { return }
                                if isBlocked {
                                    form.blockedDates.remove(dateStr)
                                } else {
                                    form.blockedDates.insert(dateStr)
                                }
                            } label: {
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.system(size: 15, weight: isBlocked ? .bold : .regular))
                                    .foregroundStyle(isPast ? .neutral300 : isBlocked ? Color(hex: "#dc2626") : .neutral800)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(isBlocked ? Color(hex: "#fee2e2") : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .disabled(isPast)
                        } else {
                            Color.clear.frame(height: 38)
                        }
                    }
                }

                if !form.blockedDates.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundStyle(Color(hex: "#dc2626"))
                        Text("\(form.blockedDates.count) dato\(form.blockedDates.count == 1 ? "" : "er") blokkert")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "#dc2626"))
                    }
                }
            }
            .padding()
        }
    }

    private func moveMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func daysInMonth() -> [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }

        // Weekday of first day (Monday = 1 in our grid)
        var weekday = calendar.component(.weekday, from: firstDay)
        // Convert from Sunday=1 to Monday=1 system
        weekday = weekday == 1 ? 7 : weekday - 1

        var days: [Date?] = Array(repeating: nil, count: weekday - 1)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }
}

// MARK: - Step 8: Review

struct ReviewStepView: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Se over annonsen din")
                    .font(.system(size: 22, weight: .bold))
                Text("Kontroller at alt ser riktig ut før du publiserer")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)

                VStack(alignment: .leading, spacing: 16) {
                    // Badges
                    HStack(spacing: 8) {
                        badge(text: form.category?.displayName ?? "", color: .primary600)
                        badge(text: form.vehicleType.displayName, color: .primary500)
                        if form.instantBooking {
                            badge(text: "Direktebooking", color: .green)
                        }
                    }

                    // Images
                    if !form.imageURLs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(form.imageURLs, id: \.self) { url in
                                    AsyncImage(url: URL(string: url)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        default:
                                            Rectangle().fill(Color.neutral100)
                                        }
                                    }
                                    .frame(width: 120, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    // Title & Price
                    HStack {
                        Text(form.title)
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                        if let price = Int(form.price) {
                            Text("\(price) kr/\(form.priceUnit.displayName)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary600)
                        }
                    }

                    Text(form.description)
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral600)

                    Divider()

                    // Location
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.primary500)
                        Text([form.address, form.city, form.region].filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral600)
                    }

                    // Details
                    HStack(spacing: 16) {
                        Label("\(form.spots) plass\(form.spots == 1 ? "" : "er")", systemImage: "car.fill")
                        if let maxLen = form.maxVehicleLength {
                            Label("Maks \(maxLen)m", systemImage: "ruler")
                        }
                        Label("\(form.checkInTime)-\(form.checkOutTime)", systemImage: "clock")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)

                    // Amenities
                    if !form.selectedAmenities.isEmpty {
                        Divider()
                        FlowLayout(spacing: 6) {
                            ForEach(Array(form.selectedAmenities), id: \.self) { key in
                                if let amenity = AmenityType(rawValue: key) {
                                    HStack(spacing: 4) {
                                        Image(systemName: amenity.icon)
                                        Text(amenity.label)
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.neutral600)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.neutral100)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Extras
                    if !form.selectedExtras.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tilleggstjenester")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.neutral700)
                            ForEach(form.selectedExtras) { extra in
                                HStack(spacing: 6) {
                                    if let type = ExtraType(rawValue: extra.id) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 12))
                                    }
                                    Text(extra.name)
                                    Spacer()
                                    Text("\(extra.price) kr\(extra.perNight ? "/natt" : "")")
                                        .fontWeight(.medium)
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(.neutral600)
                            }
                        }
                    }

                    // Blocked dates
                    if !form.blockedDates.isEmpty {
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .foregroundStyle(Color(hex: "#dc2626"))
                            Text("\(form.blockedDates.count) dato\(form.blockedDates.count == 1 ? "" : "er") blokkert")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "#dc2626"))
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
            .padding()
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Flow Layout for amenity pills

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

// MARK: - Location Picker Map (interactive, with spot markers)

struct LocationPickerMapView: UIViewRepresentable {
    @Binding var lat: Double
    @Binding var lng: Double
    @Binding var spotMarkers: [SpotMarker]
    var isSpotMode: Bool
    var maxSpots: Int = 0  // 0 = ingen grense
    var updateTrigger: UUID
    var onMaxReached: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: lat, longitude: lng, zoom: 17)
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.mapType = .hybrid
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = false
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView

        // Store bindings on coordinator so delegate can use them
        context.coordinator.latBinding = $lat
        context.coordinator.lngBinding = $lng
        context.coordinator.spotMarkersBinding = $spotMarkers
        context.coordinator.isSpotMode = isSpotMode
        context.coordinator.maxSpots = maxSpots
        context.coordinator.onMaxReached = onMaxReached

        addMarkers(to: mapView, coordinator: context.coordinator)

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Keep coordinator in sync with current state
        context.coordinator.isSpotMode = isSpotMode
        context.coordinator.maxSpots = maxSpots
        context.coordinator.onMaxReached = onMaxReached

        // Check if we need to recenter (new place selected)
        if context.coordinator.lastTrigger != updateTrigger {
            context.coordinator.lastTrigger = updateTrigger
            let camera = GMSCameraPosition(latitude: lat, longitude: lng, zoom: 17)
            mapView.animate(to: camera)
        }

        // Refresh markers
        mapView.clear()
        context.coordinator.mainMarker = nil
        context.coordinator.spotMarkerMap.removeAll()
        addMarkers(to: mapView, coordinator: context.coordinator)
    }

    private func addMarkers(to mapView: GMSMapView, coordinator: Coordinator) {
        // Main location marker (draggable)
        let main = GMSMarker()
        main.position = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        main.isDraggable = true
        main.title = "Hovedposisjon"
        main.map = mapView
        coordinator.mainMarker = main

        // Spot markers (numbered blue pins)
        for (i, spot) in spotMarkers.enumerated() {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lng)
            marker.isDraggable = true
            marker.iconView = createNumberedPin(number: i + 1)
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            marker.map = mapView
            coordinator.spotMarkerMap[marker] = i
        }
    }

    private func createNumberedPin(number: Int) -> UIView {
        let size: CGFloat = 30
        let view = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.backgroundColor = UIColor(red: 0.275, green: 0.757, blue: 0.522, alpha: 1) // #46C185
        view.layer.cornerRadius = size / 2
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 3

        let label = UILabel(frame: view.bounds)
        label.text = "\(number)"
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textAlignment = .center
        view.addSubview(label)

        return view
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        weak var mapView: GMSMapView?
        var mainMarker: GMSMarker?
        var spotMarkerMap: [GMSMarker: Int] = [:]
        var lastTrigger: UUID?

        // Updated by updateUIView each render
        nonisolated(unsafe) var isSpotMode = false
        nonisolated(unsafe) var maxSpots = 0
        nonisolated(unsafe) var latBinding: Binding<Double>?
        nonisolated(unsafe) var lngBinding: Binding<Double>?
        nonisolated(unsafe) var spotMarkersBinding: Binding<[SpotMarker]>?
        nonisolated(unsafe) var onMaxReached: (() -> Void)?

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            if isSpotMode {
                let count = spotMarkersBinding?.wrappedValue.count ?? 0
                if maxSpots > 0 && count >= maxSpots {
                    onMaxReached?()
                    return
                }
                let newSpot = SpotMarker(
                    id: UUID().uuidString.lowercased(),
                    lat: coordinate.latitude,
                    lng: coordinate.longitude,
                    label: "\(count + 1)",
                    price: nil,
                    extras: nil
                )
                spotMarkersBinding?.wrappedValue.append(newSpot)
                if maxSpots > 0 && count + 1 >= maxSpots {
                    onMaxReached?()
                }
            } else {
                latBinding?.wrappedValue = coordinate.latitude
                lngBinding?.wrappedValue = coordinate.longitude
            }
        }

        func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker) {
            if marker === mainMarker {
                latBinding?.wrappedValue = marker.position.latitude
                lngBinding?.wrappedValue = marker.position.longitude
            } else if let index = spotMarkerMap[marker] {
                guard let binding = spotMarkersBinding, index < binding.wrappedValue.count else { return }
                var existing = binding.wrappedValue[index]
                binding.wrappedValue[index] = SpotMarker(
                    id: existing.id ?? UUID().uuidString.lowercased(),
                    lat: marker.position.latitude,
                    lng: marker.position.longitude,
                    label: existing.label,
                    price: existing.price,
                    extras: existing.extras
                )
            }
        }
    }
}

// MARK: - Blokkerte datoer per plass

struct SpotBlockedDatesSection: View {
    let spotId: String
    @Binding var blockedDates: [String]
    @State private var expanded = false
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    // Bruker TunoCalendar.dateKey(_:) for konsistens og timezone-safety.
    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                    Text("Blokkerte datoer")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral700)
                    if !blockedDates.isEmpty {
                        Text("(\(blockedDates.count))")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#dc2626"))
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral400)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                HStack {
                    Button { moveMonth(-1) } label: {
                        Image(systemName: "chevron.left").foregroundStyle(.neutral600)
                    }
                    Spacer()
                    Text(monthFormatter.string(from: displayedMonth).capitalized)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button { moveMonth(1) } label: {
                        Image(systemName: "chevron.right").foregroundStyle(.neutral600)
                    }
                }

                let weekdays = ["Ma", "Ti", "On", "To", "Fr", "Lo", "So"]
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.neutral500)
                            .frame(maxWidth: .infinity)
                    }
                }

                let days = daysInMonth()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day {
                            let dateStr = TunoCalendar.dateKey(day)
                            let isBlocked = blockedDates.contains(dateStr)
                            let isPast = day < calendar.startOfDay(for: Date())
                            Button {
                                guard !isPast else { return }
                                if isBlocked {
                                    blockedDates.removeAll { $0 == dateStr }
                                } else {
                                    blockedDates.append(dateStr)
                                }
                            } label: {
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.system(size: 12, weight: isBlocked ? .bold : .regular))
                                    .foregroundStyle(isPast ? Color.neutral300 : isBlocked ? Color(hex: "#dc2626") : Color.neutral800)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 30)
                                    .background(isBlocked ? Color(hex: "#fee2e2") : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .disabled(isPast)
                        } else {
                            Color.clear.frame(height: 30)
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func moveMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func daysInMonth() -> [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }
        var weekday = calendar.component(.weekday, from: firstDay)
        weekday = weekday == 1 ? 7 : weekday - 1
        var days: [Date?] = Array(repeating: nil, count: weekday - 1)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }
}

// MARK: - SpotEditor (inline — lives here fordi Xcode-target ikke auto-inkluderer nye filer)

struct IndexWrapper: Identifiable, Hashable {
    let id: Int
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct SpotEditorSheet: View {
    @Binding var spot: SpotMarker
    let category: ListingCategory
    let defaultPrice: Int?
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var priceText: String = ""
    @State private var extras: [ListingExtra] = []
    @State private var customName: String = ""
    @State private var customPrice: String = ""
    @State private var customPerNight: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    spotEditorField("Navn / label") {
                        TextField("F.eks. Plass 1", text: $label)
                            .textFieldStyle(.roundedBorder)
                    }

                    spotEditorField("Pris per natt (valgfritt)") {
                        HStack(spacing: 8) {
                            TextField(defaultPriceHint, text: $priceText)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                            Text("kr")
                                .font(.system(size: 14))
                                .foregroundStyle(.neutral500)
                        }
                        Text("La stå tomt for å bruke annonsens standardpris.")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral500)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tilgjengelig på denne plassen")
                            .font(.system(size: 15, weight: .semibold))

                        ForEach(ExtraType.available(for: category), id: \.rawValue) { preset in
                            spotEditorExtraToggleRow(preset)
                        }

                        spotEditorCustomExtrasSection
                    }
                }
                .padding()
            }
            .navigationTitle("Rediger plass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lagre") {
                        commit()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private var defaultPriceHint: String {
        if let dp = defaultPrice { return "\(dp) (standard)" }
        return "F.eks. 200"
    }

    @ViewBuilder
    private func spotEditorField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.neutral600)
            content()
        }
    }

    private func spotEditorExtraToggleRow(_ preset: ExtraType) -> some View {
        let isSelected = extras.contains(where: { $0.id == preset.rawValue })

        return VStack(spacing: 0) {
            Button {
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
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: preset.icon)
                        .foregroundStyle(isSelected ? Color.primary600 : Color.neutral400)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name).font(.system(size: 14, weight: isSelected ? .medium : .regular))
                        Text(preset.perNight ? "per natt" : "engangspris")
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral400)
                    }
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.primary600 : Color.neutral300, lineWidth: 2)
                            .frame(width: 20, height: 20)
                        if isSelected {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary600).frame(width: 20, height: 20)
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            if isSelected, let currentIdx = extras.firstIndex(where: { $0.id == preset.rawValue }) {
                Divider().padding(.horizontal, 12)
                HStack(spacing: 10) {
                    Text("Pris").font(.system(size: 13)).foregroundStyle(.neutral600)
                    TextField("", value: Binding(
                        get: { extras[currentIdx].price },
                        set: { newVal in extras[currentIdx].price = max(0, newVal) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                    Text(preset.perNight ? "kr/natt" : "kr")
                        .font(.system(size: 12)).foregroundStyle(.neutral400)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(isSelected ? Color.primary50 : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: isSelected ? 2 : 1))
    }

    private var spotEditorCustomExtrasSection: some View {
        let presetIds = Set(ExtraType.allCases.map { $0.rawValue })
        let customExtras = extras.filter { !presetIds.contains($0.id) }

        return VStack(alignment: .leading, spacing: 8) {
            if !customExtras.isEmpty {
                ForEach(customExtras) { extra in
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles").foregroundStyle(.primary600)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(extra.name).font(.system(size: 13, weight: .medium))
                            Text("\(extra.price) \(extra.perNight ? "kr/natt" : "kr")")
                                .font(.system(size: 11)).foregroundStyle(.neutral500)
                        }
                        Spacer()
                        Button {
                            extras.removeAll { $0.id == extra.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.neutral400)
                        }
                    }
                    .padding(10)
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            HStack(spacing: 6) {
                TextField("Egendefinert navn", text: $customName)
                    .textFieldStyle(.roundedBorder)
                TextField("Pris", text: $customPrice)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 70)
            }
            HStack {
                Toggle("Per natt", isOn: $customPerNight).labelsHidden()
                Text(customPerNight ? "per natt" : "engangspris")
                    .font(.system(size: 12)).foregroundStyle(.neutral500)
                Spacer()
                Button {
                    let name = customName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, let price = Int(customPrice), price > 0 else { return }
                    extras.append(ListingExtra(
                        id: UUID().uuidString.lowercased(),
                        name: name, price: price, perNight: customPerNight
                    ))
                    customName = ""
                    customPrice = ""
                    customPerNight = false
                } label: {
                    Text("Legg til")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.primary600).clipShape(Capsule())
                }
            }
        }
    }

    private func populate() {
        label = spot.label ?? ""
        priceText = spot.price.map { "\($0)" } ?? ""
        extras = spot.extras ?? []
    }

    private func commit() {
        spot.label = label.isEmpty ? nil : label
        spot.price = Int(priceText)
        spot.extras = extras.isEmpty ? nil : extras
        if spot.id == nil {
            spot.id = UUID().uuidString.lowercased()
        }
    }
}
