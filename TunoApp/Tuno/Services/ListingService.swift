import Foundation

struct HostStats: Equatable {
    var rating: Double = 0
    var reviewCount: Int = 0
    var listingsCount: Int = 0
    var joinedYear: Int = 0
}

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
                .not("host_id", operator: .is, value: "null")  // Ekskluder seed-data (har ingen host_id)
                .contains("tags", value: [tag])

            if let vehicleType {
                request = request.in("vehicle_type", values: vehicleType.acceptingListingTypes.map { $0.rawValue })
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

    /// Henter ekte bruker-annonser (har host_id satt) — brukes på forsiden
    /// i stedet for (eller som supplement til) tag-baserte lister. Nye
    /// opprettede annonser vises selv uten 'popular'/'featured'-tags.
    func fetchRealListings(category: ListingCategory? = nil, vehicleType: VehicleType? = nil, limit: Int = 20) async -> [Listing] {
        do {
            var request = supabase
                .from("listings")
                .select()
                .or("is_active.eq.true,is_active.is.null")
                .not("host_id", operator: .is, value: "null")

            if let category {
                request = request.eq("category", value: category.rawValue)
            }
            if let vehicleType {
                request = request.in("vehicle_type", values: vehicleType.acceptingListingTypes.map { $0.rawValue })
            }

            let listings: [Listing] = try await request
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return listings
        } catch {
            print("Failed to fetch real listings: \(error)")
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

    func fetchHomeListings(category: ListingCategory? = nil, vehicleType: VehicleType? = nil) async {
        isLoading = true

        // Viser kun ekte bruker-annonser. Seeds (uten host_id) filtreres ut.
        let all = await fetchRealListings(category: category, vehicleType: vehicleType, limit: 40)

        // "Populære" = score-sortert: rating × reviews + tag-bonus + instant-bonus.
        // Ingen hard reviewCount > 0 filter, ellers blir seksjonen ofte tom mens
        // vi bygger opp kritisk masse. Begrens til 12 for å unngå overlapp med "Nye".
        popularListings = Array(all.sorted { Self.popularityScore($0) > Self.popularityScore($1) }.prefix(12))
        // "Nye" = alle nyeste, som er standard rekkefølge
        featuredListings = all
        // "Tilgjengelig i dag" = direktebestilling + ikke blokkert i dag
        let todayIso: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
            return f.string(from: Date())
        }()
        // En listing teller som "tilgjengelig i dag" dersom dagens dato ikke er BLOKKERT SOM HELE DAGEN.
        // Time-blokker (yyyy-MM-dd HH) på parkering teller ikke — gjest kan fortsatt booke andre timer.
        availableTodayListings = all.filter { listing in
            guard listing.instantBooking == true else { return false }
            let blockedSet = Set(listing.blockedDates ?? [])
            return !blockedSet.isFullDayBlocked(todayIso)
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
                request = request.in("vehicle_type", values: vehicleType.acceptingListingTypes.map { $0.rawValue })
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

            // Filter by blocked dates if check-in/check-out provided.
            // For parkering: kun HELE-DAG-blokker ekskluderer — time-blokker beholdes
            // siden gjest fortsatt kan booke andre timer. Eksakt time-validering skjer i booking-flow.
            if let checkIn, let checkOut {
                listings = listings.filter { listing in
                    guard let blocked = listing.blockedDates, !blocked.isEmpty else { return true }
                    let blockedSet = Set(blocked)
                    let dates = dateRange(from: checkIn, to: checkOut)
                    return dates.allSatisfy { !blockedSet.isFullDayBlocked($0) }
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

    /// Aggregert host-stats for bruk i "Møt verten"-kort på annonsesiden.
    /// Henter rating + review_count fra profiles (som har aggregert-triggere)
    /// og antall aktive annonser via COUNT. Brukes i stedet for de upålitelige
    /// `host_*`-kolonnene i listings-tabellen.
    func fetchHostStats(hostId: String) async -> HostStats {
        var stats = HostStats()
        do {
            struct ProfileRow: Codable {
                let rating: Double?
                let reviewCount: Int?
                let joinedYear: Int?
                enum CodingKeys: String, CodingKey {
                    case rating
                    case reviewCount = "review_count"
                    case joinedYear = "joined_year"
                }
            }
            let rows: [ProfileRow] = try await supabase
                .from("profiles")
                .select("rating, review_count, joined_year")
                .eq("id", value: hostId)
                .limit(1)
                .execute()
                .value
            if let p = rows.first {
                stats.rating = p.rating ?? 0
                stats.reviewCount = p.reviewCount ?? 0
                stats.joinedYear = p.joinedYear ?? 0
            }
        } catch {
            print("fetchHostStats profile error: \(error)")
        }
        do {
            let response = try await supabase
                .from("listings")
                .select("id", head: true, count: .exact)
                .eq("host_id", value: hostId)
                .or("is_active.eq.true,is_active.is.null")
                .execute()
            stats.listingsCount = response.count ?? 0
        } catch {
            print("fetchHostStats listings-count error: \(error)")
        }
        return stats
    }

    /// Score for "Populære nå"-sortering. Kombinerer rating, reviews,
    /// kuraterte tags og instant booking. Annonser med reelle signaler
    /// havner topp, nye annonser faller til bunn men vises fortsatt.
    static func popularityScore(_ l: Listing) -> Double {
        var score = 0.0
        let reviews = Double(l.reviewCount ?? 0)
        score += (l.rating ?? 0) * reviews * 10
        score += reviews * 5
        let tags = l.tags ?? []
        if tags.contains("popular") { score += 20 }
        if tags.contains("featured") { score += 10 }
        if tags.contains("available_today") { score += 4 }
        if l.instantBooking == true { score += 3 }
        score += Double(min(l.images?.count ?? 0, 5))
        return score
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
