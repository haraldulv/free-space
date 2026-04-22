import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pushRouter: PushRouter
    @State private var showLogoutConfirm = false
    @State private var showLogin = false
    @State private var pendingRequestCount: Int = 0
    @State private var navigateToHostRequests = false

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
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.neutral200)
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
                        HostRequestsView()
                    } label: {
                        HStack {
                            Label("Forespørsler", systemImage: "tray.full.fill")
                            if pendingRequestCount > 0 {
                                Spacer()
                                Text("\(pendingRequestCount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    NavigationLink {
                        MyListingsView()
                    } label: {
                        Label("Mine annonser", systemImage: "house.fill")
                    }
                    NavigationLink {
                        EarningsView()
                    } label: {
                        Label("Inntekter", systemImage: "chart.line.uptrend.xyaxis")
                    }
                } else {
                    NavigationLink {
                        BecomeHostView()
                    } label: {
                        Label("Bli utleier", systemImage: "plus.circle.fill")
                    }
                }
            }

            Section {
                NavigationLink {
                    SettingsView()
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
        .navigationDestination(isPresented: $navigateToHostRequests) {
            HostRequestsView()
        }
        .alert("Logg ut", isPresented: $showLogoutConfirm) {
            Button("Logg ut", role: .destructive) {
                Task { await authManager.signOut() }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Er du sikker på at du vil logge ut?")
        }
        .task(id: authManager.currentUser?.id) {
            await loadPendingCount()
        }
        .onAppear {
            // Hvis push allerede har satt type før dette viewet mountes
            // (typisk når tab-switch skjer fra kald push), fanger vi det her.
            if pushRouter.pendingBookingType == "booking_request" {
                navigateToHostRequests = true
                pushRouter.clearBooking()
            }
        }
        .onChange(of: pushRouter.pendingBookingType) { _, newType in
            if newType == "booking_request" {
                navigateToHostRequests = true
                pushRouter.clearBooking()
            }
        }
    }

    private func loadPendingCount() async {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased(),
              authManager.isHost else {
            pendingRequestCount = 0
            return
        }
        do {
            let count = try await supabase
                .from("bookings")
                .select("id", head: true, count: .exact)
                .eq("host_id", value: userId)
                .eq("status", value: "requested")
                .execute()
                .count ?? 0
            pendingRequestCount = count
        } catch {
            print("loadPendingCount error: \(error)")
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var fullName = ""
    @State private var isSaving = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarError: String?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    avatarView
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profilbilde")
                            .font(.system(size: 15, weight: .medium))
                        Text("Klikk for å endre. Maks 5 MB.")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral500)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                if let err = avatarError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }

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
        .onChange(of: selectedPhoto) { _, newItem in
            guard let item = newItem else { return }
            Task { await uploadAvatar(item) }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
            // Avatar-sirkel (clippet) med kamera-badge som sitter UTENFOR clip-maska
            // så den ikke kuttes av sirkelen.
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let urlStr = authManager.profile?.avatarUrl, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.neutral200)
                        }
                    } else {
                        Circle()
                            .fill(Color.primary100)
                            .overlay(
                                Text(String((authManager.profile?.fullName ?? "?").prefix(1)).uppercased())
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.primary600)
                            )
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay {
                    if isUploadingAvatar {
                        Circle().fill(Color.white.opacity(0.7))
                        ProgressView()
                    }
                }

                if !isUploadingAvatar {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.primary600)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
        }
        .disabled(isUploadingAvatar)
    }

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        avatarError = nil
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        guard let raw = try? await item.loadTransferable(type: Data.self) else {
            avatarError = "Kunne ikke lese bildet"
            return
        }
        let compressed = ImageCompression.compressForUpload(raw) ?? raw
        guard let userId = authManager.currentUser?.id.uuidString.lowercased() else {
            avatarError = "Ikke innlogget"
            return
        }

        let fileName = "\(userId)/\(UUID().uuidString.lowercased()).jpg"
        do {
            try await supabase.storage
                .from("avatars")
                .upload(fileName, data: compressed, options: .init(contentType: "image/jpeg", upsert: true))
            let publicURL = try supabase.storage
                .from("avatars")
                .getPublicURL(path: fileName)
            try await supabase
                .from("profiles")
                .update(["avatar_url": publicURL.absoluteString])
                .eq("id", value: userId)
                .execute()
            await authManager.loadProfile()
        } catch {
            avatarError = "Kunne ikke laste opp: \(error.localizedDescription)"
        }
    }
}

struct MyListingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var listings: [Listing] = []
    @State private var isLoading = true
    @State private var showCreateListing = false
    @State private var deleteTarget: Listing?
    @State private var qrTarget: Listing?
    @State private var statsTarget: Listing?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if listings.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "house")
                        .font(.system(size: 40))
                        .foregroundStyle(.neutral300)
                    Text("Du har ingen annonser ennå")
                        .foregroundStyle(.neutral500)
                    Button {
                        showCreateListing = true
                    } label: {
                        Text("Opprett annonse")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.primary600)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                List {
                    ForEach(listings) { listing in
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
                                .opacity(listing.isActive == true ? 1 : 0.5)

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
                                    let range = listing.displayPriceRange
                                    if range.max > 0 {
                                        Text("\(listing.displayPriceText) kr/\(listing.priceUnit?.displayName ?? "natt")")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.primary600)
                                    }
                                }

                                Spacer()

                                // Action buttons
                                HStack(spacing: 12) {
                                    Button {
                                        qrTarget = listing
                                    } label: {
                                        Image(systemName: "qrcode")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.neutral500)
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        statsTarget = listing
                                    } label: {
                                        Image(systemName: "chart.bar")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.neutral500)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTarget = listing
                            } label: {
                                Label("Slett", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Mine annonser")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateListing = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $showCreateListing) {
            CreateListingView(onCreated: { newListing in
                listings.insert(newListing, at: 0)
            })
        }
        .sheet(item: $qrTarget) { listing in
            QRCodeModal(listing: listing)
        }
        .navigationDestination(for: Listing.self) { listing in
            EditListingView(listing: listing, onSaved: { updated in
                if let idx = listings.firstIndex(where: { $0.id == updated.id }) {
                    listings[idx] = updated
                }
            })
        }
        .navigationDestination(item: $statsTarget) { listing in
            HostListingStatsView(listing: listing)
        }
        .alert("Slett annonse?", isPresented: .init(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Slett", role: .destructive) {
                if let listing = deleteTarget {
                    deleteListing(listing)
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Denne handlingen kan ikke angres.")
        }
        .task {
            await loadListings()
        }
    }

    @MainActor
    private func loadListings() async {
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
            print("Failed to load listings: \(error)")
        }
        isLoading = false
    }

    private func deleteListing(_ listing: Listing) {
        Task {
            try? await supabase
                .from("listings")
                .delete()
                .eq("id", value: listing.id)
                .execute()
            deleteTarget = nil
            await loadListings()
        }
    }
}
