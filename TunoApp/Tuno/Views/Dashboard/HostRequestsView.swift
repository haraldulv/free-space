import SwiftUI

struct HostRequestsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var requests: [Booking] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var responding: String? = nil
    @State private var declineConfirmId: String? = nil

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
                            requestCard(booking)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Forespørsler")
        .task { await load() }
    }

    private func requestCard(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let listing = booking.listing {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: listing.images.first ?? "")) { phase in
                        switch phase {
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                        default: Rectangle().fill(Color.neutral100)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(listing.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        if let guestName = booking.guest?.fullName {
                            Text(guestName)
                                .font(.system(size: 13))
                                .foregroundStyle(.neutral500)
                        }
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
            }

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

            if let err = error {
                Text(err).font(.system(size: 12)).foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await respond(to: booking, action: "approve") }
                } label: {
                    Text(responding == booking.id ? "Godkjenner…" : "Godkjenn")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(responding != nil)

                Button {
                    declineConfirmId = booking.id
                } label: {
                    Text("Avvis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                }
                .disabled(responding != nil)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .alert(
            "Avvise forespørselen?",
            isPresented: Binding(get: { declineConfirmId == booking.id }, set: { if !$0 { declineConfirmId = nil } })
        ) {
            Button("Avvis", role: .destructive) {
                Task { await respond(to: booking, action: "decline") }
            }
            Button("Avbryt", role: .cancel) { }
        } message: {
            Text("Beløpet frigjøres til gjesten.")
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
            requests = try await supabase
                .from("bookings")
                .select("*, listing:listings(id, title, city, images), guest:user_id(full_name, avatar_url)")
                .eq("host_id", value: userId)
                .eq("status", value: "requested")
                .order("approval_deadline", ascending: true)
                .execute()
                .value
        } catch {
            print("Failed to load host requests: \(error)")
            self.error = "Kunne ikke laste forespørsler"
        }
        isLoading = false
    }

    private func respond(to booking: Booking, action: String) async {
        responding = booking.id
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
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                error = errorMsg
                return
            }
            requests.removeAll { $0.id == booking.id }
        } catch {
            self.error = "Noe gikk galt"
        }
    }
}

extension ISO8601DateFormatter {
    static let tunoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let tunoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
