import SwiftUI

struct HostRequestsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var requests: [Booking] = []
    @State private var guestBookingCounts: [String: Int] = [:]
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedBooking: Booking?

    var body: some View {
        Group {
            if isLoading && requests.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if requests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.neutral300)
                    Text("Ingen forespørsler nå")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.neutral500)
                    Text("Forespørsler fra gjester vises her.")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(requests) { booking in
                            Button {
                                selectedBooking = booking
                            } label: {
                                requestCard(booking)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Forespørsler")
        .task { await load() }
        .sheet(item: $selectedBooking) { booking in
            HostRequestDetailSheet(
                booking: booking,
                previousBookingCount: guestBookingCounts[booking.userId] ?? 0,
                onResolved: { bookingId in
                    requests.removeAll { $0.id == bookingId }
                    selectedBooking = nil
                }
            )
        }
    }

    private func requestCard(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Gjest-header: avatar + navn + rating/Ny gjest
            HStack(spacing: 12) {
                GuestAvatar(avatarUrl: booking.guest?.avatarUrl, name: booking.guest?.fullName)

                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.guest?.fullName ?? "Gjest")
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    guestMetaRow(booking)
                }

                Spacer()
            }

            Divider()

            // Annonse + pris
            HStack(alignment: .top) {
                if let listing = booking.listing {
                    HStack(spacing: 10) {
                        AsyncImage(url: URL(string: listing.images.first ?? "")) { phase in
                            switch phase {
                            case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                            default: Rectangle().fill(Color.neutral100)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(listing.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.neutral700)
                                .lineLimit(1)
                            Text("\(booking.checkIn) → \(booking.checkOut)")
                                .font(.system(size: 12))
                                .foregroundStyle(.neutral500)
                        }
                    }
                }
                Spacer()
                Text("\(booking.totalPrice) kr")
                    .font(.system(size: 16, weight: .bold))
            }

            // Nedtelling
            if let deadlineText = deadlineLabel(booking.approvalDeadline) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(deadlineText)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }

            // "Se gjennom"-CTA
            HStack {
                Text("Se gjennom")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary600)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary600)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary600.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    @ViewBuilder
    private func guestMetaRow(_ booking: Booking) -> some View {
        HStack(spacing: 8) {
            if let count = booking.guest?.reviewCount, count > 0,
               let rating = booking.guest?.rating {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f (%d)", rating, count))
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral600)
                }
            } else {
                Text("Ny gjest")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.neutral600)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.neutral100)
                    .clipShape(Capsule())
            }

            let tripCount = guestBookingCounts[booking.userId] ?? 0
            if tripCount > 0 {
                Text("• \(tripCount) \(tripCount == 1 ? "tur" : "turer")")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }

            if let year = booking.guest?.joinedYear {
                Text("• Gjest siden \(String(year))")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
                    .lineLimit(1)
            }
        }
    }

    private func deadlineLabel(_ deadline: String?) -> String? {
        guard let deadline,
              let date = ISO8601DateFormatter.tunoFractional.date(from: deadline) ?? ISO8601DateFormatter.tunoBasic.date(from: deadline)
        else { return nil }
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "Tidsfristen har gått ut" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "Utløper om \(hours) t \(minutes) min"
    }

    private func load() async {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased() else {
            isLoading = false
            return
        }
        do {
            let fetched: [Booking] = try await supabase
                .from("bookings")
                .select("*, listing:listings(id, title, city, images), guest:user_id(full_name, avatar_url, rating, review_count, joined_year)")
                .eq("host_id", value: userId)
                .eq("status", value: "requested")
                .order("created_at", ascending: false)
                .execute()
                .value
            requests = fetched
            await loadGuestBookingCounts(for: fetched)
        } catch {
            print("Failed to load host requests: \(error)")
            self.error = "Kunne ikke laste forespørsler"
        }
        isLoading = false
    }

    private func loadGuestBookingCounts(for bookings: [Booking]) async {
        let guestIds = Array(Set(bookings.map { $0.userId }))
        guard !guestIds.isEmpty else { return }
        struct BookingRow: Decodable { let user_id: String }
        do {
            let rows: [BookingRow] = try await supabase
                .from("bookings")
                .select("user_id")
                .in("user_id", values: guestIds)
                .eq("status", value: "confirmed")
                .execute()
                .value
            var counts: [String: Int] = [:]
            for row in rows {
                counts[row.user_id, default: 0] += 1
            }
            guestBookingCounts = counts
        } catch {
            print("Failed to load guest booking counts: \(error)")
        }
    }
}

// MARK: - Guest avatar

private struct GuestAvatar: View {
    let avatarUrl: String?
    let name: String?
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallback: some View {
        Circle()
            .fill(Color.primary100)
            .overlay(
                Text(String((name ?? "?").prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.primary600)
            )
    }
}

// MARK: - Detail sheet

private struct HostRequestDetailSheet: View {
    let booking: Booking
    let previousBookingCount: Int
    let onResolved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var responding: String? = nil
    @State private var error: String?
    @State private var showDeclineConfirm = false
    @State private var showApproveConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    guestSection
                    Divider()
                    stayDetailsSection
                    Divider()
                    priceSection
                    Divider()
                    policySection

                    if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
                .padding(.bottom, 120)
            }
            .navigationTitle("Forespørsel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
        }
        .alert("Godkjenn forespørselen?", isPresented: $showApproveConfirm) {
            Button("Godkjenn", role: .none) {
                Task { await respond(action: "approve") }
            }
            Button("Avbryt", role: .cancel) { }
        } message: {
            Text("Beløpet belastes gjesten og pengene reserveres til utbetaling etter oppholdet.")
        }
        .alert("Avvise forespørselen?", isPresented: $showDeclineConfirm) {
            Button("Avvis", role: .destructive) {
                Task { await respond(action: "decline") }
            }
            Button("Avbryt", role: .cancel) { }
        } message: {
            Text("Beløpet frigjøres til gjesten umiddelbart.")
        }
    }

    private var guestSection: some View {
        HStack(spacing: 14) {
            GuestAvatar(avatarUrl: booking.guest?.avatarUrl, name: booking.guest?.fullName, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text(booking.guest?.fullName ?? "Gjest")
                    .font(.system(size: 20, weight: .bold))

                if let count = booking.guest?.reviewCount, count > 0,
                   let rating = booking.guest?.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 14, weight: .semibold))
                        Text("(\(count) anmeldelser)")
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                    }
                } else {
                    Text("Ny gjest")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.neutral600)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.neutral100)
                        .clipShape(Capsule())
                }

                HStack(spacing: 10) {
                    if previousBookingCount > 0 {
                        Label("\(previousBookingCount) \(previousBookingCount == 1 ? "tur" : "turer")", systemImage: "suitcase.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral600)
                    }
                    if let year = booking.guest?.joinedYear {
                        Label("Siden \(String(year))", systemImage: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral600)
                    }
                }
            }
            Spacer()
        }
    }

    private var stayDetailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Oppholdet")
            if let listing = booking.listing {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: listing.images.first ?? "")) { phase in
                        switch phase {
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                        default: Rectangle().fill(Color.neutral100)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(listing.title)
                            .font(.system(size: 15, weight: .semibold))
                        Text(listing.city)
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                    }
                }
            }
            metaRow(label: "Ankomst", value: booking.checkIn)
            metaRow(label: "Avreise", value: booking.checkOut)
            if let deadlineText = deadlineLabel(booking.approvalDeadline) {
                metaRow(label: "Frist", value: deadlineText, highlight: true)
            }
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Pris")
            HStack {
                Text("Gjesten betaler")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral600)
                Spacer()
                Text("\(booking.totalPrice) kr")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral600)
            }
            HStack {
                Text("Din andel")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(hostPayout) kr")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary600)
            }
            Text("Du får utbetalt din pris. Tunos servicegebyr betales av gjesten på toppen.")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)
        }
    }

    /// Gjesten betaler `total_price` (= host-pris + Tunos servicegebyr på toppen).
    /// Host får sin opprinnelige pris. Formelen speiler `lib/cancellation.ts`.
    private var hostPayout: Int {
        let rate = 0.10
        let fee = Int((Double(booking.totalPrice) * rate / (1 + rate)).rounded())
        return booking.totalPrice - fee
    }

    private var policySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Hva skjer nå?")
            policyBullet("Godkjenner du, belastes gjesten og bookingen bekreftes.")
            policyBullet("Avviser du, frigjøres beløpet umiddelbart og gjesten får beskjed.")
            policyBullet("Svarer du ikke innen fristen, avvises forespørselen automatisk.")
        }
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Button {
                    showDeclineConfirm = true
                } label: {
                    Text(responding == "decline" ? "Avviser…" : "Avvis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                }
                .disabled(responding != nil)

                Button {
                    showApproveConfirm = true
                } label: {
                    Text(responding == "approve" ? "Godkjenner…" : "Godkjenn")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(responding != nil)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.white)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.neutral500)
            .textCase(.uppercase)
    }

    private func metaRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.neutral600)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(highlight ? .orange : .primary)
        }
    }

    private func policyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.primary600)
                .frame(width: 4, height: 4)
                .padding(.top, 7)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.neutral700)
        }
    }

    private func deadlineLabel(_ deadline: String?) -> String? {
        guard let deadline,
              let date = ISO8601DateFormatter.tunoFractional.date(from: deadline) ?? ISO8601DateFormatter.tunoBasic.date(from: deadline)
        else { return nil }
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "Tidsfristen har gått ut" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "Utløper om \(hours) t \(minutes) min"
    }

    private func respond(action: String) async {
        responding = action
        error = nil
        defer { responding = nil }

        guard let token = try? await supabase.auth.session.accessToken,
              let url = URL(string: "\(AppConfig.siteURL)/api/bookings/respond") else {
            error = "Ikke innlogget"
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "bookingId": booking.id,
            "action": action,
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                error = errorMsg
                return
            }
            if status < 200 || status >= 300 {
                error = "Noe gikk galt (status \(status))"
                return
            }
            onResolved(booking.id)
        } catch {
            self.error = "Noe gikk galt"
        }
    }
}

extension ISO8601DateFormatter {
    nonisolated(unsafe) static let tunoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) static let tunoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
