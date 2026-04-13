import SwiftUI

private let SERVICE_FEE = 0.10

struct EarningsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var bookings: [Booking] = []
    @State private var listings: [Listing] = []
    @State private var isLoading = true

    private var confirmedBookings: [Booking] {
        bookings.filter { $0.status == .confirmed && $0.paymentStatus == .paid }
    }

    private var totalRevenue: Int {
        confirmedBookings.reduce(0) { $0 + $1.totalPrice }
    }

    private var hostShare: Int {
        Int(Double(totalRevenue) * (1 - SERVICE_FEE))
    }

    private var platformFee: Int {
        totalRevenue - hostShare
    }

    private var thisMonthKey: String {
        let now = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        return String(format: "%04d-%02d", y, m)
    }

    private var thisMonthEarnings: Int {
        confirmedBookings
            .filter { $0.createdAt?.hasPrefix(thisMonthKey) == true }
            .reduce(0) { $0 + Int(Double($1.totalPrice) * (1 - SERVICE_FEE)) }
    }

    private var activeListings: Int {
        listings.filter { $0.isActive == true }.count
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if confirmedBookings.isEmpty && listings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 40))
                        .foregroundStyle(.neutral300)
                    Text("Ingen inntekter ennå")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.neutral500)
                    Text("Inntektene dine vil vises her")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        statCards
                        monthlyChart
                        listingBreakdown
                        recentBookings
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Inntekter")
        .task {
            await loadData()
        }
    }

    // MARK: - Stat Cards

    private var statCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                icon: "norwegiankronesign",
                iconBg: .green.opacity(0.1),
                iconColor: .green,
                label: "Totalt tjent",
                value: "\(formatKr(hostShare)) kr",
                subtitle: "\(formatKr(platformFee)) kr i plattformavgift"
            )
            StatCard(
                icon: "chart.line.uptrend.xyaxis",
                iconBg: Color.primary100,
                iconColor: Color.primary600,
                label: "Denne måneden",
                value: "\(formatKr(thisMonthEarnings)) kr"
            )
            StatCard(
                icon: "arrow.up.right",
                iconBg: .green.opacity(0.1),
                iconColor: .green,
                label: "Bookings",
                value: "\(confirmedBookings.count)"
            )
            StatCard(
                icon: "clock",
                iconBg: .orange.opacity(0.1),
                iconColor: .orange,
                label: "Aktive annonser",
                value: "\(activeListings)"
            )
        }
    }

    // MARK: - Monthly Chart

    private var monthlyData: [(label: String, key: String, earnings: Int, count: Int)] {
        let now = Date()
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "MMM"

        return (0..<6).reversed().map { i in
            guard let d = cal.date(byAdding: .month, value: -i, to: now) else {
                return ("", "", 0, 0)
            }
            let y = cal.component(.year, from: d)
            let m = cal.component(.month, from: d)
            let key = String(format: "%04d-%02d", y, m)
            let label = formatter.string(from: d)
            let matched = confirmedBookings.filter { $0.createdAt?.hasPrefix(key) == true }
            let earnings = matched.reduce(0) { $0 + Int(Double($1.totalPrice) * (1 - SERVICE_FEE)) }
            return (label, key, earnings, matched.count)
        }
    }

    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary600)
                Text("Månedlig inntekt")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral700)
            }

            let data = monthlyData
            let maxEarnings = max(data.map(\.earnings).max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.key) { month in
                    VStack(spacing: 4) {
                        if month.earnings > 0 {
                            Text(formatKr(month.earnings))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.neutral700)
                        }

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary600)
                            .frame(
                                height: max(
                                    CGFloat(month.earnings) / CGFloat(maxEarnings) * 120,
                                    month.earnings > 0 ? 4 : 0
                                )
                            )

                        Text(month.label)
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral400)

                        if month.count > 0 {
                            Text("\(month.count) booking\(month.count > 1 ? "s" : "")")
                                .font(.system(size: 9))
                                .foregroundStyle(.neutral300)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Per-listing Breakdown

    private var listingBreakdownData: [(id: String, title: String, image: String, earnings: Int, count: Int)] {
        var map: [String: (title: String, image: String, earnings: Int, count: Int)] = [:]
        for b in confirmedBookings {
            let existing = map[b.listingId] ?? (
                title: b.listing?.title ?? "Ukjent",
                image: b.listing?.images.first ?? "",
                earnings: 0,
                count: 0
            )
            map[b.listingId] = (
                title: existing.title,
                image: existing.image,
                earnings: existing.earnings + Int(Double(b.totalPrice) * (1 - SERVICE_FEE)),
                count: existing.count + 1
            )
        }
        return map.map { ($0.key, $0.value.title, $0.value.image, $0.value.earnings, $0.value.count) }
            .sorted { $0.earnings > $1.earnings }
    }

    private var listingBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inntekt per annonse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral700)

            let data = listingBreakdownData
            let topEarnings = max(data.first?.earnings ?? 1, 1)

            if data.isEmpty {
                Text("Ingen inntekter ennå")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral400)
                    .padding(.vertical, 8)
            } else {
                ForEach(data, id: \.id) { item in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: item.image)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Rectangle().fill(Color.neutral100)
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.neutral700)
                                .lineLimit(1)
                            Text("\(item.count) booking\(item.count > 1 ? "s" : "")")
                                .font(.system(size: 12))
                                .foregroundStyle(.neutral400)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.neutral100)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.primary600)
                                        .frame(
                                            width: geo.size.width * CGFloat(item.earnings) / CGFloat(topEarnings),
                                            height: 6
                                        )
                                }
                            }
                            .frame(height: 6)
                        }

                        Text("\(formatKr(item.earnings)) kr")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.neutral900)
                    }
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Recent Bookings

    private var recentBookings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Siste bookings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral700)

            let recent = bookings
                .filter { $0.paymentStatus == .paid }
                .prefix(10)

            if recent.isEmpty {
                Text("Ingen bookings ennå")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral400)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(recent), id: \.id) { b in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.listing?.title ?? "Ukjent")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.neutral700)
                                .lineLimit(1)
                            Text("\(formatDate(b.checkIn)) – \(formatDate(b.checkOut))")
                                .font(.system(size: 12))
                                .foregroundStyle(.neutral400)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(formatKr(Int(Double(b.totalPrice) * (1 - SERVICE_FEE)))) kr")
                                .font(.system(size: 14, weight: .semibold))
                            Text(b.status == .confirmed ? "Bekreftet" : "Kansellert")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(b.status == .confirmed ? .green : .red)
                        }
                    }
                    .padding(.vertical, 8)

                    if b.id != recent.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Helpers

    private func formatKr(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private func formatDate(_ dateString: String) -> String {
        let parts = dateString.prefix(10).split(separator: "-")
        guard parts.count == 3 else { return dateString }
        return "\(parts[2]).\(parts[1])"
    }

    private func loadData() async {
        guard let userId = authManager.currentUser?.id else {
            isLoading = false
            return
        }
        let uid = userId.uuidString.lowercased()

        async let bookingsQuery: [Booking] = {
            do {
                return try await supabase
                    .from("bookings")
                    .select("*, listing:listings(id, title, city, images)")
                    .eq("host_id", value: uid)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            } catch {
                print("Failed to load host bookings: \(error)")
                return []
            }
        }()

        async let listingsQuery: [Listing] = {
            do {
                return try await supabase
                    .from("listings")
                    .select()
                    .eq("host_id", value: uid)
                    .execute()
                    .value
            } catch {
                print("Failed to load host listings: \(error)")
                return []
            }
        }()

        bookings = await bookingsQuery
        listings = await listingsQuery
        isLoading = false
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let label: String
    let value: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                    Text(value)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.neutral900)
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.neutral400)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}
