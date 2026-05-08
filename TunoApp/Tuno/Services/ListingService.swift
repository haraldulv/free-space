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
    /// Nær deg — sortert etter avstand fra brukerens lokasjon. Tom hvis ingen lokasjon.
    @Published var nearbyListings: [Listing] = []
    /// Ledige nå — random utvalg av listings som ikke er blokkert i dag.
    /// I motsetning til availableTodayListings krever ikke instant_booking.
    @Published var availableNowListings: [Listing] = []
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

    func fetchHomeListings(
        category: ListingCategory? = nil,
        vehicleType: VehicleType? = nil,
        userLat: Double? = nil,
        userLng: Double? = nil
    ) async {
        isLoading = true

        // Hent flere listings (50) når vi har brukerlokasjon — vil sortere på avstand.
        let limit = userLat != nil ? 50 : 40
        let all = await fetchRealListings(category: category, vehicleType: vehicleType, limit: limit)

        // "Populære" = score-sortert: rating × reviews + tag-bonus + instant-bonus.
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
        availableTodayListings = all.filter { listing in
            guard listing.instantBooking == true else { return false }
            let blockedSet = Set(listing.blockedDates ?? [])
            return !blockedSet.isFullDayBlocked(todayIso)
        }

        // "Nær deg" — sortert etter avstand fra brukerens lokasjon
        if let userLat, let userLng {
            nearbyListings = all.compactMap { listing -> (Listing, Double)? in
                guard let lat = listing.lat, let lng = listing.lng else { return nil }
                let d = haversineDistanceKm(lat1: userLat, lng1: userLng, lat2: lat, lng2: lng)
                return (listing, d)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(12)
            .map { $0.0 }
        } else {
            nearbyListings = []
        }

        // "Ledige nå" — listings som ikke er blokkert i dag, shuffled for variasjon
        // mot "Nær deg" (som er sortert etter avstand). Ekskluderer de 6 nærmeste
        // fra Nær deg så de to seksjonene ikke overlapper.
        let availableFiltered = all.filter { listing in
            let blockedSet = Set(listing.blockedDates ?? [])
            return !blockedSet.isFullDayBlocked(todayIso)
        }
        let nearbyTopIds = Set(nearbyListings.prefix(6).map { $0.id })
        availableNowListings = Array(
            availableFiltered
                .filter { !nearbyTopIds.contains($0.id) }
                .shuffled()
                .prefix(12)
        )

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
        instantOnly: Bool = false,
        flexibilityDays: Int = 0,
        openingHours: OpeningHoursFilter = .any
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

            // Fetch limit kalibrert mot 410-listing-staging:
            // - Geo-søk: 250 dekker rundt-omkring i Norge med god margin uten å overlaste klient
            // - Tom-query: 50 (forsiden / "alle"-søk)
            let fetchLimit = lat != nil ? 250 : 50

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
                let nights = nightsBetween(checkIn: checkIn, checkOut: checkOut)
                let totalDays = max(nights, 1) + (nights == 0 ? 0 : 0) // 7-7 = 1 dag, 7-13 = 7 dager (begge inkl)
                let bookedDays = nights + 1 // antall dager bruker leier (begge endepunkter inkludert)

                listings = listings.filter { listing in
                    // 1) Min-stay sjekk: hvis annonsen krever lenger leie enn det
                    // brukeren ønsker, ekskluder. Eks: månedsannonse (min 30) treffer
                    // ikke på 7-dagers søk.
                    if let minStay = listing.minStayDays, minStay > 0 {
                        if bookedDays < minStay { return false }
                    }

                    // 2) Blocked-dates sjekk
                    guard let blocked = listing.blockedDates, !blocked.isEmpty else { return true }
                    let blockedSet = Set(blocked)
                    let candidateStarts = shiftedStartDates(checkIn: checkIn, flexibilityDays: flexibilityDays)
                    return candidateStarts.contains { startISO in
                        let dates = dateRange(fromISO: startISO, nights: nights)
                        return dates.allSatisfy { !blockedSet.isFullDayBlocked($0) }
                    }
                }
                _ = totalDays // avoid unused-warning hvis vi bruker bookedDays direkte over
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

            // Filter by opening hours
            switch openingHours {
            case .any:
                break
            case .alwaysOpen:
                listings = listings.filter { $0.openingHours == nil }
            case .limitedHours:
                listings = listings.filter { OpeningHoursService.hasLimitedHours($0.openingHours) }
            }

            // Vi auto-filtrerer IKKE på åpningstid — gjest kan justere
            // pickup-dag, eller vert kan ha nøkkel/kode for tilgang utenfor
            // åpningstid. Åpningstiden vises på søkekortet ("9-17"), og
            // gjest får eksplisitt kontroll via 3-segments-filteret
            // (Alle / Døgnåpent / Med åpningstid).

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

/// Avstand mellom to koordinater i kilometer. Public så ListingCard og
/// andre views kan vise "X km fra deg" uten å duplisere matten.
func haversineDistanceKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
    haversineDistance(lat1: lat1, lng1: lng1, lat2: lat2, lng2: lng2)
}

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

/// Antall netter mellom to datoer (checkOut - checkIn).
private func nightsBetween(checkIn: String, checkOut: String) -> Int {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    guard let i = f.date(from: checkIn), let o = f.date(from: checkOut) else { return 0 }
    return Calendar.current.dateComponents([.day], from: i, to: o).day ?? 0
}

/// Genererer alle kandidat-startdatoer i [checkIn-flex, checkIn+flex].
/// Eksakt søk (flex=0) returnerer kun original-checkIn.
private func shiftedStartDates(checkIn: String, flexibilityDays: Int) -> [String] {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    guard let base = f.date(from: checkIn) else { return [checkIn] }
    let cal = Calendar.current
    var dates: [String] = []
    for offset in -flexibilityDays...flexibilityDays {
        if let shifted = cal.date(byAdding: .day, value: offset, to: base) {
            dates.append(f.string(from: shifted))
        }
    }
    return dates
}

/// Genererer dato-strenger fra en startdato over N netter (start, start+1, …, start+N-1).
/// Den første natten er checkIn; checkOut er ikke inkludert.
private func dateRange(fromISO start: String, nights: Int) -> [String] {
    guard nights > 0 else { return [start] }
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    guard let base = f.date(from: start) else { return [start] }
    let cal = Calendar.current
    var out: [String] = []
    for offset in 0..<nights {
        if let shifted = cal.date(byAdding: .day, value: offset, to: base) {
            out.append(f.string(from: shifted))
        }
    }
    return out
}
