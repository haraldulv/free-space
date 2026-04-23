import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    var unreadMessages: Int = 0
    var pendingHostRequests: Int = 0
    var profileAvatarURL: URL?
    var profileInitial: String?

    private let tabs: [(index: Int, icon: String, label: String)] = [
        (0, "magnifyingglass", "Utforsk"),
        (1, "heart", "Favoritter"),
        (2, "", "Bestillinger"), // Tuno logo
        (3, "bubble.left", "Meldinger"),
        (4, "person.crop.circle", "Profil"),
    ]

    private func badgeCount(for tabIndex: Int) -> Int {
        switch tabIndex {
        case 3: return unreadMessages
        case 4: return pendingHostRequests
        default: return 0
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.index) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                // Strekk materialet 3pt OPPOVER bak HStack-innholdet. Content
                // i MainTabView bruker padding(.bottom, 80), som ikke matcher
                // tab-barens reelle høyde helt eksakt på alle enhete → 1-2pt
                // tom hvit stripe synlig mellom content og tab-bar. Denne
                // forskyvningen dekker gapet uten å endre tab-bar-layout.
                .padding(.top, -3)
        )
        .overlay(alignment: .top) {
            Divider().opacity(0.3)
        }
    }

    @ViewBuilder
    private func tabButton(for tab: (index: Int, icon: String, label: String)) -> some View {
        Button {
            selectedTab = tab.index
        } label: {
            VStack(spacing: 3) {
                tabIcon(for: tab)
                Text(tab.label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(selectedTab == tab.index ? Color.primary600 : Color.neutral400)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func tabIcon(for tab: (index: Int, icon: String, label: String)) -> some View {
        if tab.index == 2 {
            Image("TunoPin")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
        } else if tab.index == 4 {
            profileTabIcon(isSelected: selectedTab == 4)
        } else {
            standardTabIcon(iconName: tab.icon, tabIndex: tab.index)
        }
    }

    @ViewBuilder
    private func standardTabIcon(iconName: String, tabIndex: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .frame(height: 22)

            let count = badgeCount(for: tabIndex)
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .offset(x: 10, y: -6)
            }
        }
    }

    @ViewBuilder
    private func profileTabIcon(isSelected: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            profileTabContent(isSelected: isSelected)

            let count = badgeCount(for: 4)
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .offset(x: 10, y: -6)
            }
        }
        .frame(height: 22)
    }

    @ViewBuilder
    private func profileTabContent(isSelected: Bool) -> some View {
        if let url = profileAvatarURL {
            avatarImage(url: url, isSelected: isSelected)
        } else if profileInitial != nil {
            initialCircle
        } else {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 20))
                .frame(height: 22)
        }
    }

    private func avatarImage(url: URL, isSelected: Bool) -> some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            initialCircle
        }
        .frame(width: 24, height: 24)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(isSelected ? Color.primary600 : Color.clear, lineWidth: 1.5),
        )
    }

    private var initialCircle: some View {
        Circle()
            .fill(Color.neutral200)
            .frame(width: 24, height: 24)
            .overlay(
                Text(profileInitial ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.neutral700),
            )
    }
}
