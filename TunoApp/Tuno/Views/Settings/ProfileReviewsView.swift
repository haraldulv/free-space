import SwiftUI

/// Egen side for mottatte anmeldelser, pushet inn fra "Anmeldelser"-tellingen
/// i Profil-kortet. Tidligere lå dette som en seksjon på selve Profil-tab,
/// men flyttet ut etter TU-74 — anmeldelser er nå "et eget rom" man går inn i.
struct ProfileReviewsView: View {
    let reviews: [ProfileReviewItem]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(reviews) { item in
                    ReviewCard(
                        rating: item.rating,
                        comment: item.comment,
                        createdAt: item.createdAt,
                        reviewerName: item.profile?.fullName,
                        reviewerAvatarUrl: item.profile?.avatarUrl,
                        contextLine: item.listing?.title.map { "For \($0)" },
                        listingImageUrl: item.listing?.images?.first
                    )
                }
            }
            .padding(20)
        }
        .background(Color.neutral50)
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var navigationTitleText: String {
        let count = reviews.count
        if count == 1 { return "1 anmeldelse" }
        return "\(count) anmeldelser"
    }
}
