import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showLogoutConfirm = false
    @State private var showLogin = false

    var body: some View {
        if !authManager.isAuthenticated {
            // Not logged in — show login prompt
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "person.crop.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.neutral300)

                Text("Logg inn for å se profilen din")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.neutral500)

                Button {
                    showLogin = true
                } label: {
                    Text("Logg inn")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Profil")
            .fullScreenCover(isPresented: $showLogin) {
                LoginView()
            }
        } else {
            loggedInView
        }
    }

    var loggedInView: some View {
        List {
            // Profile header
            Section {
                HStack(spacing: 14) {
                    if let avatarUrl = authManager.profile?.avatarUrl,
                       let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Circle().fill(Color.neutral200)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.primary100)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(String(authManager.displayName.prefix(1)).uppercased())
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.primary600)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(authManager.displayName)
                            .font(.system(size: 17, weight: .semibold))
                        Text(authManager.currentUser?.email ?? "")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral500)
                    }
                }
                .padding(.vertical, 4)
            }

            // Actions
            Section {
                NavigationLink {
                    EditProfileView()
                } label: {
                    Label("Rediger profil", systemImage: "person.fill")
                }

                if authManager.isHost {
                    NavigationLink {
                        MyListingsView()
                    } label: {
                        Label("Mine annonser", systemImage: "house.fill")
                    }
                }

                NavigationLink {
                    // TODO: Become host flow
                    Text("Bli utleier")
                } label: {
                    Label("Bli utleier", systemImage: "plus.circle.fill")
                }
            }

            Section {
                NavigationLink {
                    Text("Innstillinger")
                } label: {
                    Label("Innstillinger", systemImage: "gearshape.fill")
                }
            }

            // Logout
            Section {
                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    Label("Logg ut", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Profil")
        .alert("Logg ut", isPresented: $showLogoutConfirm) {
            Button("Logg ut", role: .destructive) {
                Task { await authManager.signOut() }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Er du sikker på at du vil logge ut?")
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var fullName = ""
    @State private var isSaving = false

    var body: some View {
        Form {
            Section("Personlig informasjon") {
                TextField("Fullt navn", text: $fullName)
            }

            Section {
                Button {
                    Task {
                        isSaving = true
                        try? await supabase
                            .from("profiles")
                            .update(["full_name": fullName])
                            .eq("id", value: authManager.currentUser?.id.uuidString ?? "")
                            .execute()
                        await authManager.loadProfile()
                        isSaving = false
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Lagre endringer")
                    }
                }
            }
        }
        .navigationTitle("Rediger profil")
        .onAppear {
            fullName = authManager.profile?.fullName ?? ""
        }
    }
}

struct MyListingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var listings: [Listing] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if listings.isEmpty {
                Text("Du har ingen annonser ennå")
                    .foregroundStyle(.neutral500)
            } else {
                List(listings) { listing in
                    NavigationLink(value: listing) {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: listing.images?.first ?? "")) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Rectangle().fill(Color.neutral100)
                                }
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(listing.title)
                                    .font(.system(size: 15, weight: .medium))
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(listing.isActive == true ? Color.green : Color.neutral400)
                                        .frame(width: 8, height: 8)
                                    Text(listing.isActive == true ? "Aktiv" : "Inaktiv")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.neutral500)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: Listing.self) { listing in
                    ListingDetailView(listingId: listing.id)
                }
            }
        }
        .navigationTitle("Mine annonser")
        .task {
            guard let userId = authManager.currentUser?.id else {
                isLoading = false
                return
            }
            do {
                listings = try await supabase
                    .from("listings")
                    .select()
                    .eq("host_id", value: userId.uuidString)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            } catch {
                print("Failed: \(error)")
            }
            isLoading = false
        }
    }
}
