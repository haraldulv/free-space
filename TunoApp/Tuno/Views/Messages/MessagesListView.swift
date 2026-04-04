import SwiftUI

struct MessagesListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var chatService = ChatService()
    @State private var showLogin = false

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                AuthPromptView(
                    icon: "bubble.left",
                    message: "Logg inn for å se meldingene dine",
                    showLogin: $showLogin
                )
            } else if chatService.isLoading {
                ProgressView()
            } else if chatService.conversations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 40))
                        .foregroundStyle(.neutral300)
                    Text("Ingen meldinger")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.neutral500)
                    Text("Meldinger fra utleiere og gjester vises her")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                }
            } else {
                List(chatService.conversations) { conversation in
                    NavigationLink(value: conversation.id) {
                        ConversationRow(conversation: conversation)
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: String.self) { conversationId in
                    if let convo = chatService.conversations.first(where: { $0.id == conversationId }) {
                        ChatView(
                            conversationId: convo.id,
                            otherUserName: convo.otherUserName,
                            listingTitle: convo.listingTitle
                        )
                    }
                }
            }
        }
        .navigationTitle("Meldinger")
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .task {
            guard let userId = authManager.currentUser?.id else { return }
            await chatService.loadConversations(userId: userId.uuidString)
        }
        .refreshable {
            guard let userId = authManager.currentUser?.id else { return }
            await chatService.loadConversations(userId: userId.uuidString)
        }
    }
}

struct ConversationRow: View {
    let conversation: ConversationPreview

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarUrl = conversation.otherUserAvatar, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        avatarPlaceholder
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUserName)
                        .font(.system(size: 15, weight: conversation.unreadCount > 0 ? .bold : .semibold))
                        .foregroundStyle(.neutral900)
                    Spacer()
                    if let dateStr = conversation.lastMessageAt {
                        Text(formatDate(dateStr))
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral400)
                    }
                }

                Text(conversation.listingTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral400)
                    .lineLimit(1)

                HStack {
                    Text(conversation.lastMessage)
                        .font(.system(size: 14, weight: conversation.unreadCount > 0 ? .medium : .regular))
                        .foregroundStyle(conversation.unreadCount > 0 ? .neutral900 : .neutral500)
                        .lineLimit(1)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary600)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.primary100)
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(conversation.otherUserName.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary600)
            )
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: iso) else { return "" }
            return relativeDate(date)
        }
        return relativeDate(date)
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return df.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "I går"
        } else {
            let df = DateFormatter()
            df.dateFormat = "d. MMM"
            df.locale = Locale(identifier: "nb_NO")
            return df.string(from: date)
        }
    }
}
