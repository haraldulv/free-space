import Foundation

/// Rask bildesjekk ved opplasting (speiler web-wizarden). Kaller
/// `POST /api/moderate-image` på tuno.no med brukerens access token.
///
/// Dette er UX-laget: porten som faktisk hindrer publisering er
/// annonse-modereringen server-side + RLS (annonsen er usynlig til den er
/// godkjent). Derfor "fail open" ved nettverksfeil.
enum ModerationService {
    struct Verdict: Decodable {
        let approved: Bool
        let reason: String?
        let category: String?
    }

    static func moderateImage(url: String) async -> Verdict {
        guard let accessToken = try? await supabase.auth.session.accessToken,
              let endpoint = URL(string: "\(AppConfig.siteURL)/api/moderate-image") else {
            return Verdict(approved: true, reason: nil, category: nil)
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["imageUrl": url])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return Verdict(approved: true, reason: nil, category: nil)
            }
            return try JSONDecoder().decode(Verdict.self, from: data)
        } catch {
            print("[Moderation] image check failed: \(error)")
            return Verdict(approved: true, reason: nil, category: nil)
        }
    }

    static func moderateAvatar(url: String) async -> Verdict {
        guard let accessToken = try? await supabase.auth.session.accessToken,
              let endpoint = URL(string: "\(AppConfig.siteURL)/api/moderate-avatar") else {
            return Verdict(approved: true, reason: nil, category: nil)
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["avatarUrl": url])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return Verdict(approved: true, reason: nil, category: nil)
            }
            return try JSONDecoder().decode(Verdict.self, from: data)
        } catch {
            return Verdict(approved: true, reason: nil, category: nil)
        }
    }
}
