import Foundation

@MainActor
final class ListingService: ObservableObject {
    @Published var popularListings: [Listing] = []
    @Published var featuredListings: [Listing] = []
    @Published var availableTodayListings: [Listing] = []
    @Published var searchResults: [Listing] = []
    @Published var isLoading = false

    func fetchByTag(_ tag: String, vehicleType: VehicleType? = nil, limit: Int = 12) async -> [Listing] {
        do {
            var request = supabase
                .from("listings")
                .select()
                .or("is_active.eq.true,is_active.is.null")
                .contains("tags", value: [tag])

            if let vehicleType {
                switch vehicleType {
                case .car:
                    request = request.in("vehicle_type", values: ["car", "campervan", "motorhome"])
                case .campervan:
                    request = request.in("vehicle_type", values: ["campervan", "motorhome"])
                case .motorhome:
                    request = request.in("vehicle_type", values: ["motorhome"])
                }
            }

            let listings: [Listing] = try await request
                .limit(limit)
                .execute()
                .value
            return listings
        } catch {
            print("Failed to fetch listings by tag \(tag): \(error)")
            return []
        }
    }

    func fetchRecent(limit: Int = 12) async -> [Listing] {
        do {
            let response = try await supabase
                .from("listings")
                .select()
                .or("is_active.eq.true,is_active.is.null")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()

            print("📡 Supabase response status: \(response.status)")
            print("📡 Supabase response data size: \(response.data.count) bytes")

            let listings: [Listing] = try JSONDecoder().decode([Listing].self, from: response.data)
            print("✅ Decoded \(listings.count) listings")
            return listings
        } catch let decodingError as DecodingError {
            print("❌ Decoding error: \(decodingError)")
            // Try to print raw JSON to see what we got
            if let raw = try? await supabase.from("listings").select("id, title").eq("is_active", value: true).limit(3).execute() {
                print("📋 Raw sample: \(String(data: raw.data, encoding: .utf8) ?? "nil")")
            }
            return []
        } catch {
            print("❌ Failed to fetch recent listings: \(error)")
            return []
        }
    }

    func fetchHomeListings(vehicleType: VehicleType? = nil) async {
        isLoading = true

        async let popular = fetchByTag("popular", vehicleType: vehicleType, limit: 20)
        async let featured = fetchByTag("featured", vehicleType: vehicleType, limit: 20)
        async let available = fetchByTag("available_today", vehicleType: vehicleType, limit: 20)

        popularListings = await popular
        featuredListings = await featured
        availableTodayListings = await available

        isLoading = false
    }

    func search(
        query: String? = nil,
        category: ListingCategory? = nil,
        vehicleType: VehicleType? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        radiusKm: Double = 20,
        checkIn: String? = nil,
        checkOut: String? = nil,
        amenities: Set<AmenityType>? = nil,
        instantOnly: Bool = false
    ) async {
        isLoading = true
        do {
            var request = supabase
                .from("listings")
                .select()
                .or("is_active.eq.true,is_active.is.null")

            if let category {
                request = request.eq("category", value: category.rawValue)
            }
            if let vehicleType {
                // Vehicle hierarchy: motorhome spots accept all, campervan accepts campervan+car
                switch vehicleType {
                case .car:
                    request = request.in("vehicle_type", values: ["car", "campervan", "motorhome"])
                case .campervan:
                    request = request.in("vehicle_type", values: ["campervan", "motorhome"])
                case .motorhome:
                    request = request.in("vehicle_type", values: ["motorhome"])
                }
            }
            // Only text-search if no coordinates (place search uses geo filter instead)
            if lat == nil, let query, !query.isEmpty {
                request = request.or("title.ilike.%\(query)%,city.ilike.%\(query)%,region.ilike.%\(query)%,address.ilike.%\(query)%")
            }

            // Fetch more when doing geo-search to ensure coverage
            let fetchLimit = lat != nil ? 500 : 50

            var listings: [Listing] = try await request
                .limit(fetchLimit)
                .execute()
                .value

            // Client-side Haversine distance filter if coordinates provided
            if let lat, let lng {
                listings = listings.filter { listing in
                    guard let lLat = listing.lat, let lLng = listing.lng else { return false }
                    let distance = haversineDistance(lat1: lat, lng1: lng, lat2: lLat, lng2: lLng)
                    return distance <= radiusKm
                }.sorted { a, b in
                    let distA = haversineDistance(lat1: lat, lng1: lng, lat2: a.lat ?? 0, lng2: a.lng ?? 0)
                    let distB = haversineDistance(lat1: lat, lng1: lng, lat2: b.lat ?? 0, lng2: b.lng ?? 0)
                    return distA < distB
                }
            }

            // Filter by blocked dates if check-in/check-out provided
            if let checkIn, let checkOut {
                listings = listings.filter { listing in
                    guard let blocked = listing.blockedDates, !blocked.isEmpty else { return true }
                    let blockedSet = Set(blocked)
                    // Check if any date in the range is blocked
                    let dates = dateRange(from: checkIn, to: checkOut)
                    return dates.allSatisfy { !blockedSet.contains($0) }
                }
            }

            // Filter by amenities — listing must have ALL selected amenities
            if let amenities, !amenities.isEmpty {
                let requiredKeys = amenities.map { $0.rawValue }
                listings = listings.filter { listing in
                    guard let listingAmenities = listing.amenities else { return false }
                    return requiredKeys.allSatisfy { listingAmenities.contains($0) }
                }
            }

            // Filter by instant booking
            if instantOnly {
                listings = listings.filter { $0.instantBooking == true }
            }

            searchResults = listings
        } catch {
            print("Search failed: \(error)")
            searchResults = []
        }
        isLoading = false
    }

    func fetchListing(id: String) async -> Listing? {
        do {
            let listing: Listing = try await supabase
                .from("listings")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            return listing
        } catch {
            print("Failed to fetch listing \(id): \(error)")
            return nil
        }
    }
}

// MARK: - Helpers

private func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
    let R = 6371.0 // Earth radius in km
    let dLat = (lat2 - lat1) * .pi / 180
    let dLng = (lng2 - lng1) * .pi / 180
    let a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
        sin(dLng / 2) * sin(dLng / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c
}

private func dateRange(from start: String, to end: String) -> [String] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let startDate = formatter.date(from: start),
          let endDate = formatter.date(from: end) else { return [] }

    var dates: [String] = []
    var current = startDate
    while current <= endDate {
        dates.append(formatter.string(from: current))
        current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
    }
    return dates
}
