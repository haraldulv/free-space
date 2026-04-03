import Foundation
import UIKit
import PassKit
import StripeApplePay
import StripePaymentsUI

struct CreateBookingRequest: Encodable {
    let listingId: String
    let checkIn: String
    let checkOut: String
    let totalPrice: Int
    let licensePlate: String?
    let isRentalCar: Bool
}

struct CreateBookingResponse: Decodable {
    let bookingId: String?
    let clientSecret: String?
    let publishableKey: String?
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
            urlRequest.httpBody = try JSONEncoder().encode(request)

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
                .in("status", values: ["confirmed", "pending"])
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
