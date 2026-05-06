import SwiftUI

/// Root-view for host-kalender (Profil → Kalender). Henter alle hostens
/// annonser og lar brukeren velge en — eller går rett til
/// `ProfileCalendarView` hvis det bare finnes én.
struct CalendarRootView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var listings: [Listing] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if listings.isEmpty {
                emptyState
            } else if listings.count == 1, let only = listings.first {
                ProfileCalendarView(listing: only)
            } else {
                listingPicker
            }
        }
        .navigationTitle(listings.count > 1 ? "Velg annonse" : "Kalender")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundStyle(.neutral300)
            Text("Ingen annonser ennå")
                .font(.system(size: 17, weight: .semibold))
            Text("Opprett en annonse for å administrere priser og blokkere datoer.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listingPicker: some View {
        List {
            ForEach(listings) { listing in
                NavigationLink {
                    ProfileCalendarView(listing: listing)
                } label: {
                    HStack(spacing: 12) {
                        CachedAsyncImage(url: URL(string: listing.images?.first ?? "")) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.neutral100)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(listing.internalName ?? listing.title)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            if let city = listing.city {
                                Text(city)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.neutral500)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @MainActor
    private func load() async {
        guard let userId = authManager.currentUser?.id else {
            isLoading = false
            return
        }
        do {
            listings = try await supabase
                .from("listings")
                .select()
                .eq("host_id", value: userId.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            print("CalendarRootView load error: \(error)")
        }
        isLoading = false
    }
}
