import Foundation

@MainActor
final class ListingService: ObservableObject {
    @Published var popularListings: [Listing] = []
    @Published var featuredListings: [Listing] = []
    @Published var availableTodayListings: [Listing] = []
    @Published var searchResults: [Listing] = []
    @Published var isLoading = false

    func fetchByTag(_ tag: String, limit: Int = 12) async -> [Listing] {
        do {
            let listings: [Listing] = try await supabase
                .from("listings")
                .select()
                .eq("is_active", value: true)
                .contains("tags", value: [tag])
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
                .eq("is_active", value: true)
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

    func fetchHomeListings() async {
        isLoading = true

        // Try tags first
        async let popular = fetchByTag("popular", limit: 8)
        async let featured = fetchByTag("featured", limit: 8)
        async let available = fetchByTag("available_today", limit: 8)
        popularListings = await popular
        featuredListings = await featured
        availableTodayListings = await available

        // Fallback: if no tagged listings, show recent ones
        if popularListings.isEmpty && featuredListings.isEmpty {
            popularListings = await fetchRecent(limit: 8)
        }

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
        checkOut: String? = nil
    ) async {
        isLoading = true
        do {
            var request = supabase
                .from("listings")
                .select()
                .eq("is_active", value: true)

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
            if let query, !query.isEmpty {
                request = request.or("title.ilike.%\(query)%,city.ilike.%\(query)%,region.ilike.%\(query)%,address.ilike.%\(query)%")
            }

            var listings: [Listing] = try await request
                .limit(50)
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
