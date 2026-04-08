import Foundation

/// API-kontrakter som speiler endpointene under `/api/stripe/...`.
/// All onboarding-state lever i `HostOnboardingViewModel`; denne servicen
/// er en tynn wrapper rundt URLSession + Bearer-token fra Supabase-sesjonen.
enum HostOnboardingAPIError: LocalizedError {
    case notAuthenticated
    case server(message: String, field: String?)
    case decoding
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Du må være innlogget"
        case .server(let message, _): return message
        case .decoding: return "Uventet svar fra serveren"
        case .network(let error): return "Nettverksfeil: \(error.localizedDescription)"
        }
    }

    var field: String? {
        if case .server(_, let field) = self { return field }
        return nil
    }
}

struct AccountRequirements: Decodable {
    let currently_due: [String]
    let eventually_due: [String]
    let past_due: [String]
    let disabled_reason: String?
}

struct AccountStatus: Decodable {
    let accountId: String?
    let requirements: AccountRequirements
    let charges_enabled: Bool
    let payouts_enabled: Bool
}

struct AccountUpdateIndividualDOB: Encodable {
    let day: Int
    let month: Int
    let year: Int
}

struct AccountUpdateIndividualAddress: Encodable {
    let line1: String
    let postal_code: String
    let city: String
    let country: String
}

struct AccountUpdateIndividual: Encodable {
    var first_name: String?
    var last_name: String?
    var dob: AccountUpdateIndividualDOB?
    var id_number: String?
    var phone: String?
    var email: String?
    var address: AccountUpdateIndividualAddress?
}

struct AccountUpdateTOSAcceptance: Encodable {
    let accepted: Bool
}

struct AccountUpdateRequest: Encodable {
    var individual: AccountUpdateIndividual?
    var tos_acceptance: AccountUpdateTOSAcceptance?
}

struct BankAccountRequest: Encodable {
    let iban: String
    let accountHolderName: String
}

@MainActor
final class HostOnboardingService {
    // MARK: - Public API

    func ensureAccount() async throws -> AccountStatus {
        try await post(
            path: "/api/stripe/connect",
            body: ["platform": "ios"],
        )
    }

    func updateAccount(_ request: AccountUpdateRequest) async throws -> AccountStatus {
        try await post(path: "/api/stripe/account/update", body: request)
    }

    func submitBank(iban: String, accountHolderName: String) async throws -> AccountStatus {
        try await post(
            path: "/api/stripe/account/bank",
            body: BankAccountRequest(iban: iban, accountHolderName: accountHolderName),
        )
    }

    // MARK: - HTTP

    private func post<Body: Encodable>(path: String, body: Body) async throws -> AccountStatus {
        guard let session = try? await supabase.auth.session else {
            throw HostOnboardingAPIError.notAuthenticated
        }

        let url = URL(string: "\(AppConfig.siteURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw HostOnboardingAPIError.network(error)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw HostOnboardingAPIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw HostOnboardingAPIError.decoding
        }

        if http.statusCode != 200 {
            // Serveren returnerer { error, field? } for forventede feil
            if let payload = try? JSONDecoder().decode([String: String].self, from: data) {
                throw HostOnboardingAPIError.server(
                    message: payload["error"] ?? "Feil (\(http.statusCode))",
                    field: payload["field"],
                )
            }
            throw HostOnboardingAPIError.server(
                message: "Feil (\(http.statusCode))",
                field: nil,
            )
        }

        do {
            return try JSONDecoder().decode(AccountStatus.self, from: data)
        } catch {
            throw HostOnboardingAPIError.decoding
        }
    }
}
