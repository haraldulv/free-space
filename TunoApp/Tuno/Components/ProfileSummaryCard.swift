import SwiftUI

/// Profil-oppsummering-kort øverst i Profil-tab. Viser avatar (m. evt. verified-
/// emblem), fornavn, og tre statistikker (Turer / Anmeldelser / Rating).
struct ProfileSummaryCard: View {
    let name: String
    let avatarUrl: String?
    let location: String?
    let trips: Int
    let reviews: Int
    let rating: Double?
    let isVerified: Bool
    /// Valgfri callback for tap på "Anmeldelser"-stat-raden. Når satt,
    /// overlayes en gjennomsiktig knapp som tar over tap-arealet for den
    /// raden — resten av kortet beholder sin opprinnelige tap-bobling
    /// (typisk en NavigationLink til EditProfileView i parent).
    var onReviewsTap: (() -> Void)? = nil

    private var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    private var hasRating: Bool {
        if let rating, rating > 0, reviews > 0 { return true }
        return false
    }

    private var ratingDisplay: String {
        if let rating, hasRating {
            return String(format: "%.1f", rating).replacingOccurrences(of: ".", with: ",")
        }
        return "Ny"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(spacing: 12) {
                Group {
                    if let avatarUrl, let url = URL(string: avatarUrl) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.primary100).overlay(
                                Text(String(firstName.prefix(1)).uppercased())
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundStyle(.primary600)
                            )
                        }
                    } else {
                        Circle().fill(Color.primary100).overlay(
                            Text(String(firstName.prefix(1)).uppercased())
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.primary600)
                        )
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) {
                    if isVerified {
                        verifiedBadge
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(spacing: 2) {
                    Text(firstName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)
                    if let location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral500)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                statRow(value: "\(trips)", label: trips == 1 ? "Booking" : "Bookinger")
                Divider().padding(.vertical, 2)
                statRow(value: "\(reviews)", label: reviews == 1 ? "Anmeldelse" : "Anmeldelser")
                    .overlay(reviewsTapOverlay)
                Divider().padding(.vertical, 2)
                statRow(
                    value: ratingDisplay,
                    label: "Vurdering",
                    icon: hasRating ? "star.fill" : nil
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20).stroke(Color.neutral200.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }

    /// Blå "verifisert"-badge bygget som to lagrede seal-symboler (hvit halo +
    /// blå fyll) med en hvit sjekkmerke oppå. Inspirert av Twitter/X's verifisert-
    /// badge og Airbnbs shield-emblem — men i Tunos sekundære blåfarge.
    private var verifiedBadge: some View {
        ZStack {
            Image(systemName: "seal.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white)
            Image(systemName: "seal.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color(hex: "#1d9bf0"))
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var reviewsTapOverlay: some View {
        if let onReviewsTap {
            Button(action: onReviewsTap) {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func statRow(value: String, label: String, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.neutral900)
                }
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.neutral900)
            }
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.neutral600)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}
