import SwiftUI

/// Plass-detalj med kalender for å blokkere datoer + liste over kommende bookinger.
/// Bruker TunoCalendar (timezone-safe) for å unngå off-by-one bugs som har
/// plaget tidligere kalender-implementasjoner.
struct HostSpotDetailView: View {
    let listing: Listing
    let spotId: String
    @State private var blockedDates: Set<String> = []
    @State private var initialBlocked: Set<String> = []
    @State private var bookings: [Booking] = []
    @State private var bookedDates: Set<String> = []
    @State private var displayedMonth = Date()
    @State private var saving = false
    @State private var saveError: String?
    @State private var saved = false

    private let calendar = Calendar.current

    private var spot: SpotMarker? {
        (listing.spotMarkers ?? []).first(where: { $0.id == spotId })
    }

    private var dirty: Bool {
        blockedDates != initialBlocked
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                calendarBlock
                legend
                saveBar
                upcomingList
            }
            .padding(16)
        }
        .navigationTitle(spot?.label ?? "Plass")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(spot?.label ?? "Plass uten navn")
                .font(.system(size: 22, weight: .bold))
            if let price = spot?.price {
                Text("\(price) kr per natt")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            } else {
                Text("Bruker annonsens pris")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            }
        }
    }

    private var calendarBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { moveMonth(-1) } label: {
                    Image(systemName: "chevron.left").foregroundStyle(.neutral600)
                }
                Spacer()
                Text(monthLabel(displayedMonth))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { moveMonth(1) } label: {
                    Image(systemName: "chevron.right").foregroundStyle(.neutral600)
                }
            }

            let weekdays = ["Ma", "Ti", "On", "To", "Fr", "Lo", "Sø"]
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { d in
                    Text(d)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.neutral500)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(daysInMonth().indices, id: \.self) { idx in
                    if let day = daysInMonth()[idx] {
                        dayButton(for: day)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    private func dayButton(for day: Date) -> some View {
        let key = TunoCalendar.dateKey(day)
        let isPast = day < calendar.startOfDay(for: Date())
        let isBooked = bookedDates.contains(key)
        let isBlocked = blockedDates.contains(key)
        let canTap = !isPast && !isBooked

        let fg: Color
        if isPast { fg = .neutral300 }
        else if isBooked { fg = Color(hex: "#4338ca") }
        else if isBlocked { fg = Color(hex: "#dc2626") }
        else { fg = .neutral800 }

        let bg: Color
        if isBooked { bg = Color(hex: "#e0e7ff") }
        else if isBlocked { bg = Color(hex: "#fee2e2") }
        else { bg = Color.clear }

        let weight: Font.Weight = (isBlocked || isBooked) ? .semibold : .regular

        return Button {
            guard canTap else { return }
            if isBlocked {
                blockedDates.remove(key)
            } else {
                blockedDates.insert(key)
            }
            saved = false
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 15, weight: weight))
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(!canTap)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Color(hex: "#fee2e2"), label: "Blokkert")
            legendItem(color: Color(hex: "#e0e7ff"), label: "Booket")
        }
        .font(.system(size: 12))
        .foregroundStyle(.neutral500)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }

    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let err = saveError {
                Text(err).font(.system(size: 12)).foregroundStyle(.red)
            }
            HStack {
                Button {
                    Task { await save() }
                } label: {
                    HStack(spacing: 6) {
                        if saving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "tray.and.arrow.down").font(.system(size: 12))
                        }
                        Text(saving ? "Lagrer…" : "Lagre blokkering")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(dirty && !saving ? Color.primary600 : Color.neutral300)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!dirty || saving)

                if saved && !dirty {
                    Text("Lagret")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                }

                Spacer()

                if !blockedDates.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 11))
                        Text("\(blockedDates.count) blokkert")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "#dc2626"))
                }
            }
        }
    }

    private var upcomingList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kommende på denne plassen")
                .font(.system(size: 17, weight: .semibold))
            let upcoming = bookings.filter { ($0.selectedSpotIds ?? []).contains(spotId) }
                .filter { $0.checkIn >= TunoCalendar.todayKey() }
                .sorted { $0.checkIn < $1.checkIn }

            if upcoming.isEmpty {
                Text("Ingen kommende bookinger.")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            } else {
                VStack(spacing: 8) {
                    ForEach(upcoming) { b in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.guest?.fullName ?? "Anonym")
                                    .font(.system(size: 14, weight: .medium))
                                Text("\(b.checkIn) → \(b.checkOut)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.neutral500)
                            }
                            Spacer()
                            Text("\(b.totalPrice) kr")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neutral200, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func moveMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = d
        }
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date).capitalized
    }

    /// Bygger array av Date? for hele måneden, padded slik at uka starter mandag.
    private func daysInMonth() -> [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }

        var weekday = calendar.component(.weekday, from: firstDay)
        weekday = weekday == 1 ? 7 : weekday - 1

        var days: [Date?] = Array(repeating: nil, count: weekday - 1)
        for d in range {
            if let date = calendar.date(byAdding: .day, value: d - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func load() async {
        let initial = Set(spot?.blockedDates ?? [])
        blockedDates = initial
        initialBlocked = initial

        do {
            bookings = try await supabase
                .from("bookings")
                .select("*, guest:user_id(full_name, avatar_url, rating, review_count)")
                .eq("listing_id", value: listing.id)
                .in("status", values: ["confirmed", "requested"])
                .gte("check_out", value: TunoCalendar.todayKey())
                .execute()
                .value

            // Bygg sett av booket datoer for denne plassen
            var booked = Set<String>()
            for b in bookings where (b.selectedSpotIds ?? []).contains(spotId) {
                guard let start = TunoCalendar.date(from: b.checkIn),
                      let end = TunoCalendar.date(from: b.checkOut) else { continue }
                var cursor = start
                while cursor < end {
                    booked.insert(TunoCalendar.dateKey(cursor))
                    cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? end
                }
            }
            bookedDates = booked
        } catch {
            print("HostSpotDetail load error: \(error)")
        }
    }

    private func save() async {
        saveError = nil
        saving = true
        defer { saving = false }

        guard let token = try? await supabase.auth.session.accessToken,
              let url = URL(string: "\(AppConfig.siteURL)/api/host/spot-blocked-dates") else {
            saveError = "Ikke innlogget"
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "listingId": listing.id,
            "spotId": spotId,
            "blockedDates": Array(blockedDates).sorted(),
        ])

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? String {
                saveError = err
                return
            }
            initialBlocked = blockedDates
            saved = true
        } catch {
            saveError = "Noe gikk galt"
        }
    }
}
