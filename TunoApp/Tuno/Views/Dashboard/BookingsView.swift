import SwiftUI

struct BookingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var bookings: [Booking] = []
    @State private var isLoading = true
    @State private var showLogin = false
    @State private var activeTab: BookingTab = .upcoming

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
            } else {
                contentWithTabs
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

    private var contentWithTabs: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().opacity(0.4)
            ScrollView {
                LazyVStack(spacing: 16) {
                    let visible = filteredBookings
                    if visible.isEmpty {
                        emptyState
                            .padding(.top, 80)
                    } else {
                        ForEach(visible) { booking in
                            BookingCard(booking: booking, onCancelled: { updated in
                                if let idx = bookings.firstIndex(where: { $0.id == updated.id }) {
                                    bookings[idx] = updated
                                }
                            })
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(BookingTab.allCases, id: \.self) { tab in
                    let count = bookings.filter { tab.matches($0) }.count
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { activeTab = tab }
                    } label: {
                        HStack(spacing: 6) {
                            Text(tab.title)
                                .font(.system(size: 14, weight: activeTab == tab ? .semibold : .medium))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(activeTab == tab ? Color.white.opacity(0.25) : Color.neutral200.opacity(0.6))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundStyle(activeTab == tab ? .white : .neutral800)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(activeTab == tab ? Color.primary600 : Color.neutral50)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(activeTab == tab ? Color.primary600 : Color.neutral200, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var filteredBookings: [Booking] {
        bookings.filter { activeTab.matches($0) }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: activeTab.emptyIcon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.neutral300)
            Text(activeTab.emptyTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.neutral700)
            Text(activeTab.emptySubtitle)
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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
                .select("*, listing:listings(id, title, city, images, address, lat, lng)")
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

// MARK: - Tabs

enum BookingTab: CaseIterable {
    case upcoming, ongoing, past, cancelled

    var title: String {
        switch self {
        case .upcoming: return "Kommende"
        case .ongoing: return "Pågående"
        case .past: return "Tidligere"
        case .cancelled: return "Avlyst"
        }
    }

    var emptyIcon: String {
        switch self {
        case .upcoming: return "calendar.badge.plus"
        case .ongoing: return "clock"
        case .past: return "clock.arrow.circlepath"
        case .cancelled: return "xmark.circle"
        }
    }

    var emptyTitle: String {
        switch self {
        case .upcoming: return "Ingen kommende bestillinger"
        case .ongoing: return "Ingenting pågående akkurat nå"
        case .past: return "Ingen tidligere opphold"
        case .cancelled: return "Ingen avlyste bestillinger"
        }
    }

    var emptySubtitle: String {
        switch self {
        case .upcoming: return "Plassene du booker, dukker opp her."
        case .ongoing: return "Pågående opphold viser seg her mens du er på plassen."
        case .past: return "Når du har sjekket ut, lagres bestillingene her."
        case .cancelled: return "Avlyste bestillinger arkiveres her."
        }
    }

    func matches(_ booking: Booking) -> Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let start = fmt.date(from: booking.checkIn) ?? today
        let end = fmt.date(from: booking.checkOut) ?? today

        switch self {
        case .cancelled:
            return booking.status == .cancelled
        case .upcoming:
            return booking.status != .cancelled && start > today
        case .ongoing:
            return booking.status != .cancelled && start <= today && end >= today
        case .past:
            return booking.status != .cancelled && end < today
        }
    }
}

// MARK: - BookingCard

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
    @State private var navigateToListing = false
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
        VStack(alignment: .leading, spacing: 0) {
            heroSection
            VStack(alignment: .leading, spacing: 16) {
                titleSection
                Divider().opacity(0.5)
                datesSection
                if let listing = booking.listing, listing.address != nil || listing.city.isEmpty == false {
                    locationSection(listing: listing)
                }
                priceSection
                if booking.status == .cancelled, let refund = booking.refundAmount, refund > 0 {
                    refundedBadge(amount: refund)
                }
                Divider().opacity(0.5)
                ctaRow
                if canReview {
                    Divider().opacity(0.5)
                    reviewSection
                }
                if reviewSubmitted || hasExistingReview == true {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).font(.system(size: 12))
                        Text("Anmeldelse sendt")
                            .font(.system(size: 13)).foregroundStyle(.neutral500)
                    }
                }
                if showCancelConfirm { cancelConfirmSection }
            }
            .padding(16)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200.opacity(0.6), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        .opacity(booking.status == .cancelled ? 0.75 : 1)
        .navigationDestination(item: $chatConversationId) { id in
            ChatView(
                conversationId: id,
                otherUserName: "Utleier",
                listingTitle: booking.listing?.title ?? "",
                listingId: booking.listing?.id,
                listingImage: booking.listing?.images.first
            )
        }
        .navigationDestination(isPresented: $navigateToListing) {
            if let id = booking.listing?.id {
                ListingDetailView(listingId: id)
            } else {
                EmptyView()
            }
        }
        .task {
            if isPastCheckout && booking.status == .confirmed {
                await checkExistingReview()
            }
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if let listing = booking.listing {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: URL(string: listing.images.first ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.neutral100)
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()
                StatusBadge(status: booking.status)
                    .padding(12)
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let listing = booking.listing {
                Text(listing.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .lineLimit(2)
                Text(listing.city)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
            }
        }
    }

    private var datesSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Innsjekk")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.neutral500)
                Text(formatDateLong(booking.checkIn))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                if let t = booking.checkInTimeSnapshot {
                    Text("Fra \(t)")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                }
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.neutral400)
                .padding(.top, 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("Utsjekk")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.neutral500)
                Text(formatDateLong(booking.checkOut))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                if let t = booking.checkOutTimeSnapshot {
                    Text("Innen \(t)")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func locationSection(listing: BookingListing) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14))
                .foregroundStyle(.primary600)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                if let addr = listing.address, !addr.isEmpty {
                    Text(addr)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral800)
                        .lineLimit(2)
                }
                if let lat = listing.lat, let lng = listing.lng {
                    Button {
                        openInAppleMaps(lat: lat, lng: lng, name: listing.title)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Få veibeskrivelse")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary600)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Total")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral800)
                Spacer()
                Text("\(booking.totalPrice) kr")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.neutral900)
            }
            if let breakdown = booking.priceBreakdown, !breakdown.isEmpty {
                let groups = groupBreakdownForBookingsView(breakdown)
                if groups.count > 1 {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                            HStack {
                                Text("\(g.price) kr × \(g.count) døgn (\(bookingPriceSourceLabel(g.source)))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.neutral500)
                                Spacer()
                                Text("\(g.price * g.count) kr")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.neutral500)
                            }
                        }
                    }
                }
            }
        }
    }

    private func refundedBadge(amount: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14))
            Text("Refundert \(amount) kr")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral700)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
        .clipShape(Capsule())
    }

    private var ctaRow: some View {
        HStack(spacing: 8) {
            ctaButton(label: "Vis annonse", icon: "eye") {
                if booking.listing?.id != nil { navigateToListing = true }
            }
            ctaButton(label: openingChat ? "Åpner..." : "Kontakt utleier", icon: "bubble.left.and.bubble.right.fill", loading: openingChat) {
                Task { await openChatWithHost() }
            }
            if canCancel {
                ctaButton(label: "Avbestill", icon: "xmark.circle", destructive: true) {
                    Task { await loadPreview() }
                    showCancelConfirm = true
                }
            } else if isPastCheckout && (booking.status == .confirmed || booking.status == .cancelled) {
                ctaButton(label: "Kvittering", icon: "doc.text") {
                    let text = ReceiptBuilder.buildText(
                        for: booking,
                        guestName: authManager.profile?.fullName
                    )
                    ReceiptBuilder.presentShareSheet(text)
                }
            }
        }
    }

    @ViewBuilder
    private func ctaButton(label: String, icon: String, destructive: Bool = false, loading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if loading {
                    ProgressView().scaleEffect(0.7).frame(height: 16)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(height: 16)
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(destructive ? .red : .neutral800)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.neutral200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }

    @ViewBuilder
    private var cancelConfirmSection: some View {
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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(cancelling)
                Button("Tilbake") {
                    showCancelConfirm = false
                    previewText = nil
                    previewAmount = nil
                    cancelError = nil
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.neutral500)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func openInAppleMaps(lat: Double, lng: Double, name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Plass"
        if let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lng)&q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    private func formatDateLong(_ iso: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "d. MMM"
        out.locale = Locale(identifier: "nb_NO")
        return out.string(from: date)
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
            .padding(.vertical, 5)
            .background(bgColor)
            .foregroundStyle(textColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private var label: String {
        switch status {
        case .pending: return String(localized: "booking.statusPending", defaultValue: "Venter")
        case .requested, .awaiting_host: return String(localized: "booking.statusRequested", defaultValue: "Forespørsel sendt")
        case .awaiting_guest, .awaiting_payment: return String(localized: "booking.statusAwaitingPayment", defaultValue: "Venter på betaling")
        case .confirmed: return String(localized: "booking.statusConfirmed", defaultValue: "Bekreftet")
        case .declined: return String(localized: "booking.statusDeclined", defaultValue: "Avslått")
        case .expired: return String(localized: "booking.statusExpired", defaultValue: "Utløpt")
        case .cancelled: return String(localized: "booking.statusCancelled", defaultValue: "Kansellert")
        }
    }

    private var bgColor: Color {
        switch status {
        case .pending, .requested, .awaiting_host: return .orange
        case .awaiting_guest, .awaiting_payment: return .orange
        case .confirmed: return .primary600
        case .declined, .expired, .cancelled: return .neutral500
        }
    }

    private var textColor: Color {
        Color.white
    }
}
