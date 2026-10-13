import SwiftUI

/// Vertens samlede oversikt over bookinger på egne annonser, gruppert
/// Pågår nå / Kommende / Venter på svar / Tidligere. Bor i Bestillinger-
/// fanen bak «Som vert»-velgeren (Harald 2026-10-13: en egen «Utleiinger»-
/// rad i profilen var for godt gjemt og hadde et dårlig navn). Embeddes av
/// BookingsView — ingen egen navigationTitle/bakgrunn.
struct HostBookingsContent: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var bookings: [Booking] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading && bookings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bookings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.neutral300)
                    Text("Ingen bookinger på plassene dine ennå")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.neutral500)
                        .multilineTextAlignment(.center)
                    Text("Når noen booker en av plassene dine, vises bookingen her.")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        bookingSection("Pågår nå", items: ongoing)
                        bookingSection("Kommende", items: upcoming)
                        bookingSection("Venter på svar", items: awaiting)
                        bookingSection("Tidligere", items: past)
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await load() }
    }

    // MARK: - Grupper

    private var ongoing: [Booking] {
        let today = TunoCalendar.todayKey()
        return bookings.filter { $0.status == .confirmed && $0.checkIn <= today && $0.checkOut >= today }
            .sorted { $0.checkOut < $1.checkOut }
    }

    private var upcoming: [Booking] {
        let today = TunoCalendar.todayKey()
        return bookings.filter { $0.status == .confirmed && $0.checkIn > today }
            .sorted { $0.checkIn < $1.checkIn }
    }

    private var awaiting: [Booking] {
        bookings.filter { $0.status == .requested }
            .sorted { $0.checkIn < $1.checkIn }
    }

    private var past: [Booking] {
        let today = TunoCalendar.todayKey()
        return bookings.filter { $0.status == .confirmed && $0.checkOut < today }
            .sorted { $0.checkIn > $1.checkIn }
    }

    @ViewBuilder
    private func bookingSection(_ title: String, items: [Booking]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral500)
                    .textCase(.uppercase)
                VStack(spacing: 10) {
                    ForEach(items) { b in
                        bookingCard(b)
                    }
                }
            }
        }
    }

    private func bookingCard(_ b: Booking) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(b.listing?.title ?? "Annonse")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)
                    Text(b.guest?.fullName ?? "Gjest")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral600)
                }
                Spacer()
                statusChip(b)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateLabel(b))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral700)
                    // Regnr er privat: vises først når bookingen er bekreftet.
                    if b.status == .confirmed, let vehicle = b.hostVehicleLabel {
                        Text(vehicle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.neutral600)
                    }
                }
                Spacer()
                Text("\(b.totalPrice) kr")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.neutral900)
            }
        }
        .padding(14)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appLine, lineWidth: 1))
    }

    private func statusChip(_ b: Booking) -> some View {
        let today = TunoCalendar.todayKey()
        let (label, fg): (String, Color)
        if b.status == .requested {
            (label, fg) = ("Forespørsel", .orange)
        } else if b.checkIn <= today && b.checkOut >= today {
            (label, fg) = ("Pågår", AppConfig.parkingOnly ? Color(hex: "#1f9177") : .appAccent)
        } else if b.checkOut < today {
            (label, fg) = ("Fullført", .neutral500)
        } else {
            (label, fg) = ("Bekreftet", AppConfig.parkingOnly ? Color(hex: "#1f9177") : .appAccent)
        }
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fg.opacity(0.12))
            .clipShape(Capsule())
    }

    private func dateLabel(_ b: Booking) -> String {
        if b.hasGappedDates, let dates = b.bookedDates {
            return "\(dates.count) dager mellom \(b.checkIn) og \(b.checkOut)"
        }
        return "\(b.checkIn) → \(b.checkOut)"
    }

    private func load() async {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased() else {
            isLoading = false
            return
        }
        do {
            bookings = try await supabase
                .from("bookings")
                .select("*, listing:listings(id, title, city, images), guest:user_id(full_name, avatar_url, rating, review_count)")
                .eq("host_id", value: userId)
                .in("status", values: ["confirmed", "requested"])
                .order("check_in", ascending: true)
                .execute()
                .value
        } catch {
            print("HostBookingsView load error: \(error)")
        }
        isLoading = false
    }
}
