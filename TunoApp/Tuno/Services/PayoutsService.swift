import Foundation

/// Henter Stripe Connect-status og siste utbetalinger for innlogget vert.
/// Speiler `/api/host/payouts`-endpointet.
@MainActor
final class PayoutsService: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var status: HostPayoutStatus?
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let session = try? await supabase.auth.session else {
            errorMessage = "Ikke innlogget"
            return
        }

        let url = URL(string: "\(AppConfig.siteURL)/api/host/payouts")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                errorMessage = "Kunne ikke hente utbetalingsstatus"
                return
            }
            let decoder = JSONDecoder()
            status = try decoder.decode(HostPayoutStatus.self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Models

struct HostPayoutStatus: Decodable {
    let has_stripe_account: Bool
    let balance: HostBalance?
    let account_status: HostAccountStatus?
    let external_accounts: [HostExternalAccount]
    let payouts: [HostPayout]
}

struct HostBalance: Decodable {
    let available_nok: Double
    let pending_nok: Double
}

struct HostAccountStatus: Decodable {
    let payouts_enabled: Bool
    let charges_enabled: Bool
    let currently_due: [String]
    let past_due: [String]
    let disabled_reason: String?
    let payout_schedule: String?
}

struct HostExternalAccount: Decodable, Identifiable {
    let type: String
    let last4: String?
    let country: String?
    let currency: String?
    let status: String?
    let default_for_currency: Bool

    var id: String { (last4 ?? "") + (country ?? "") }
}

struct HostPayout: Decodable, Identifiable {
    let id: String
    let amount_nok: Double
    let currency: String
    let status: String  // "paid" | "pending" | "in_transit" | "canceled" | "failed"
    let method: String?
    let arrival_date: Int  // unix seconds
    let created: Int
    let failure_message: String?
    let bank_last4: String?

    var arrivalDate: Date { Date(timeIntervalSince1970: TimeInterval(arrival_date)) }
    var createdDate: Date { Date(timeIntervalSince1970: TimeInterval(created)) }

    var statusLabel: String {
        switch status {
        case "paid": return "Utbetalt"
        case "pending": return "Venter"
        case "in_transit": return "Underveis"
        case "canceled": return "Avbrutt"
        case "failed": return "Feilet"
        default: return status.capitalized
        }
    }
}
