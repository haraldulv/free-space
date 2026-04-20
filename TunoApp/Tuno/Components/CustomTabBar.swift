import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    var unreadMessages: Int = 0
    var pendingHostRequests: Int = 0

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
                Button {
                    selectedTab = tab.index
                } label: {
                    VStack(spacing: 3) {
                        if tab.index == 2 {
                            // Tuno logo for center tab
                            Image("TunoPin")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                        } else {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 20))
                                    .frame(height: 22)

                                let count = badgeCount(for: tab.index)
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
                        Text(tab.label)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(selectedTab == tab.index ? Color.primary600 : Color.neutral400)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Divider().opacity(0.3)
        }
    }
}
