import SwiftUI
import PassKit
import StripePaymentsUI
import StripeApplePay

/// Sheet som viser Apple Pay + kort-input når en gjest skal fullføre betaling
/// etter at en forhandling-flyt har endt med aksept. Gjenbruker samme
/// Apple Pay + STPPaymentCardTextField-pattern som BookingView (se
/// memory `feedback_stripe_crash.md` om hvorfor PaymentSheet ikke brukes).
struct NegotiationPaymentView: View {
    let bookingId: String
    let clientSecret: String
    let totalPrice: Int
    let listingTitle: String
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var bookingService = BookingService()
    @State private var cardComplete: Bool = false
    @State private var cardField: STPPaymentCardTextField?
    @State private var processing = false
    @State private var errorMessage: String?
    @State private var applePayHandler: ApplePayHandler?
    @State private var paymentController: PKPaymentAuthorizationController?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summarySection

                    if BookingService.canPayWithApplePay {
                        ApplePayButtonView(action: triggerApplePay)
                            .frame(height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    HStack {
                        Rectangle().fill(Color.neutral200).frame(height: 1)
                        Text("eller")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral500)
                            .padding(.horizontal, 8)
                        Rectangle().fill(Color.neutral200).frame(height: 1)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Betal med kort")
                            .font(.system(size: 14, weight: .semibold))
                        CardFormView(isComplete: $cardComplete, cardField: $cardField)
                            .frame(height: 48)
                            .padding(.horizontal, 12)
                            .background(Color.neutral50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await payWithCard() }
                    } label: {
                        HStack {
                            if processing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Betal \(totalPrice.formatted(.number.locale(Locale(identifier: "nb_NO")))) kr")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(cardComplete && !processing ? Color.primary600 : Color.neutral300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!cardComplete || processing)
                }
                .padding(20)
            }
            .navigationTitle("Fullfør betaling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Avbryt") { dismiss() }
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(spacing: 6) {
            Text(listingTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral700)
                .multilineTextAlignment(.center)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(totalPrice.formatted(.number.locale(Locale(identifier: "nb_NO"))))")
                    .font(.system(size: 32, weight: .bold))
                Text("kr")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral500)
            }
            Text("Bekreftet pris fra forhandlingen")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func triggerApplePay() {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.no.tuno.app"
        request.supportedNetworks = [.visa, .masterCard, .amex]
        request.merchantCapabilities = .threeDSecure
        request.countryCode = "NO"
        request.currencyCode = "NOK"
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: listingTitle, amount: NSDecimalNumber(value: totalPrice)),
        ]

        let handler = ApplePayHandler(clientSecret: clientSecret) { success in
            DispatchQueue.main.async {
                if success {
                    Task {
                        await bookingService.notifyPaymentConfirmed(bookingId: bookingId)
                        onSuccess()
                        dismiss()
                    }
                } else {
                    errorMessage = "Apple Pay-betalingen feilet. Prøv kort i stedet."
                }
            }
        }
        applePayHandler = handler

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = handler
        paymentController = controller
        controller.present(completion: nil)
    }

    private func payWithCard() async {
        guard let cardField, cardField.isValid else { return }
        processing = true
        errorMessage = nil

        let pmCard = STPPaymentMethodCardParams()
        pmCard.number = cardField.cardParams.number
        pmCard.expMonth = cardField.cardParams.expMonth
        pmCard.expYear = cardField.cardParams.expYear
        pmCard.cvc = cardField.cardParams.cvc
        let pmParams = STPPaymentMethodParams(card: pmCard, billingDetails: nil, metadata: nil)

        let params = STPPaymentIntentParams(clientSecret: clientSecret)
        params.paymentMethodParams = pmParams

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            STPAPIClient.shared.confirmPaymentIntent(with: params) { paymentIntent, error in
                Task { @MainActor in
                    processing = false
                    if let error {
                        errorMessage = error.localizedDescription
                    } else if paymentIntent?.status == .succeeded {
                        await bookingService.notifyPaymentConfirmed(bookingId: bookingId)
                        onSuccess()
                        dismiss()
                    } else {
                        errorMessage = "Betalingen feilet. Prøv igjen."
                    }
                    continuation.resume()
                }
            }
        }
    }
}
