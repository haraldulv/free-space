import Foundation
import UIKit
import PassKit
import StripeApplePay
import StripePaymentsUI

struct CreateBookingRequest: Encodable {
    let listingId: String
    let checkIn: String       // "yyyy-MM-dd" — alltid satt
    let checkOut: String      // "yyyy-MM-dd" — alltid satt
    /// ISO 8601 timestamp for hourly bookings (parkering per time). nil for daglige bookinger.
    let checkInAt: String?
    let checkOutAt: String?
    let licensePlate: String?
    let isRentalCar: Bool
    let selectedSpotIds: [String]?
    let selectedExtras: SelectedExtras?
}

struct CreateBookingResponse: Decodable {
    let bookingId: String?
    let clientSecret: String?
    let publishableKey: String?
    let error: String?
}

struct BookingErrorBody: Decodable {
    let error: String?
}

@MainActor
final class BookingService: ObservableObject {
    @Published var isProcessing = false
    @Published var error: String?
    @Published var bookingId: String?
    @Published var clientSecret: String?

    static let serviceFeeRate = 0.10

    static var canPayWithApplePay: Bool {
        StripeAPI.deviceSupportsApplePay()
    }

    func createBooking(request: CreateBookingRequest) async -> Bool {
        isProcessing = true
        error = nil

        do {
            let session = try await supabase.auth.session
            let token = session.accessToken
            print("🔑 Got auth token, calling API...")

            var urlRequest = URLRequest(url: URL(string: "\(AppConfig.siteURL)/api/bookings/create")!)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let bodyData = try JSONEncoder().encode(request)
            urlRequest.httpBody = bodyData
            print("📤 Request body: \(String(data: bodyData, encoding: .utf8) ?? "nil")")

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Nettverksfeil"
                isProcessing = false
                return false
            }

            let responseBody = String(data: data, encoding: .utf8) ?? "nil"
            print("📡 API response (\(httpResponse.statusCode)): \(responseBody)")

            let result = try JSONDecoder().decode(CreateBookingResponse.self, from: data)

            if let errorMsg = result.error {
                error = errorMsg
                isProcessing = false
                return false
            }

            guard let secret = result.clientSecret,
                  let publishableKey = result.publishableKey else {
                error = "Mangler betalingsinformasjon"
                isProcessing = false
                return false
            }

            print("✅ Got clientSecret and publishableKey")

            STPAPIClient.shared.publishableKey = publishableKey
            self.bookingId = result.bookingId
            self.clientSecret = secret
            isProcessing = false
            return true
        } catch {
            print("❌ BookingService error: \(error)")
            self.error = "Noe gikk galt: \(error.localizedDescription)"
            isProcessing = false
            return false
        }
    }

    // MARK: - Forhandling-flyt (instant_booking=false)

    struct RequestBookingPayload: Encodable {
        let listingId: String
        let checkIn: String
        let checkOut: String
        let licensePlate: String?
        let isRentalCar: Bool
        let selectedSpotIds: [String]?
        let selectedExtras: SelectedExtras?
        let message: String?
    }

    struct RequestBookingResponse: Decodable {
        let bookingId: String?
        let offerId: String?
        let conversationId: String?
        let totalPrice: Int?
        let error: String?
    }

    /// Send forespørsel uten Stripe. Brukes for instant_booking=false-annonser.
    /// Returnerer (bookingId, conversationId) ved suksess.
    func requestBooking(payload: RequestBookingPayload) async -> RequestBookingResponse? {
        return await postJSON(path: "/api/bookings/request", body: payload)
    }

    struct OfferPayload: Encodable {
        let bookingId: String
        let totalPrice: Int
        let checkIn: String?
        let checkOut: String?
        let message: String?
    }

    struct OfferResponse: Decodable {
        let offerId: String?
        let round: Int?
        let awaitingParty: String?
        let expiresAt: String?
        let error: String?
    }

    func sendOffer(payload: OfferPayload) async -> OfferResponse? {
        return await postJSON(path: "/api/bookings/offer", body: payload)
    }

    struct AcceptPayload: Encodable {
        let bookingId: String
        let offerId: String
    }

    struct AcceptResponse: Decodable {
        let bookingId: String?
        let offerId: String?
        let status: String?
        let paymentDeadline: String?
        let clientSecret: String?
        let publishableKey: String?
        let acceptorRole: String?
        let error: String?
    }

    func acceptOffer(payload: AcceptPayload) async -> AcceptResponse? {
        let response: AcceptResponse? = await postJSON(path: "/api/bookings/accept", body: payload)
        if let secret = response?.clientSecret, let key = response?.publishableKey {
            STPAPIClient.shared.publishableKey = key
            self.bookingId = response?.bookingId
            self.clientSecret = secret
        }
        return response
    }

    struct DeclinePayload: Encodable {
        let bookingId: String
        let reason: String?
    }

    struct DeclineResponse: Decodable {
        let status: String?
        let error: String?
    }

    func declineBooking(bookingId: String, reason: String? = nil) async -> Bool {
        let payload = DeclinePayload(bookingId: bookingId, reason: reason)
        let response: DeclineResponse? = await postJSON(path: "/api/bookings/decline", body: payload)
        return response?.status == "declined"
    }

    struct PaymentConfirmedPayload: Encodable {
        let bookingId: String
    }

    struct PaymentConfirmedResponse: Decodable {
        let status: String?
        let alreadyProcessed: Bool?
        let error: String?
    }

    /// Notifiser server etter at PaymentSheet returnerte success. Idempotent —
    /// kalles også via Stripe webhook for redundans.
    func notifyPaymentConfirmed(bookingId: String) async {
        let payload = PaymentConfirmedPayload(bookingId: bookingId)
        let _: PaymentConfirmedResponse? = await postJSON(path: "/api/bookings/payment-confirmed", body: payload)
    }

    /// Generisk POST med Bearer-token-autentisering.
    private func postJSON<Body: Encodable, Response: Decodable>(path: String, body: Body) async -> Response? {
        do {
            let session = try await supabase.auth.session
            let token = session.accessToken
            var req = URLRequest(url: URL(string: "\(AppConfig.siteURL)\(path)")!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                if let parsed = try? JSONDecoder().decode(BookingErrorBody.self, from: data), let msg = parsed.error {
                    self.error = msg
                }
                print("❌ \(path) returned \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                return nil
            }
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            print("❌ postJSON \(path) error: \(error)")
            self.error = error.localizedDescription
            return nil
        }
    }

    func confirmCardPayment(paymentMethodId: String) async -> Bool {
        guard let clientSecret else {
            error = "Mangler betalingsinformasjon"
            return false
        }

        isProcessing = true
        error = nil

        let paymentIntentParams = STPPaymentIntentParams(clientSecret: clientSecret)
        paymentIntentParams.paymentMethodId = paymentMethodId

        return await withCheckedContinuation { continuation in
            STPAPIClient.shared.confirmPaymentIntent(with: paymentIntentParams) { paymentIntent, confirmError in
                DispatchQueue.main.async {
                    self.isProcessing = false

                    if let confirmError {
                        print("❌ confirmPayment error: \(confirmError)")
                        self.error = confirmError.localizedDescription
                        continuation.resume(returning: false)
                        return
                    }

                    guard let paymentIntent else {
                        self.error = "Betaling feilet"
                        continuation.resume(returning: false)
                        return
                    }

                    print("💳 Payment status: \(paymentIntent.status)")

                    if paymentIntent.status == .succeeded {
                        print("✅ Payment succeeded!")
                        continuation.resume(returning: true)
                    } else {
                        self.error = "Betaling feilet"
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    struct BookedDates {
        let perSpot: [String: [String]]
        let perDateCount: [String: Int]
    }

    /// Henter fremtidige bookede datoer for en annonse, gruppert per spot-ID og per dato.
    func fetchBookedDates(listingId: String) async -> BookedDates {
        struct Row: Decodable {
            let check_in: String
            let check_out: String
            let selected_spot_ids: [String]?
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        let today = fmt.string(from: Date())

        do {
            let rows: [Row] = try await supabase
                .from("bookings")
                .select("check_in, check_out, selected_spot_ids")
                .eq("listing_id", value: listingId)
                .in("status", values: ["confirmed", "pending", "requested"])
                .gte("check_out", value: today)
                .execute()
                .value

            var perSpot: [String: Set<String>] = [:]
            var perDateCount: [String: Int] = [:]
            for row in rows {
                guard let start = fmt.date(from: row.check_in),
                      let end = fmt.date(from: row.check_out) else { continue }
                let occupies = (row.selected_spot_ids?.count ?? 0) > 0 ? row.selected_spot_ids!.count : 1
                var cursor = start
                while cursor < end {
                    let d = fmt.string(from: cursor)
                    perDateCount[d, default: 0] += occupies
                    if let ids = row.selected_spot_ids, !ids.isEmpty {
                        for sid in ids {
                            perSpot[sid, default: []].insert(d)
                        }
                    }
                    guard let next = Calendar.current.date(byAdding: .day, value: 1, to: cursor) else { break }
                    cursor = next
                }
            }
            return BookedDates(
                perSpot: perSpot.mapValues { Array($0).sorted() },
                perDateCount: perDateCount
            )
        } catch {
            print("fetchBookedDates error: \(error)")
            return BookedDates(perSpot: [:], perDateCount: [:])
        }
    }

    func checkAvailability(listingId: String, checkIn: String, checkOut: String) async -> (available: Int, total: Int) {
        do {
            struct ListingSpots: Decodable {
                let spots: Int
            }

            let listing: ListingSpots = try await supabase
                .from("listings")
                .select("spots")
                .eq("id", value: listingId)
                .single()
                .execute()
                .value

            let count = try await supabase
                .from("bookings")
                .select("id", head: true, count: .exact)
                .eq("listing_id", value: listingId)
                .in("status", values: ["confirmed", "pending", "requested"])
                .lt("check_in", value: checkOut)
                .gt("check_out", value: checkIn)
                .execute()
                .count ?? 0

            return (available: listing.spots - count, total: listing.spots)
        } catch {
            print("checkAvailability error: \(error)")
            return (available: 0, total: 0)
        }
    }
}
