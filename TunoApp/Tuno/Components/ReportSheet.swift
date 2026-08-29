import SwiftUI

/// Rapporter annonse/bruker/samtale. Sender til `POST /api/reports` med
/// Bearer-token; admin varsles server-side. Brukes som `.sheet`.
struct ReportSheet: View {
    enum TargetType: String { case listing, user, conversation, review }

    let targetType: TargetType
    let targetId: String

    @Environment(\.dismiss) private var dismiss
    @State private var reason: String?
    @State private var details = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var error: String?

    private let reasons: [(key: String, label: String)] = [
        ("scam", "Svindel eller betaling utenom Tuno"),
        ("inappropriate", "Upassende innhold"),
        ("harassment", "Trakassering eller trusler"),
        ("fake", "Falsk annonse eller profil"),
        ("spam", "Spam"),
        ("other", "Annet"),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if sent {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.primary600)
                        Text("Takk. Vi ser på det så fort vi kan.")
                            .font(.system(size: 15))
                            .foregroundStyle(.neutral700)
                        Button("Lukk") { dismiss() }
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hva er galt? Rapporten går til Tuno-teamet, ikke til den du rapporterer.")
                                .font(.system(size: 14))
                                .foregroundStyle(.neutral500)
                                .padding(.bottom, 4)
                            ForEach(reasons, id: \.key) { r in
                                Button {
                                    reason = r.key
                                } label: {
                                    HStack {
                                        Image(systemName: reason == r.key ? "largecircle.fill.circle" : "circle")
                                            .foregroundStyle(reason == r.key ? Color.primary600 : .neutral400)
                                        Text(r.label)
                                            .font(.system(size: 15))
                                            .foregroundStyle(.neutral900)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(reason == r.key ? Color.primary50 : Color.white)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(reason == r.key ? Color.primary500 : Color.neutral200, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                            TextField("Beskriv gjerne kort (valgfritt)", text: $details, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(12)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neutral200, lineWidth: 1))
                                .padding(.top, 8)
                            if let error {
                                Text(error).font(.system(size: 13)).foregroundStyle(.red)
                            }
                            Button {
                                Task { await send() }
                            } label: {
                                Group {
                                    if isSending { ProgressView().tint(.white) } else { Text("Send rapport").font(.system(size: 16, weight: .semibold)) }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(reason == nil ? Color.neutral300 : Color.neutral900)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(reason == nil || isSending)
                            .padding(.top, 8)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Rapporter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { dismiss() }
                }
            }
        }
    }

    private func send() async {
        guard let reason else { return }
        isSending = true
        defer { isSending = false }
        error = nil
        guard let accessToken = try? await supabase.auth.session.accessToken,
              let url = URL(string: "\(AppConfig.siteURL)/api/reports") else {
            error = "Logg inn for å rapportere."
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "targetType": targetType.rawValue,
            "targetId": targetId,
            "reason": reason,
            "details": details,
        ])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                sent = true
            } else {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                error = msg ?? "Kunne ikke sende rapporten. Prøv igjen."
            }
        } catch {
            self.error = "Kunne ikke sende rapporten. Prøv igjen."
        }
    }
}
