import SwiftUI

/// Offentlig profil-sheet — vises når man trykker på en host/utleier.
/// Kun offentlige felt: navn, avatar, medlem-siden-år, antall annonser, rating.
struct PublicProfileView: View {
    let hostId: String
    var initialName: String? = nil
    var initialAvatar: String? = nil
    var initialJoinedYear: Int? = nil
    var initialListingsCount: Int? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var profile: PublicHostProfile?
    @State private var listingsCount: Int?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar
                    CachedAsyncImage(url: URL(string: profile?.avatarUrl ?? initialAvatar ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.neutral100).overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.neutral400)
                        )
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary600, lineWidth: 3))
                    .padding(.top, 20)

                    VStack(spacing: 6) {
                        Text(profile?.fullName ?? initialName ?? "Utleier")
                            .font(.system(size: 22, weight: .bold))
                        if let joined = profile?.joinedYear ?? initialJoinedYear {
                            Text("Medlem siden \(joined)")
                                .font(.system(size: 14))
                                .foregroundStyle(.neutral500)
                        }
                    }

                    // Stats-rad
                    HStack(spacing: 24) {
                        if let count = listingsCount ?? initialListingsCount {
                            statBlock(value: "\(count)", label: count == 1 ? "annonse" : "annonser")
                        }
                        if let rating = profile?.rating, rating > 0, let reviewCount = profile?.reviewCount, reviewCount > 0 {
                            statBlock(
                                value: String(format: "%.1f", rating),
                                label: reviewCount == 1 ? "anmeldelse" : "anmeldelser",
                                icon: "star.fill"
                            )
                        }
                    }
                    .padding(.vertical, 12)

                    if isLoading {
                        ProgressView()
                            .padding(.top, 20)
                    }

                    Spacer(minLength: 30)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk") { dismiss() }
                }
            }
        }
        .task { await loadProfile() }
    }

    @ViewBuilder
    private func statBlock(value: String, label: String, icon: String? = nil) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 14))
                }
                Text(value).font(.system(size: 18, weight: .bold))
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)
        }
    }

    @MainActor
    private func loadProfile() async {
        do {
            let profiles: [PublicHostProfile] = try await supabase
                .from("profiles")
                .select("id, full_name, avatar_url, joined_year, rating, review_count")
                .eq("id", value: hostId)
                .limit(1)
                .execute()
                .value
            profile = profiles.first

            struct ListingRow: Decodable { let id: String }
            let rows: [ListingRow] = try await supabase
                .from("listings")
                .select("id")
                .eq("host_id", value: hostId)
                .eq("is_active", value: true)
                .execute()
                .value
            listingsCount = rows.count
        } catch {
            print("loadProfile error: \(error)")
        }
        isLoading = false
    }
}

struct PublicHostProfile: Codable {
    let id: String
    let fullName: String?
    let avatarUrl: String?
    let joinedYear: Int?
    let rating: Double?
    let reviewCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case joinedYear = "joined_year"
        case rating
        case reviewCount = "review_count"
    }
}
