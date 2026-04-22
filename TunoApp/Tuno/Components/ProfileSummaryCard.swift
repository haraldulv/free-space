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

    private var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    private var ratingDisplay: String {
        if let rating, reviews > 0 {
            return String(format: "%.1f", rating).replacingOccurrences(of: ".", with: ",")
        }
        return "Ny"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let avatarUrl, let url = URL(string: avatarUrl) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(Color.primary100).overlay(
                                    Text(String(firstName.prefix(1)).uppercased())
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(.primary600)
                                )
                            }
                        } else {
                            Circle().fill(Color.primary100).overlay(
                                Text(String(firstName.prefix(1)).uppercased())
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.primary600)
                            )
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())

                    if isVerified {
                        verifiedBadge
                    }
                }

                VStack(spacing: 2) {
                    Text(firstName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)
                    if let location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                statRow(value: "\(trips)", label: "Turer")
                Divider().padding(.vertical, 2)
                statRow(value: "\(reviews)", label: reviews == 1 ? "Anmeldelse" : "Anmeldelser")
                Divider().padding(.vertical, 2)
                statRow(value: ratingDisplay, label: "Vurdering", icon: reviews > 0 ? "star.fill" : nil)
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

    /// Grønn sjekkmerke-badge med hvit ring. Bygget uten SF `checkmark.seal.fill`
    /// som har interne transparent-punkter — vi lager emblemet manuelt i ZStack
    /// så det aldri blir hvite kanter rundt.
    private var verifiedBadge: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
            Circle()
                .fill(Color.primary600)
                .frame(width: 24, height: 24)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func statRow(value: String, label: String, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.neutral900)
                }
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.neutral900)
            }
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.neutral600)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}
