import SwiftUI

struct BookingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var bookings: [Booking] = []
    @State private var isLoading = true
    @State private var showLogin = false

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                AuthPromptView(
                    icon: "calendar",
                    message: "Logg inn for å se bestillingene dine",
                    showLogin: $showLogin
                )
            } else if isLoading {
                ProgressView()
            } else if bookings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundStyle(.neutral300)
                    Text("Ingen bestillinger")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.neutral500)
                    Text("Bestillingene dine vil vises her")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(bookings) { booking in
                            BookingCard(booking: booking, onCancelled: { updated in
                                if let idx = bookings.firstIndex(where: { $0.id == updated.id }) {
                                    bookings[idx] = updated
                                }
                            })
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Bestillinger")
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .task {
            await loadBookings()
        }
    }

    private func loadBookings() async {
        guard let userId = authManager.currentUser?.id else {
            isLoading = false
            return
        }
        do {
            bookings = try await supabase
                .from("bookings")
                .select("*, listing:listings(id, title, city, images)")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            print("Failed to load bookings: \(error)")
        }
        isLoading = false
    }
}

struct BookingCard: View {
    let booking: Booking
    var onCancelled: ((Booking) -> Void)?
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var chatService = ChatService()
    @State private var showCancelConfirm = false
    @State private var cancelling = false
    @State private var previewText: String?
    @State private var previewAmount: Int?
    @State private var cancelError: String?
    @State private var openingChat = false
    @State private var chatConversationId: String?
    @State private var reviewRating: Int = 0
    @State private var reviewComment: String = ""
    @State private var reviewSubmitting = false
    @State private var reviewSubmitted = false
    @State private var hasExistingReview: Bool?
    @State private var reviewError: String?

    private var canCancel: Bool {
        booking.status == .pending || booking.status == .confirmed
    }

    private var isPastCheckout: Bool {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let checkOutDate = fmt.date(from: booking.checkOut) else { return false }
        return checkOutDate < Calendar.current.startOfDay(for: Date())
    }

    private var canReview: Bool {
        booking.status == .confirmed && isPastCheckout && hasExistingReview == false && !reviewSubmitted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let listing = booking.listing {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: listing.images.first ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(Color.neutral100)
                        }
                    }
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Text(listing.city)
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                    }

                    Spacer()
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(booking.checkIn) → \(booking.checkOut)")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral600)
                    if let t = booking.checkInTimeSnapshot {
                        Text("Innsjekk fra \(t)")
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral400)
                    }
                    Text("\(booking.totalPrice) kr")
                        .font(.system(size: 15, weight: .bold))
                }

                Spacer()

                StatusBadge(status: booking.status)
            }

            if let breakdown = booking.priceBreakdown, !breakdown.isEmpty {
                let groups = groupBreakdownForBookingsView(breakdown)
                if groups.count > 1 {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                            HStack {
                                Text("\(g.price) kr × \(g.count) \(g.count == 1 ? "natt" : "netter")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.neutral600)
                                + Text(" (\(bookingPriceSourceLabel(g.source)))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.neutral400)
                                Spacer()
                                Text("\(g.price * g.count) kr")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.neutral600)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            if booking.status == .cancelled, let refund = booking.refundAmount, refund > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 14))
                    Text("Refundert \(refund) kr")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral600)
                }
            }

            HStack(spacing: 16) {
                Button {
                    Task { await openChatWithHost() }
                } label: {
                    HStack(spacing: 6) {
                        if openingChat {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 13))
                        }
                        Text("Send melding til utleier")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(Color.primary600)
                }
                .disabled(openingChat)

                Spacer()
            }

            if canReview {
                reviewSection
            }

            if reviewSubmitted || hasExistingReview == true {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow).font(.system(size: 12))
                    Text("Anmeldelse sendt")
                        .font(.system(size: 13)).foregroundStyle(.neutral500)
                }
            }

            if canCancel {
                if !showCancelConfirm {
                    Button {
                        Task { await loadPreview() }
                        showCancelConfirm = true
                    } label: {
                        Text("Kanseller bestilling")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if let text = previewText {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 16))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(text)
                                        .font(.system(size: 13, weight: .medium))
                                    if let amt = previewAmount {
                                        Text("Refusjon: \(amt) kr av \(booking.totalPrice) kr")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.neutral500)
                                    }
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        if let err = cancelError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                        }

                        HStack(spacing: 12) {
                            Button {
                                Task { await performCancel() }
                            } label: {
                                Text(cancelling ? "Kansellerer..." : "Bekreft kansellering")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                            .disabled(cancelling)

                            Button("Avbryt") {
                                showCancelConfirm = false
                                previewText = nil
                                previewAmount = nil
                                cancelError = nil
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral500)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .opacity(booking.status == .cancelled ? 0.6 : 1)
        .navigationDestination(item: $chatConversationId) { id in
            ChatView(
                conversationId: id,
                otherUserName: "Utleier",
                listingTitle: booking.listing?.title ?? "",
                listingId: booking.listing?.id,
                listingImage: booking.listing?.images.first
            )
        }
        .task {
            if isPastCheckout && booking.status == .confirmed {
                await checkExistingReview()
            }
        }
    }

    private func openChatWithHost() async {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased(),
              let listingId = booking.listing?.id else { return }
        openingChat = true
        let convoId = await chatService.getOrCreateConversation(
            listingId: listingId,
            guestId: userId,
            hostId: booking.hostId
        )
        openingChat = false
        if let convoId { chatConversationId = convoId }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.vertical, 2)
            Text("Hvordan var oppholdet?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral900)

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        reviewRating = star
                    } label: {
                        Image(systemName: star <= reviewRating ? "star.fill" : "star")
                            .font(.system(size: 24))
                            .foregroundStyle(star <= reviewRating ? .yellow : .neutral300)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Kommentar (valgfritt)", text: $reviewComment, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if let err = reviewError {
                Text(err).font(.system(size: 12)).foregroundStyle(.red)
            }

            Button {
                Task { await submitReview() }
            } label: {
                Text(reviewSubmitting ? "Sender..." : "Send anmeldelse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(reviewRating > 0 ? Color.primary600 : Color.neutral300)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(reviewRating == 0 || reviewSubmitting)
        }
    }

    private func checkExistingReview() async {
        guard hasExistingReview == nil else { return }
        do {
            struct ReviewRow: Decodable { let id: String }
            let rows: [ReviewRow] = try await supabase
                .from("reviews")
                .select("id")
                .eq("booking_id", value: booking.id)
                .eq("reviewer_role", value: "guest")
                .execute()
                .value
            hasExistingReview = !rows.isEmpty
        } catch {
            hasExistingReview = false
        }
    }

    private func submitReview() async {
        guard reviewRating > 0,
              let userId = authManager.currentUser?.id.uuidString.lowercased(),
              let listingId = booking.listing?.id else { return }
        reviewSubmitting = true
        reviewError = nil
        do {
            struct ReviewInsert: Encodable {
                let booking_id: String
                let listing_id: String
                let user_id: String
                let reviewer_role: String
                let reviewee_id: String
                let rating: Int
                let comment: String
            }
            let input = ReviewInsert(
                booking_id: booking.id,
                listing_id: listingId,
                user_id: userId,
                reviewer_role: "guest",
                reviewee_id: booking.hostId,
                rating: reviewRating,
                comment: reviewComment.trimmingCharacters(in: .whitespaces)
            )
            try await supabase.from("reviews").insert(input).execute()
            reviewSubmitted = true
        } catch {
            reviewError = "Kunne ikke sende anmeldelse. Prøv igjen."
        }
        reviewSubmitting = false
    }

    private func loadPreview() async {
        guard let token = try? await supabase.auth.session.accessToken else { return }
        guard let url = URL(string: "\(AppConfig.siteURL)/api/bookings/cancel") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "bookingId": booking.id,
            "preview": true,
        ])
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        previewText = json["policyLabel"] as? String
        previewAmount = json["refundAmount"] as? Int
    }

    private func performCancel() async {
        cancelling = true
        cancelError = nil
        guard let token = try? await supabase.auth.session.accessToken else {
            cancelError = "Ikke innlogget"
            cancelling = false
            return
        }
        guard let url = URL(string: "\(AppConfig.siteURL)/api/bookings/cancel") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "bookingId": booking.id,
        ])
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            cancelError = "Noe gikk galt"
            cancelling = false
            return
        }
        if let error = json["error"] as? String {
            cancelError = error
            cancelling = false
            return
        }
        var updated = booking
        updated.status = .cancelled
        updated.refundAmount = json["refundAmount"] as? Int
        onCancelled?(updated)
        cancelling = false
    }
}

private func groupBreakdownForBookingsView(_ breakdown: [NightlyPriceEntry]) -> [(price: Int, source: String, count: Int)] {
    var result: [(price: Int, source: String, count: Int)] = []
    for entry in breakdown {
        if let last = result.last, last.price == entry.price, last.source == entry.source {
            result[result.count - 1].count += 1
        } else {
            result.append((price: entry.price, source: entry.source, count: 1))
        }
    }
    return result
}

private func bookingPriceSourceLabel(_ source: String) -> String {
    switch source {
    case "weekend": return "helg"
    case "season": return "sesong"
    case "override": return "tilpasset"
    default: return "standard"
    }
}

struct StatusBadge: View {
    let status: BookingStatus

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bgColor)
            .foregroundStyle(textColor)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .pending: return String(localized: "booking.statusPending", defaultValue: "Venter")
        case .requested: return String(localized: "booking.statusRequested", defaultValue: "Forespørsel sendt")
        case .confirmed: return String(localized: "booking.statusConfirmed", defaultValue: "Bekreftet")
        case .cancelled: return String(localized: "booking.statusCancelled", defaultValue: "Kansellert")
        }
    }

    private var bgColor: Color {
        switch status {
        case .pending, .requested: return .orange.opacity(0.15)
        case .confirmed: return .green.opacity(0.15)
        case .cancelled: return .red.opacity(0.15)
        }
    }

    private var textColor: Color {
        switch status {
        case .pending, .requested: return .orange
        case .confirmed: return .green
        case .cancelled: return .red
        }
    }
}
