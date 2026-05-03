import SwiftUI

/// Airbnb-inspirert listing-kort for host'ens egne annonser. Brukes i
/// Profil → Mine annonser (MyListingsView). Stort 16:9-bilde, status-pill
/// over bildet, og en metadata-rad under med type, spots og pris.
///
/// Ulik `ListingCard.swift` (browsing-kortet) som er fokusert på gjest-
/// fasaden. Dette kortet viser host-spesifikk info: aktiv/inaktiv-status
/// og evt. inntekt sist måned.
struct HostListingCard: View {
    let listing: Listing
    /// Inntekt host har tjent på denne annonsen sist måned. Skjuler banneren
    /// når nil eller 0.
    let monthlyEarnings: Int?

    private var isActive: Bool { listing.isActive == true }

    private var category: ListingCategory { listing.category ?? .parking }

    private var spotCount: Int {
        listing.spotMarkers?.count ?? listing.spots ?? 1
    }

    private var priceText: String {
        let range = listing.displayPriceRange
        guard range.max > 0 else { return "" }
        let unit = listing.priceUnit?.displayName ?? "natt"
        return "\(listing.displayPriceText) kr/\(unit)"
    }

    private var primaryLine: String {
        listing.internalName?.isEmpty == false ? listing.internalName! : listing.title
    }

    private var secondaryLine: String? {
        if let internalName = listing.internalName, !internalName.isEmpty {
            return listing.title
        }
        return [listing.city, listing.region].compactMap { $0 }.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            heroImage
            metadata
        }
        .padding(.bottom, 4)
    }

    // MARK: - Hero image med status-pill

    private var heroImage: some View {
        ZStack(alignment: .topLeading) {
            CachedAsyncImage(url: URL(string: listing.images?.first ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.neutral100)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(isActive ? 1 : 0.55)

            statusPill
                .padding(12)
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.green : Color.neutral500)
                .frame(width: 7, height: 7)
            Text(isActive ? "Listet" : "Inaktiv")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.neutral900)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - Metadata under bildet

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(primaryLine)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.neutral900)
                .lineLimit(1)

            if let secondaryLine, !secondaryLine.isEmpty {
                Text(secondaryLine)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
                    .lineLimit(1)
            }

            metadataRow

            if let monthlyEarnings, monthlyEarnings > 0 {
                earningsBanner(amount: monthlyEarnings)
                    .padding(.top, 4)
            }
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 10) {
            metaItem(
                icon: category.lucideIcon,
                isAsset: true,
                text: category.displayName
            )
            metaSeparator
            metaItem(
                icon: "mappin.circle.fill",
                isAsset: false,
                text: spotCount == 1 ? "1 plass" : "\(spotCount) plasser"
            )
            if !priceText.isEmpty {
                metaSeparator
                metaItem(
                    icon: "tag.fill",
                    isAsset: false,
                    text: priceText
                )
            }
            Spacer(minLength: 0)
        }
    }

    private func metaItem(icon: String, isAsset: Bool, text: String) -> some View {
        HStack(spacing: 4) {
            if isAsset {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 13, height: 13)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 11))
            }
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.neutral700)
    }

    private var metaSeparator: some View {
        Text("·")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.neutral400)
    }

    private func earningsBanner(amount: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
            Text("Tjent \(amount) kr siste 30 dager")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.primary700)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary50)
        .clipShape(Capsule())
    }
}
