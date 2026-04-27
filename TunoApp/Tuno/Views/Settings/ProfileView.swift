import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pushRouter: PushRouter
    @EnvironmentObject var profileStats: ProfileStatsStore
    @State private var showLogoutConfirm = false
    @State private var showLogin = false
    @State private var showRegister = false
    @State private var navigateToHostRequests = false
    @State private var navigateToNotifications = false
    @State private var showSelfProfile = false
    @State private var showBecomeHost = false

    var body: some View {
        if !authManager.isAuthenticated {
            loggedOutView
        } else {
            loggedInView
        }
    }

    // MARK: - Logged-out

    private var loggedOutView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Lekent ikon-hero — matcher Tuno-stil med store grønne sirkler
            ZStack {
                Circle()
                    .fill(Color.primary50)
                    .frame(width: 140, height: 140)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.primary600)
            }
            .padding(.bottom, 24)

            VStack(spacing: 8) {
                Text("Velkommen til Tuno")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.neutral900)

                Text("Logg inn for å bestille plasser eller leie ut din egen")
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral500)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 32)

            VStack(spacing: 12) {
                Button { showLogin = true } label: {
                    Text("Logg inn")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button { showRegister = true } label: {
                    Text("Opprett konto")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary700)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primary50)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .navigationTitle("Profil")
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .fullScreenCover(isPresented: $showRegister) {
            RegisterView()
        }
    }

    // MARK: - Logged-in

    private var loggedInView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileSummaryCard(
                    name: authManager.profile?.fullName ?? authManager.displayName,
                    avatarUrl: authManager.profile?.avatarUrl,
                    location: authManager.profile?.location,
                    trips: profileStats.tripCount,
                    reviews: profileStats.reviewCount,
                    rating: profileStats.rating,
                    isVerified: authManager.isHost && (authManager.profile?.stripeOnboardingComplete ?? false)
                )
                .onTapGesture { showSelfProfile = true }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if authManager.isHost {
                    NavigationLink {
                        EarningsView()
                    } label: {
                        HostInntektCard(
                            monthName: currentMonthName,
                            netIncome: profileStats.monthlyNet,
                            bookingCount: profileStats.monthlyBookings,
                            recentMonths: profileStats.recentMonthsEarnings
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                if authManager.isHost {
                    hostSection
                        .padding(.horizontal, 16)
                }

                accountSection
                    .padding(.horizontal, 16)

                if !authManager.isHost {
                    becomeHostCard
                        .padding(.horizontal, 16)
                }

                logoutRow
                    .padding(.horizontal, 16)

                Spacer(minLength: 40)
            }
        }
        .background(Color.neutral50)
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigateToNotifications = true
                } label: {
                    Image(systemName: "bell")
                        .foregroundStyle(.neutral900)
                        .overlay(alignment: .topTrailing) {
                            if profileStats.unreadNotifications > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                    .offset(x: 4, y: -2)
                            }
                        }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToHostRequests) {
            HostRequestsView()
        }
        .navigationDestination(isPresented: $navigateToNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showSelfProfile) {
            if let userId = authManager.currentUser?.id {
                PublicProfileView(
                    hostId: userId.uuidString.lowercased(),
                    initialName: authManager.profile?.fullName,
                    initialAvatar: authManager.profile?.avatarUrl,
                    initialJoinedYear: authManager.profile?.joinedYear,
                    initialListingsCount: nil
                )
            }
        }
        .alert("Logg ut", isPresented: $showLogoutConfirm) {
            Button("Logg ut", role: .destructive) {
                Task { await authManager.signOut() }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Er du sikker på at du vil logge ut?")
        }
        .task {
            // Bakgrunns-refresh — cached verdier vises med én gang fra storen,
            // så ingen 0 → 3 flicker. Nye verdier kommer uten visuelt sprang.
            guard let userId = authManager.currentUser?.id.uuidString.lowercased() else { return }
            await profileStats.refresh(userId: userId, isHost: authManager.isHost)
        }
        .onAppear {
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
        .fullScreenCover(isPresented: $showBecomeHost) {
            // Bli utleier-flowen (Stripe-onboarding eller direkte til wizarden) skal også
            // dekke tab-baren, ikke pushes inn i nav-stacken.
            NavigationStack {
                BecomeHostView()
            }
        }
    }

    // MARK: - Sections

    private var hostSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Vertskap")

            menuRow(
                icon: "tray.full.fill",
                label: "Forespørsler",
                badge: profileStats.pendingRequestCount > 0 ? "\(profileStats.pendingRequestCount)" : nil,
                destination: AnyView(HostRequestsView())
            )
            menuRow(
                icon: "calendar",
                label: "Kalender",
                destination: AnyView(CalendarRootView())
            )
            menuRow(
                icon: "house.fill",
                label: "Mine annonser",
                destination: AnyView(MyListingsView())
            )
            menuRow(
                icon: "chart.line.uptrend.xyaxis",
                label: "Inntekter",
                destination: AnyView(EarningsView())
            )
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200.opacity(0.5), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var accountSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Konto")
            menuRow(
                icon: "person.fill",
                label: "Rediger profil",
                destination: AnyView(EditProfileView())
            )
            menuRow(
                icon: "gearshape.fill",
                label: "Innstillinger",
                destination: AnyView(SettingsView())
            )
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200.opacity(0.5), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var becomeHostCard: some View {
        Button {
            showBecomeHost = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.primary100).frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.primary600)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bli utleier")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text("Det er lett å komme i gang og tjene ekstra penger.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral400)
            }
            .padding(16)
            .background(Color.primary50)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var logoutRow: some View {
        Button {
            showLogoutConfirm = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15))
                    .foregroundStyle(.red)
                    .frame(width: 24)
                Text("Logg ut")
                    .font(.system(size: 15))
                    .foregroundStyle(.red)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func menuRow(icon: String, label: String, badge: String? = nil, destination: AnyView) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral600)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral900)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral400)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var currentMonthName: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "nb_NO")
        df.dateFormat = "MMMM yyyy"
        return df.string(from: Date()).capitalized
    }
}

// MARK: - EditProfileView (uendret fra tidligere — bio + avatar-crop)

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var isSaving = false
    @State private var showImagePicker = false
    @State private var isUploadingAvatar = false
    @State private var avatarError: String?
    @State private var saveError: String?
    @State private var showSavedBanner = false

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
                TextField("Sted (f.eks. Oslo, Norge)", text: $location)
                    .textInputAutocapitalization(.words)
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dette vises til gjester som trykker på profilen din. Hold det kort og vennlig.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                    TextEditor(text: $bio)
                        .frame(minHeight: 100)
                        .onChange(of: bio) { _, new in
                            if new.count > 500 { bio = String(new.prefix(500)) }
                        }
                    HStack {
                        Spacer()
                        Text("\(bio.count) / 500")
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral400)
                    }
                }
            } header: {
                Text("Om deg")
            }

            if let err = saveError {
                Section {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await saveProfile() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(.primary600)
                            Text("Lagrer …").foregroundStyle(.neutral500)
                        } else {
                            Text("Lagre endringer")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary600)
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("Rediger profil")
        .overlay(alignment: .top) {
            if showSavedBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                    Text("Lagret!")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color(hex: "#10b981"))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            fullName = authManager.profile?.fullName ?? ""
            location = authManager.profile?.location ?? ""
        }
        .task {
            guard let userId = authManager.currentUser?.id else { return }
            do {
                struct BioRow: Decodable { let bio: String? }
                let rows: [BioRow] = try await supabase
                    .from("profiles")
                    .select("bio")
                    .eq("id", value: userId.uuidString.lowercased())
                    .limit(1)
                    .execute()
                    .value
                bio = rows.first?.bio ?? ""
            } catch {
                print("load bio: \(error)")
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImageCropPicker { picked in
                Task { await uploadAvatar(picked) }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        Button {
            showImagePicker = true
        } label: {
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
        .buttonStyle(.plain)
        .disabled(isUploadingAvatar)
    }

    @MainActor
    private func saveProfile() async {
        guard let userId = authManager.currentUser?.id else {
            saveError = "Ikke innlogget"
            return
        }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        struct Payload: Encodable {
            let full_name: String
            let bio: String?
            let location: String?
        }
        let trimmedBio = bio.trimmingCharacters(in: .whitespaces)
        let trimmedLoc = location.trimmingCharacters(in: .whitespaces)
        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            saveError = "Navn kan ikke være tomt"
            return
        }

        do {
            try await supabase
                .from("profiles")
                .update(Payload(
                    full_name: trimmedName,
                    bio: trimmedBio.isEmpty ? nil : trimmedBio,
                    location: trimmedLoc.isEmpty ? nil : trimmedLoc
                ))
                .eq("id", value: userId.uuidString)
                .execute()
            await authManager.loadProfile()
            withAnimation { showSavedBanner = true }
            // Vent 1,0 s så bannerenslik user faktisk ser det, og naviger tilbake
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        } catch {
            saveError = "Kunne ikke lagre: \(error.localizedDescription)"
        }
    }

    private func uploadAvatar(_ image: UIImage) async {
        avatarError = nil
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            avatarError = "Kunne ikke lese bildet"
            return
        }
        let compressed = ImageCompression.compressForUpload(jpegData) ?? jpegData
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

// MARK: - Mine annonser

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
                        NavigationLink {
                            EditListingView(listing: listing, onSaved: { updated in
                                if let idx = listings.firstIndex(where: { $0.id == updated.id }) {
                                    listings[idx] = updated
                                }
                            })
                        } label: {
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
                                    Text(listing.internalName ?? listing.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .lineLimit(1)
                                    if let internalName = listing.internalName, !internalName.isEmpty {
                                        Text(listing.title)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.neutral500)
                                            .lineLimit(1)
                                    }
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
        .fullScreenCover(isPresented: $showCreateListing) {
            // Wizarden i sin egen NavigationStack — pakker for å bevare navigationTitle/toolbar.
            NavigationStack {
                CreateListingView(onCreated: { newListing in
                    listings.insert(newListing, at: 0)
                })
            }
        }
        .sheet(item: $qrTarget) { listing in
            QRCodeModal(listing: listing)
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
