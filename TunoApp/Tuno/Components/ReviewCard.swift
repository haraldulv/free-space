import SwiftUI

/// Gjenbrukbar review-rad. Airbnb-stil — avatar + navn + relativ dato +
/// 5-stjerne row + kommentar. Brukes på ListingDetailView, ProfileView,
/// og evt. "Se alle anmeldelser"-sheet.
struct ReviewCard: View {
    let rating: Int
    let comment: String
    let createdAt: String?
    let reviewerName: String?
    let reviewerAvatarUrl: String?
    /// Valgfri kontekst-linje, f.eks. annonse-tittel ("Anmeldelse for X").
    /// Vises kun på ProfileView hvor brukeren ser sine mottatte reviews
    /// på tvers av flere annonser.
    var contextLine: String? = nil
    /// Valgfri mini-thumb av annonsen reviewet handler om. Vises til høyre
    /// i headeren, så brukeren raskt ser hvilken plass det refereres til.
    var listingImageUrl: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            stars
            if !comment.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(comment)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral800)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let context = contextLine, !context.isEmpty {
                Text(context)
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.neutral200.opacity(0.6), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                if let dateText = relativeDate {
                    Text(dateText)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
            }
            Spacer()
            listingThumb
        }
    }

    @ViewBuilder
    private var listingThumb: some View {
        if let urlString = listingImageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.neutral100)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.neutral200.opacity(0.6), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let urlString = reviewerAvatarUrl, !urlString.isEmpty, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                initialsCircle
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(Color.primary50)
            Text(initials)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary700)
        }
        .frame(width: 40, height: 40)
    }

    private var stars: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(i <= rating ? Color.yellow : Color.neutral300)
            }
        }
    }

    // MARK: - Computed

    private var displayName: String {
        let trimmed = (reviewerName ?? "").trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Anonym" : trimmed
    }

    private var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    private var relativeDate: String? {
        guard let createdAt, !createdAt.isEmpty else { return nil }
        guard let date = ReviewCard.iso8601.date(from: createdAt) ?? ReviewCard.iso8601Fractional.date(from: createdAt) else {
            return nil
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    nonisolated(unsafe) static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
