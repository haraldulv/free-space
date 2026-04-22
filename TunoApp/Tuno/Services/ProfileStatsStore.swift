import Foundation
import SwiftUI

/// Holder statistikken for Profil-tab (antall turer, rating, inntekt-snapshot, osv.)
/// slik at verdiene overlever tab-bytter og ikke flimrer fra 0 → ekte verdi hver gang
/// man åpner Profil. Lever på MainTabView-nivå som @StateObject.
@MainActor
final class ProfileStatsStore: ObservableObject {
    @Published var pendingRequestCount: Int = 0
    @Published var unreadNotifications: Int = 0
    @Published var tripCount: Int = 0
    @Published var reviewCount: Int = 0
    @Published var rating: Double? = nil
    @Published var monthlyNet: Int = 0
    @Published var monthlyBookings: Int = 0
    @Published var recentMonthsEarnings: [HostInntektCard.MonthlyEarning] = []

    /// Sant første gang lastingen er ferdig — brukes for å vise ProgressView bare
    /// helt første gang. Påfølgende refresh skjer i bakgrunnen uten å nullstille.
    @Published var hasLoaded: Bool = false

    private var isRefreshing = false
    private var loadedForUserId: String?

    /// Last eller refresh. Cached verdier forblir synlige mens nye hentes —
    /// ingen flicker. Ved bruker-bytte (logg ut/inn) nullstiller vi først.
    func refresh(userId: String, isHost: Bool) async {
        // Bruker-bytte: nullstill så vi ikke viser forrige brukers verdier
        if let loaded = loadedForUserId, loaded != userId {
            pendingRequestCount = 0
            unreadNotifications = 0
            tripCount = 0
            reviewCount = 0
            rating = nil
            monthlyNet = 0
            monthlyBookings = 0
            recentMonthsEarnings = []
            hasLoaded = false
        }
        loadedForUserId = userId

        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPendingCount(userId: userId, isHost: isHost) }
            group.addTask { await self.loadUnreadCount(userId: userId) }
            group.addTask { await self.loadTripCount(userId: userId) }
            group.addTask { await self.loadReviewCount(userId: userId) }
            if isHost {
                group.addTask { await self.loadMonthlyRevenue(userId: userId) }
            }
        }

        hasLoaded = true
    }

    func clear() {
        pendingRequestCount = 0
        unreadNotifications = 0
        tripCount = 0
        reviewCount = 0
        rating = nil
        monthlyNet = 0
        monthlyBookings = 0
        recentMonthsEarnings = []
        hasLoaded = false
        loadedForUserId = nil
    }

    // MARK: - Individual loaders

    private func loadPendingCount(userId: String, isHost: Bool) async {
        guard isHost else {
            pendingRequestCount = 0
            return
        }
        do {
            let count = try await supabase
                .from("bookings")
                .select("id", head: true, count: .exact)
                .eq("host_id", value: userId)
                .eq("status", value: "requested")
                .execute()
                .count ?? 0
            pendingRequestCount = count
        } catch {
            print("ProfileStats loadPendingCount error: \(error)")
        }
    }

    private func loadUnreadCount(userId: String) async {
        do {
            let count = try await supabase
                .from("notifications")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .eq("read", value: false)
                .execute()
                .count ?? 0
            unreadNotifications = count
        } catch {
            print("ProfileStats loadUnreadCount error: \(error)")
        }
    }

    private func loadTripCount(userId: String) async {
        do {
            let count = try await supabase
                .from("bookings")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .eq("status", value: "confirmed")
                .execute()
                .count ?? 0
            tripCount = count
        } catch {
            print("ProfileStats loadTripCount error: \(error)")
        }
    }

    private func loadReviewCount(userId: String) async {
        do {
            struct RatingRow: Decodable {
                let rating: Double?
                let reviewCount: Int?
                enum CodingKeys: String, CodingKey {
                    case rating
                    case reviewCount = "review_count"
                }
            }
            let rows: [RatingRow] = try await supabase
                .from("profiles")
                .select("rating, review_count")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            if let row = rows.first {
                reviewCount = row.reviewCount ?? 0
                rating = row.rating
            }
        } catch {
            print("ProfileStats loadReviewCount error: \(error)")
        }
    }

    private func loadMonthlyRevenue(userId: String) async {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current

        var comps = cal.dateComponents([.year, .month], from: Date())
        comps.day = 1
        guard let currentMonthStart = cal.date(from: comps) else { return }
        guard let threeMonthsAgo = cal.date(byAdding: .month, value: -2, to: currentMonthStart) else { return }

        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(identifier: "Europe/Oslo")
        let fromRecent = iso.string(from: threeMonthsAgo)
        let fromThisMonth = iso.string(from: currentMonthStart)

        struct Row: Decodable {
            let totalPrice: Int
            let createdAt: String?
            enum CodingKeys: String, CodingKey {
                case totalPrice = "total_price"
                case createdAt = "created_at"
            }
        }

        do {
            let rows: [Row] = try await supabase
                .from("bookings")
                .select("total_price, created_at")
                .eq("host_id", value: userId)
                .eq("status", value: "confirmed")
                .eq("payment_status", value: "paid")
                .gte("created_at", value: fromRecent)
                .execute()
                .value

            let serviceFee = 0.10

            let thisMonthRows = rows.filter { ($0.createdAt ?? "") >= fromThisMonth }
            monthlyNet = thisMonthRows.reduce(0) { $0 + Int(Double($1.totalPrice) * (1 - serviceFee)) }
            monthlyBookings = thisMonthRows.count

            let keyFormatter = DateFormatter()
            keyFormatter.dateFormat = "yyyy-MM"
            keyFormatter.locale = Locale(identifier: "en_US_POSIX")
            keyFormatter.timeZone = TimeZone(identifier: "Europe/Oslo")

            let shortMonthFormatter = DateFormatter()
            shortMonthFormatter.dateFormat = "MMM"
            shortMonthFormatter.locale = Locale(identifier: "nb_NO")
            shortMonthFormatter.timeZone = TimeZone(identifier: "Europe/Oslo")

            let parser = ISO8601DateFormatter()
            parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            var bucket: [String: Int] = [:]
            for row in rows {
                guard let isoDate = row.createdAt,
                      let date = parser.date(from: isoDate) ?? {
                          parser.formatOptions = [.withInternetDateTime]
                          return parser.date(from: isoDate)
                      }() else { continue }
                let key = keyFormatter.string(from: date)
                bucket[key, default: 0] += Int(Double(row.totalPrice) * (1 - serviceFee))
            }

            var months: [HostInntektCard.MonthlyEarning] = []
            for offset in (0...2).reversed() {
                guard let monthDate = cal.date(byAdding: .month, value: -offset, to: currentMonthStart) else { continue }
                let key = keyFormatter.string(from: monthDate)
                let label = shortMonthFormatter.string(from: monthDate).lowercased()
                months.append(HostInntektCard.MonthlyEarning(
                    id: key,
                    shortLabel: label,
                    earnings: bucket[key] ?? 0
                ))
            }
            recentMonthsEarnings = months
        } catch {
            print("ProfileStats loadMonthlyRevenue error: \(error)")
        }
    }
}
