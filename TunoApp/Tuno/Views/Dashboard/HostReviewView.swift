import SwiftUI

/// Standalone host-review-form. Vises etter en confirmed booking er sjekket ut.
/// Tilgjengelig via push-deep-link når `review_reminder` med `reviewerRole=host`
/// mottas — se PushNotificationManager.
///
/// Speiler guest-flowen i BookingsView (`reviewSection` linje 579), bare med
/// `reviewer_role = "host"` og `reviewee_id = booking.user_id`.
struct HostReviewView: View {
    let bookingId: String

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var booking: Booking?
    @State private var isLoading = true
    @State private var hasExistingReview = false
    @State private var reviewRating: Int = 0
    @State private var reviewComment: String = ""
    @State private var reviewSubmitting = false
    @State private var reviewSubmitted = false
    @State private var reviewError: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Anmeld gjest")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Lukk") { dismiss() }
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if booking == nil {
            errorState(message: "Fant ikke bookingen.")
        } else if hasExistingReview || reviewSubmitted {
            doneState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    guestHeader
                    Divider()
                    reviewForm
                }
                .padding(20)
            }
        }
    }

    private var guestHeader: some View {
        HStack(spacing: 14) {
            if let booking {
                if let url = booking.guest?.avatarUrl.flatMap({ URL(string: $0) }) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.primary50)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    Circle().fill(Color.primary50).frame(width: 56, height: 56)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.guest?.fullName ?? "Gjest")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text("Sjekket ut \(formatDate(booking.checkOut))")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }
            }
            Spacer()
        }
    }

    private var reviewForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hvordan var oppholdet?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.neutral900)
            Text("Anmeldelsen din hjelper andre verter med å vurdere gjester. Den blir synlig først når begge har sendt inn, eller etter 14 dager.")
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        reviewRating = star
                    } label: {
                        Image(systemName: star <= reviewRating ? "star.fill" : "star")
                            .font(.system(size: 30))
                            .foregroundStyle(star <= reviewRating ? .yellow : .neutral300)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)

            TextField("Kommentar (valgfritt)", text: $reviewComment, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let err = reviewError {
                Text(err).font(.system(size: 13)).foregroundStyle(.red)
            }

            Button {
                Task { await submit() }
            } label: {
                Text(reviewSubmitting ? "Sender..." : "Send anmeldelse")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(reviewRating > 0 ? Color.primary600 : Color.neutral300)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(reviewRating == 0 || reviewSubmitting)
        }
    }

    private var doneState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.primary600)
            Text("Takk for anmeldelsen!")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Vi viser den til gjesten når de selv har anmeldt deg, eller etter 14 dager.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Button {
                dismiss()
            } label: {
                Text("Lukk")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .padding(32)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
        }
        .padding(32)
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [Booking] = try await supabase
                .from("bookings")
                .select("*, listing:listing_id(*), guest:user_id(full_name, avatar_url, rating, review_count, joined_year)")
                .eq("id", value: bookingId)
                .limit(1)
                .execute()
                .value
            booking = rows.first
            if booking != nil {
                let service = ReviewService()
                hasExistingReview = await service.hasReviewed(bookingId: bookingId, role: .host)
            }
        } catch {
            print("HostReviewView.load error: \(error)")
        }
    }

    private func submit() async {
        guard reviewRating > 0,
              let booking,
              let userId = authManager.currentUser?.id.uuidString.lowercased() else { return }
        reviewSubmitting = true
        reviewError = nil
        defer { reviewSubmitting = false }
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
                listing_id: booking.listingId,
                user_id: userId,
                reviewer_role: "host",
                reviewee_id: booking.userId,
                rating: reviewRating,
                comment: reviewComment.trimmingCharacters(in: .whitespaces)
            )
            try await supabase.from("reviews").insert(input).execute()
            reviewSubmitted = true
        } catch {
            reviewError = "Kunne ikke sende anmeldelse. Prøv igjen."
        }
    }

    private func formatDate(_ iso: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "d. MMM yyyy"
        out.locale = Locale(identifier: "nb_NO")
        return out.string(from: date)
    }
}
