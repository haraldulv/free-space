import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var listingService = ListingService()
    @State private var query = ""
    @State private var selectedCategory: ListingCategory? = nil
    @State private var selectedVehicle: VehicleType = .motorhome

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search header
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.neutral400)
                        TextField("Søk etter sted eller adresse...", text: $query)
                            .textFieldStyle(.plain)
                            .submitLabel(.search)
                            .onSubmit { performSearch() }

                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.neutral400)
                            }
                        }
                    }
                    .padding(14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                    // Vehicle type filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(VehicleType.allCases, id: \.self) { type in
                                FilterChip(
                                    label: type.displayName,
                                    icon: type.icon,
                                    isSelected: selectedVehicle == type
                                ) {
                                    selectedVehicle = type
                                    performSearch()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.white)

                // Results
                if listingService.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if listingService.searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.neutral300)
                        Text("Ingen resultater")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.neutral500)
                        Text("Prøv å søke etter et annet sted")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral400)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(listingService.searchResults) { listing in
                                NavigationLink(value: listing) {
                                    ListingCard(listing: listing)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.neutral50)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.neutral600)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Søk")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .navigationDestination(for: Listing.self) { listing in
                ListingDetailView(listingId: listing.id)
            }
            .task {
                await listingService.search(vehicleType: selectedVehicle)
            }
        }
    }

    private func performSearch() {
        Task {
            await listingService.search(
                query: query.isEmpty ? nil : query,
                vehicleType: selectedVehicle
            )
        }
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary600 : .white)
            .foregroundStyle(isSelected ? .white : .neutral700)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.neutral200, lineWidth: 1)
            )
        }
    }
}
