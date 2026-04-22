import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pushRouter: PushRouter
    @State private var showLogoutConfirm = false
    @State private var showLogin = false
    @State private var pendingRequestCount: Int = 0
    @State private var unreadNotifications: Int = 0
    @State private var tripCount: Int = 0
    @State private var reviewCount: Int = 0
    @State private var monthlyNet: Int = 0
    @State private var monthlyBookings: Int = 0
    @State private var navigateToHostRequests = false
    @State private var navigateToNotifications = false
    @State private var showSelfProfile = false

    var body: some View {
        if !authManager.isAuthenticated {
            loggedOutView
        } else {
            loggedInView
        }
    }

    // MARK: - Logged-out

    private var loggedOutView: some View {
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
    }

    // MARK: - Logged-in

    private var loggedInView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileSummaryCard(
                    name: authManager.profile?.fullName ?? authManager.displayName,
                    avatarUrl: authManager.profile?.avatarUrl,
                    location: nil,
                    trips: tripCount,
                    reviews: reviewCount,
                    joinedYear: authManager.profile?.joinedYear,
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
                            netIncome: monthlyNet,
                            bookingCount: monthlyBookings,
                            trend: nil
                        )
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
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.neutral900)
                            .frame(width: 36, height: 36)
                            .background(Color.neutral100)
                            .clipShape(Circle())
                        if unreadNotifications > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                .offset(x: 2, y: -2)
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
        .task(id: authManager.currentUser?.id) {
            await loadAll()
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
    }

    // MARK: - Sections

    private var hostSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Vertskap")

            menuRow(
                icon: "tray.full.fill",
                label: "Forespørsler",
                badge: pendingRequestCount > 0 ? "\(pendingRequestCount)" : nil,
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
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200, lineWidth: 1))
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
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200, lineWidth: 1))
    }

    private var becomeHostCard: some View {
        NavigationLink {
            BecomeHostView()
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

    // MARK: - Data loading

    private func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadPendingCount() }
            group.addTask { await loadUnreadCount() }
            group.addTask { await loadTripCount() }
            group.addTask { await loadReviewCount() }
            if authManager.isHost {
                group.addTask { await loadMonthlyRevenue() }
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

    private func loadUnreadCount() async {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased() else { return }
        do {
            let count = try await supabase
                .from("notifications")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .eq("read", value: false)
                .execute()
                .count ?? 0
            unreadNotifications = count
        } catch {
            print("loadUnreadCount error: \(error)")
        }
    }

    private func loadTripCount() async {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased() else { return }
        do {
            let count = try await supabase
                .from("bookings")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .eq("status", value: "confirmed")
                .execute()
                .count ?? 0
            tripCount = count
        } catch {
            print("loadTripCount error: \(error)")
        }
    }

    private func loadReviewCount() async {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased() else { return }
        do {
            let count = try await supabase
                .from("reviews")
                .select("id", head: true, count: .exact)
                .eq("reviewee_id", value: userId)
                .execute()
                .count ?? 0
            reviewCount = count
        } catch {
            print("loadReviewCount error: \(error)")
        }
    }

    private func loadMonthlyRevenue() async {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased() else { return }
        // Første dag i inneværende måned i Oslo-tz
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: Date())
        comps.day = 1
        guard let monthStart = cal.date(from: comps) else { return }
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(identifier: "Europe/Oslo")
        let from = iso.string(from: monthStart)

        struct Row: Decodable { let totalPrice: Int
            enum CodingKeys: String, CodingKey { case totalPrice = "total_price" }
        }

        do {
            let rows: [Row] = try await supabase
                .from("bookings")
                .select("total_price")
                .eq("host_id", value: userId)
                .eq("status", value: "confirmed")
                .eq("payment_status", value: "paid")
                .gte("created_at", value: from)
                .execute()
                .value
            let serviceFee = 0.10
            monthlyNet = rows.reduce(0) { $0 + Int(Double($1.totalPrice) * (1 - serviceFee)) }
            monthlyBookings = rows.count
        } catch {
            print("loadMonthlyRevenue error: \(error)")
        }
    }
}

// MARK: - EditProfileView (uendret fra tidligere — bio + avatar-crop)

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var fullName = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var showImagePicker = false
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

            Section {
                Button {
                    Task {
                        isSaving = true
                        struct Payload: Encodable {
                            let full_name: String
                            let bio: String?
                        }
                        let trimmedBio = bio.trimmingCharacters(in: .whitespaces)
                        try? await supabase
                            .from("profiles")
                            .update(Payload(full_name: fullName, bio: trimmedBio.isEmpty ? nil : trimmedBio))
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
