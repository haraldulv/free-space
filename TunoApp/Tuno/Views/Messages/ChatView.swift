import SwiftUI

struct ChatView: View {
    let conversationId: String
    let otherUserName: String
    let listingTitle: String

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var chatService = ChatService()
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    private var currentUserId: String {
        authManager.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(chatService.messages) { message in
                            MessageBubble(
                                message: message,
                                isMe: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: chatService.messages.count) {
                    if let last = chatService.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = chatService.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input
            HStack(spacing: 12) {
                TextField("Skriv en melding...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    Task { await sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .neutral300 : .primary600)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.white)
        }
        .navigationTitle(otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(otherUserName)
                        .font(.system(size: 15, weight: .semibold))
                    Text(listingTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral400)
                }
            }
        }
        .task {
            await chatService.loadMessages(conversationId: conversationId)
            await chatService.subscribeToMessages(conversationId: conversationId)
            await chatService.markAsRead(conversationId: conversationId, userId: currentUserId)
        }
        .onDisappear {
            Task { await chatService.unsubscribe() }
        }
    }

    private func sendMessage() async {
        let text = messageText
        messageText = ""
        await chatService.sendMessage(
            conversationId: conversationId,
            senderId: currentUserId,
            content: text
        )
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 60) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(isMe ? .white : .neutral900)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMe ? Color.primary600 : Color.neutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(formatTime(message.createdAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.neutral400)
            }

            if !isMe { Spacer(minLength: 60) }
        }
    }

    private func formatTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: iso) else { return "" }
            return timeString(date)
        }
        return timeString(date)
    }

    private func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }
}
