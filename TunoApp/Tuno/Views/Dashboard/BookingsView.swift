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
                            BookingCard(booking: booking)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Listing image + title
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

            // Dates + status
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
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
