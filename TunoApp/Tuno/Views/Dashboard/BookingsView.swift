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
    @State private var showCancelConfirm = false
    @State private var cancelling = false
    @State private var previewText: String?
    @State private var previewAmount: Int?
    @State private var cancelError: String?

    private var canCancel: Bool {
        booking.status == .pending || booking.status == .confirmed
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
                    Text("\(booking.totalPrice) kr")
                        .font(.system(size: 15, weight: .bold))
                }

                Spacer()

                StatusBadge(status: booking.status)
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
        case .pending: return "Venter"
        case .confirmed: return "Bekreftet"
        case .cancelled: return "Kansellert"
        }
    }

    private var bgColor: Color {
        switch status {
        case .pending: return .orange.opacity(0.15)
        case .confirmed: return .green.opacity(0.15)
        case .cancelled: return .red.opacity(0.15)
        }
    }

    private var textColor: Color {
        switch status {
        case .pending: return .orange
        case .confirmed: return .green
        case .cancelled: return .red
        }
    }
}
