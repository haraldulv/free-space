import SwiftUI
import PhotosUI
import GoogleMaps

struct CreateListingView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var form = ListingFormModel()
    @StateObject private var placesService = PlacesService()
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccess = false

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
                PricingStepView(form: form).tag(5)
                AvailabilityStepView(form: form).tag(6)
                ReviewStepView(form: form).tag(7)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: form.currentStep)

            // Navigation buttons
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
        }
        .navigationTitle("Ny annonse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Avbryt") { dismiss() }
            }
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
                try await supabase
                    .from("listings")
                    .insert(input)
                    .execute()

                // Reload profile to update isHost if needed
                await authManager.loadProfile()
                form.isSubmitting = false
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
                        category: .parking,
                        icon: "car.fill",
                        title: "Parkering"
                    )
                    categoryCard(
                        category: .camping,
                        icon: "tent.fill",
                        title: "Camping / Bobil"
                    )
                }

                // Vehicle type
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hvilken kjøretøytype passer?")
                        .font(.system(size: 17, weight: .semibold))

                    HStack(spacing: 10) {
                        ForEach([VehicleType.motorhome, .campervan, .car], id: \.self) { type in
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
                    TextEditor(text: $form.description)
                        .frame(minHeight: 100)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200))
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
                        TextField("15:00", text: $form.checkInTime)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Utsjekk")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.neutral600)
                        TextField("11:00", text: $form.checkOutTime)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
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

                // Map
                if form.lat != 0 || form.lng != 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        // Spot mode toggle
                        HStack {
                            Button {
                                isSpotMode.toggle()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse")
                                    Text("Marker plasser")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(isSpotMode ? .white : .primary600)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSpotMode ? Color.primary600 : Color.primary50)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.primary600, lineWidth: 1))
                            }

                            Spacer()

                            if isSpotMode {
                                Text("Trykk på kartet for å plassere")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.neutral500)
                            }
                        }

                        LocationPickerMapView(
                            lat: $form.lat,
                            lng: $form.lng,
                            spotMarkers: $form.spotMarkers,
                            isSpotMode: isSpotMode,
                            updateTrigger: mapUpdateTrigger
                        )
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Spot markers list
                        if !form.spotMarkers.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { index, _ in
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color.primary600)
                                                .frame(width: 22, height: 22)
                                                .overlay(
                                                    Text("\(index + 1)")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(.white)
                                                )
                                            Text("Plass \(index + 1)")
                                                .font(.system(size: 13, weight: .medium))
                                            Button {
                                                form.spotMarkers.remove(at: index)
                                                mapUpdateTrigger = UUID()
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(.neutral400)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.neutral50)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.neutral200))
                                    }
                                }
                            }
                        }
                    }
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

                if form.isUploadingImages {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Laster opp bilder...")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral500)
                    }
                }

                // Image grid
                if !form.imageURLs.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(Array(form.imageURLs.enumerated()), id: \.offset) { index, url in
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

                                // Remove button
                                Button {
                                    form.imageURLs.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                }
                                .padding(4)

                                // First image label
                                if index == 0 {
                                    Text("Forsidebilde")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                        .padding(4)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func uploadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        form.isUploadingImages = true

        Task {
            guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
                form.isUploadingImages = false
                return
            }

            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

                let fileName = "\(userId)/\(UUID().uuidString.lowercased()).jpg"
                do {
                    try await supabase.storage
                        .from("listing-images")
                        .upload(fileName, data: data, options: .init(contentType: "image/jpeg"))

                    let publicURL = try supabase.storage
                        .from("listing-images")
                        .getPublicURL(path: fileName)

                    form.imageURLs.append(publicURL.absoluteString)
                } catch {
                    print("Image upload failed: \(error)")
                }
            }

            form.selectedPhotos = []
            form.isUploadingImages = false
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

// MARK: - Step 5: Pricing

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
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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
                            let dateStr = dateFormatter.string(from: day)
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

// MARK: - Step 7: Review

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
    var updateTrigger: UUID

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

        addMarkers(to: mapView, coordinator: context.coordinator)

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Keep coordinator in sync with current state
        context.coordinator.isSpotMode = isSpotMode

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
        view.backgroundColor = UIColor(red: 0.102, green: 0.310, blue: 0.839, alpha: 1)
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
        nonisolated(unsafe) var latBinding: Binding<Double>?
        nonisolated(unsafe) var lngBinding: Binding<Double>?
        nonisolated(unsafe) var spotMarkersBinding: Binding<[SpotMarker]>?

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            if isSpotMode {
                let count = spotMarkersBinding?.wrappedValue.count ?? 0
                let newSpot = SpotMarker(
                    lat: coordinate.latitude,
                    lng: coordinate.longitude,
                    label: "\(count + 1)"
                )
                spotMarkersBinding?.wrappedValue.append(newSpot)
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
                binding.wrappedValue[index] = SpotMarker(
                    lat: marker.position.latitude,
                    lng: marker.position.longitude,
                    label: binding.wrappedValue[index].label
                )
            }
        }
    }
}
