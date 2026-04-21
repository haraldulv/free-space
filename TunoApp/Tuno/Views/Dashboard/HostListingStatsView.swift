import SwiftUI

/// Drill-down stats for én av host sine annonser. Speiler web-versjonen
/// /dashboard/annonse/[id] med stats-banner, plass-grid og kommende bookinger.
struct HostListingStatsView: View {
    let listing: Listing
    @State private var bookings: [Booking] = []
    @State private var isLoading = true
    @State private var stats30 = ListingStatsSnapshot.zero
    @State private var stats90 = ListingStatsSnapshot.zero
    @State private var pricingRules: [PricingService.Rule] = []
    @State private var showPricingEditor = false

    private var spotMarkers: [SpotMarker] {
        (listing.spotMarkers ?? []).filter { $0.id != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statsBanner
                pricingRulesSection
                if !spotMarkers.isEmpty {
                    spotGrid
                }
                upcomingSection
            }
            .padding(16)
        }
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showPricingEditor, onDismiss: {
            Task {
                pricingRules = await PricingService.fetchRules(listingId: listing.id)
            }
        }) {
            PricingRulesEditorView(
                listingId: listing.id,
                basePrice: listing.price ?? 0
            )
        }
    }

    private var pricingRulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Prisregler")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button {
                    showPricingEditor = true
                } label: {
                    Text(pricingRules.isEmpty ? "Legg til" : "Rediger")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary600)
                        .clipShape(Capsule())
                }
            }

            if pricingRules.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.neutral500)
                        .font(.system(size: 13))
                    Text("Ingen aktive regler. Alle netter bruker annonsens standardpris (\(listing.price ?? 0) kr).")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral600)
                }
                .padding(12)
                .background(Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(pricingRules.enumerated()), id: \.offset) { _, rule in
                        pricingRuleRow(rule)
                    }
                }
            }
        }
    }

    private func pricingRuleRow(_ rule: PricingService.Rule) -> some View {
        HStack(spacing: 10) {
            Image(systemName: rule.kind == "weekend" ? "calendar" : "sun.max")
                .foregroundStyle(Color.primary600)
                .font(.system(size: 13))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                if rule.kind == "weekend" {
                    Text("Helg-pris")
                        .font(.system(size: 14, weight: .medium))
                } else {
                    Text("Sesong-pris")
                        .font(.system(size: 14, weight: .medium))
                    if let start = rule.start_date, let end = rule.end_date {
                        Text("\(start) – \(end)")
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral500)
                    }
                }
            }
            Spacer()
            Text("\(rule.price) kr/natt")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral900)
        }
        .padding(10)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statsBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCard(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Belegg 30 d",
                    value: "\(stats30.occupancyPct)%",
                    sub: "Siste 90 d: \(stats90.occupancyPct)%"
                )
                statCard(
                    icon: "norwegiankronesign.circle",
                    label: "Inntekt 30 d",
                    value: "\(stats30.revenue) kr",
                    sub: "Siste 90 d: \(stats90.revenue) kr"
                )
                statCard(
                    icon: "calendar",
                    label: "Kommende",
                    value: "\(stats30.upcomingCount)",
                    sub: stats30.nextCheckIn.map { "Neste: \($0)" } ?? "Ingen kommende"
                )
                statCard(
                    icon: "person.2",
                    label: "Kapasitet",
                    value: "\(listing.spots ?? 1)",
                    sub: spotMarkers.isEmpty ? "Samlet kapasitet" : "\(spotMarkers.count) plasser"
                )
            }
        }
    }

    private func statCard(icon: String, label: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.neutral500)

            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.neutral900)
            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(.neutral500)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    private var spotGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per plass")
                .font(.system(size: 17, weight: .semibold))
            Text("Trykk på en plass for å se kalender og blokkere datoer.")
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)

            VStack(spacing: 10) {
                ForEach(spotMarkers, id: \.id) { spot in
                    NavigationLink {
                        HostSpotDetailView(listing: listing, spotId: spot.id ?? "")
                    } label: {
                        spotCard(spot)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func spotCard(_ spot: SpotMarker) -> some View {
        let stats = perSpotStats(spot.id ?? "")
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(spot.label ?? "Plass uten navn")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral400)
            }
            HStack(spacing: 16) {
                statPill("Belegg 30 d", "\(stats.occupancyPct)%")
                statPill("Kommende", "\(stats.upcomingCount)")
                statPill("Inntekt 30 d", "\(stats.revenue) kr")
            }
            if let next = stats.nextCheckIn {
                Text("Neste: \(next)")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    private func statPill(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundStyle(.neutral500)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(.neutral900)
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kommende bookinger")
                .font(.system(size: 17, weight: .semibold))

            if isLoading {
                ProgressView().padding(.vertical)
            } else if upcomingBookings.isEmpty {
                Text("Ingen kommende bookinger.")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            } else {
                VStack(spacing: 8) {
                    ForEach(upcomingBookings) { b in
                        bookingRow(b)
                    }
                }
            }
        }
    }

    private func bookingRow(_ b: Booking) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(b.guest?.fullName ?? "Anonym")
                    .font(.system(size: 14, weight: .medium))
                Text("\(b.checkIn) → \(b.checkOut)")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(b.totalPrice) kr")
                    .font(.system(size: 14, weight: .semibold))
                if b.status == .requested {
                    Text("Forespørsel")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neutral200, lineWidth: 1))
    }

    // MARK: - Data

    private var upcomingBookings: [Booking] {
        let today = TunoCalendar.todayKey()
        return bookings
            .filter { ($0.status == .confirmed || $0.status == .requested) && $0.checkIn >= today }
            .sorted { $0.checkIn < $1.checkIn }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            bookings = try await supabase
                .from("bookings")
                .select("*, guest:user_id(full_name, avatar_url, rating, review_count)")
                .eq("listing_id", value: listing.id)
                .in("status", values: ["confirmed", "requested"])
                .execute()
                .value
            stats30 = ListingStatsSnapshot.compute(listing: listing, bookings: bookings, days: 30)
            stats90 = ListingStatsSnapshot.compute(listing: listing, bookings: bookings, days: 90)
        } catch {
            print("HostListingStats load error: \(error)")
        }

        // Last pris-regler separat — ikke-kritisk, faller bare til tom array ved feil.
        do {
            pricingRules = try await supabase
                .from("listing_pricing_rules")
                .select()
                .eq("listing_id", value: listing.id)
                .execute()
                .value
        } catch {
            pricingRules = []
        }
    }

    private func perSpotStats(_ spotId: String) -> ListingStatsSnapshot {
        ListingStatsSnapshot.compute(listing: listing, bookings: bookings, days: 30, spotId: spotId)
    }
}

// MARK: - Stats snapshot

struct ListingStatsSnapshot {
    let occupancyPct: Int
    let revenue: Int
    let upcomingCount: Int
    let nextCheckIn: String?

    static let zero = ListingStatsSnapshot(occupancyPct: 0, revenue: 0, upcomingCount: 0, nextCheckIn: nil)

    /// Beregn stats fra hentede bookinger uten flere round-trips.
    static func compute(listing: Listing, bookings: [Booking], days: Int, spotId: String? = nil) -> ListingStatsSnapshot {
        let serviceFee = 0.10
        let hostShare = 1 - serviceFee
        let today = TunoCalendar.todayKey()
        let fromKey = TunoCalendar.dateKey(daysAgo: days)
        let capacity = listing.spots ?? 1

        var occupiedNights = 0
        var revenue = 0
        var upcomingCount = 0
        var nextCheckIn: String?

        for b in bookings {
            let inSpot = spotId.map { (b.selectedSpotIds ?? []).contains($0) } ?? true
            if !inSpot { continue }

            // Past window for occupancy + revenue (only confirmed)
            if b.status == .confirmed && b.checkIn < today && b.checkOut >= fromKey {
                let ci = max(b.checkIn, fromKey)
                let co = min(b.checkOut, today)
                if let nights = TunoCalendar.nightsBetween(ci, co), nights > 0 {
                    let occupies = (b.selectedSpotIds?.count ?? 0) > 0 ? (b.selectedSpotIds?.count ?? 1) : 1
                    occupiedNights += nights * (spotId != nil ? 1 : occupies)
                    let denom = max(1, b.selectedSpotIds?.count ?? 1)
                    let factor = spotId != nil ? (1.0 / Double(denom)) : 1.0
                    revenue += Int(Double(b.totalPrice) * hostShare * factor)
                }
            }

            // Upcoming
            if (b.status == .confirmed || b.status == .requested) && b.checkIn >= today {
                upcomingCount += 1
                if nextCheckIn == nil || b.checkIn < (nextCheckIn ?? "9999") {
                    nextCheckIn = b.checkIn
                }
            }
        }

        let denom = (spotId != nil ? 1 : capacity) * days
        let pct = denom > 0 ? min(100, Int(Double(occupiedNights) / Double(denom) * 100)) : 0

        return ListingStatsSnapshot(occupancyPct: pct, revenue: revenue, upcomingCount: upcomingCount, nextCheckIn: nextCheckIn)
    }
}

// (TunoCalendar er nå definert i Services/TunoCalendar.swift)
