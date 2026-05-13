import Foundation

/// Henter og rendrer reviews for listing-detalj, host-profil og egen profil.
/// Speiler `lib/supabase/reviews.ts` på server. To-veis modellen skiller mellom
/// guest- og host-reviews via `reviewer_role`.
@MainActor
final class ReviewService: ObservableObject {
    @Published private(set) var isLoading = false

    /// Reviews skrevet av gjester om en spesifikk listing. Brukes på
    /// ListingDetailView. Filtrerer `reviewer_role = 'guest'` så host-reviews
    /// (som handler om gjesten, ikke annonsen) ikke lekker inn i lista.
    func fetchListingReviews(listingId: String, limit: Int = 50) async -> [Review] {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [Review] = try await supabase
                .from("reviews")
                .select("*, profile:user_id(full_name, avatar_url)")
                .eq("listing_id", value: listingId)
                .eq("reviewer_role", value: "guest")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows
        } catch {
            print("ReviewService.fetchListingReviews error: \(error)")
            return []
        }
    }

    /// Alle reviews der `reviewee_id == userId`. Brukes på "Min profil" for å
    /// vise mottatte anmeldelser uavhengig av om brukeren ble anmeldt som gjest
    /// eller host. Joiner reviewer-profil + listing-tittel.
    func fetchReviewsForUser(_ userId: String, limit: Int = 100) async -> [ProfileReviewItem] {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [ProfileReviewItem] = try await supabase
                .from("reviews")
                .select("*, profile:user_id(full_name, avatar_url), listing:listing_id(title)")
                .eq("reviewee_id", value: userId)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows
        } catch {
            print("ReviewService.fetchReviewsForUser error: \(error)")
            return []
        }
    }

    /// Sjekk om bruker allerede har skrevet review for booking med gitt rolle.
    /// Brukes til å skjule submit-form-en når review allerede finnes.
    func hasReviewed(bookingId: String, role: ReviewerRole) async -> Bool {
        do {
            struct Row: Decodable { let id: String }
            let rows: [Row] = try await supabase
                .from("reviews")
                .select("id")
                .eq("booking_id", value: bookingId)
                .eq("reviewer_role", value: role.rawValue)
                .execute()
                .value
            return !rows.isEmpty
        } catch {
            return false
        }
    }
}

// MARK: - Roller

enum ReviewerRole: String, Codable {
    case guest
    case host
}

// MARK: - Profil-review-item

/// Review vist på "Min profil" — utvider Review med listing-tittel så vi
/// kan vise "Anmeldelse for [annonse-tittel]" som kontekst.
struct ProfileReviewItem: Codable, Identifiable {
    let id: String
    let bookingId: String
    let listingId: String
    let userId: String
    let reviewerRole: String?
    let revieweeId: String?
    let rating: Int
    let comment: String
    let createdAt: String?
    let profile: ReviewProfile?
    let listing: ReviewListing?

    enum CodingKeys: String, CodingKey {
        case id, rating, comment, profile, listing
        case bookingId = "booking_id"
        case listingId = "listing_id"
        case userId = "user_id"
        case reviewerRole = "reviewer_role"
        case revieweeId = "reviewee_id"
        case createdAt = "created_at"
    }
}

struct ReviewListing: Codable {
    let title: String?
}
