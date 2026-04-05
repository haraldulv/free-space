import SwiftUI
import PhotosUI

struct EditListingView: View {
    let listing: Listing
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
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var region: String = ""
    @State private var lat: Double = 0
    @State private var lng: Double = 0
    @State private var spotMarkers: [SpotMarker] = []
    @State private var isSpotMode = false
    @State private var mapUpdateTrigger = UUID()
    @State private var price: String = ""
    @State private var priceUnit: PriceUnit = .natt
    @State private var instantBooking: Bool = false
    @State private var selectedAmenities: Set<String> = []
    @State private var imageURLs: [String] = []
    @State private var blockedDates: Set<String> = []
    @State private var hideExactLocation: Bool = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isUploadingImages = false

    private let tabs = ["Detaljer", "Lokasjon", "Bilder", "Fasiliteter", "Pris", "Tilgjengelighet"]

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
                pricingTab.tag(4)
                availabilityTab.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Save button
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
        .navigationTitle("Rediger annonse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Avbryt") { dismiss() }
            }
        }
        .onAppear { populateFields() }
    }

    // MARK: - Tab Views

    private var detailsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                field("Tittel") {
                    TextField("Tittel", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                field("Beskrivelse") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200))
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
                        TextField("15:00", text: $checkInTime)
                            .textFieldStyle(.roundedBorder)
                    }
                    field("Utsjekk") {
                        TextField("11:00", text: $checkOutTime)
                            .textFieldStyle(.roundedBorder)
                    }
                }
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

                // Map with spot markers
                if lat != 0 || lng != 0 {
                    VStack(alignment: .leading, spacing: 10) {
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
                                Text("Trykk på kartet")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.neutral500)
                            }
                        }

                        LocationPickerMapView(
                            lat: $lat,
                            lng: $lng,
                            spotMarkers: $spotMarkers,
                            isSpotMode: isSpotMode,
                            updateTrigger: mapUpdateTrigger
                        )
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if !spotMarkers.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(spotMarkers.enumerated()), id: \.offset) { index, _ in
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
                                                spotMarkers.remove(at: index)
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

                if isUploadingImages {
                    HStack { ProgressView(); Text("Laster opp...").font(.system(size: 14)).foregroundStyle(.neutral500) }
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
                let spotMarkersArray = spotMarkers.map { marker -> [String: Any] in
                    var obj: [String: Any] = ["lat": marker.lat, "lng": marker.lng]
                    if let label = marker.label { obj["label"] = label }
                    return obj
                }

                let updates: [String: Any] = [
                    "title": title,
                    "description": description,
                    "spots": spots,
                    "check_in_time": checkInTime,
                    "check_out_time": checkOutTime,
                    "address": address,
                    "city": city,
                    "region": region,
                    "lat": lat,
                    "lng": lng,
                    "price": Int(price) ?? 0,
                    "price_unit": priceUnit.rawValue,
                    "instant_booking": instantBooking,
                    "amenities": Array(selectedAmenities),
                    "images": imageURLs,
                    "blocked_dates": Array(blockedDates).sorted(),
                    "hide_exact_location": hideExactLocation,
                    "spot_markers": spotMarkersArray,
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: updates)
                try await supabase
                    .from("listings")
                    .update(jsonData)
                    .eq("id", value: listing.id)
                    .execute()

                if let maxLen = maxVehicleLength, listing.category == .camping {
                    try await supabase
                        .from("listings")
                        .update(["max_vehicle_length": maxLen])
                        .eq("id", value: listing.id)
                        .execute()
                }

                isSaving = false
                savedMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    savedMessage = false
                }
            } catch {
                self.error = "Kunne ikke lagre: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }

    private func uploadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isUploadingImages = true

        Task {
            guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
                isUploadingImages = false
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
                    imageURLs.append(publicURL.absoluteString)
                } catch {
                    print("Image upload failed: \(error)")
                }
            }

            selectedPhotos = []
            isUploadingImages = false
        }
    }
}
