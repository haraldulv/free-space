import Foundation
import StripePaymentSheet

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
    @Published var paymentSheet: PaymentSheet?
    @Published var isProcessing = false
    @Published var error: String?
    @Published var bookingId: String?

    static let serviceFeeRate = 0.10

    func createBookingAndPreparePayment(request: CreateBookingRequest, listingTitle: String) async -> Bool {
        isProcessing = true
        error = nil

        do {
            let session = try await supabase.auth.session
            let token = session.accessToken

            var urlRequest = URLRequest(url: URL(string: "\(AppConfig.siteURL)/api/bookings/create")!)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(request)

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Nettverksfeil"
                isProcessing = false
                return false
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(CreateBookingResponse.self, from: data)

            if let errorMsg = result.error {
                error = errorMsg
                isProcessing = false
                return false
            }

            guard let clientSecret = result.clientSecret,
                  let publishableKey = result.publishableKey else {
                error = "Mangler betalingsinformasjon"
                isProcessing = false
                return false
            }

            self.bookingId = result.bookingId

            // Configure Stripe PaymentSheet
            STPAPIClient.shared.publishableKey = publishableKey

            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "Tuno"
            config.applePay = .init(merchantId: "merchant.no.tuno.app", merchantCountryCode: "NO")
            config.defaultBillingDetails.address.country = "NO"
            config.allowsDelayedPaymentMethods = false

            self.paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: config)
            isProcessing = false
            return true
        } catch {
            self.error = "Noe gikk galt: \(error.localizedDescription)"
            isProcessing = false
            return false
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

            struct BookingCount: Decodable {
                let count: Int
            }

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
