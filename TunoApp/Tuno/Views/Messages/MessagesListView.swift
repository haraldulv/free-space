import SwiftUI

struct MessagesListView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var conversations: [ConversationPreview] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if conversations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "message")
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
                List(conversations) { conversation in
                    ConversationRow(conversation: conversation)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Meldinger")
        .task {
            await loadConversations()
        }
    }

    private func loadConversations() async {
        // TODO: Implement with Supabase queries
        isLoading = false
    }
}

struct ConversationPreview: Identifiable {
    let id: String
    let otherUserName: String
    let otherUserAvatar: String?
    let lastMessage: String
    let lastMessageAt: Date
    let unreadCount: Int
    let listingTitle: String
}

struct ConversationRow: View {
    let conversation: ConversationPreview

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.neutral200)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(conversation.otherUserName.prefix(1)))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.neutral500)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUserName)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(conversation.listingTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral400)
                        .lineLimit(1)
                }

                Text(conversation.lastMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
                    .lineLimit(2)
            }

            if conversation.unreadCount > 0 {
                Circle()
                    .fill(Color.primary600)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}
