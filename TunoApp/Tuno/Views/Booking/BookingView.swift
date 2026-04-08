import SwiftUI
import PassKit
import StripePaymentsUI
import StripeApplePay

// Stripe card input wrapped for SwiftUI
struct CardFormView: UIViewRepresentable {
    @Binding var isComplete: Bool
    @Binding var cardField: STPPaymentCardTextField?

    class Coordinator: NSObject, STPPaymentCardTextFieldDelegate {
        var parent: CardFormView
        init(_ parent: CardFormView) { self.parent = parent }
        func paymentCardTextFieldDidChange(_ textField: STPPaymentCardTextField) {
            parent.isComplete = textField.isValid
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> STPPaymentCardTextField {
        let field = STPPaymentCardTextField()
        field.delegate = context.coordinator
        field.postalCodeEntryEnabled = false
        field.countryCode = "NO"
        DispatchQueue.main.async { self.cardField = field }
        return field
    }

    func updateUIView(_ uiView: STPPaymentCardTextField, context: Context) {}
}

// Native Apple Pay button
struct ApplePayButtonView: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

// Apple Pay handler
class ApplePayHandler: NSObject, PKPaymentAuthorizationControllerDelegate {
    let clientSecret: String
    let completion: (Bool) -> Void

    init(clientSecret: String, completion: @escaping (Bool) -> Void) {
        self.clientSecret = clientSecret
        self.completion = completion
    }

    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler: @escaping (PKPaymentAuthorizationResult) -> Void) {
        STPAPIClient.shared.createPaymentMethod(with: payment) { paymentMethod, error in
            guard let paymentMethod, error == nil else {
                print("❌ Apple Pay createPM error: \(error?.localizedDescription ?? "unknown")")
                handler(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                self.completion(false)
                return
            }

            let params = STPPaymentIntentParams(clientSecret: self.clientSecret)
            params.paymentMethodId = paymentMethod.stripeId

            STPAPIClient.shared.confirmPaymentIntent(with: params) { paymentIntent, confirmError in
                if paymentIntent?.status == .succeeded {
                    print("✅ Apple Pay succeeded!")
                    handler(PKPaymentAuthorizationResult(status: .success, errors: nil))
                    self.completion(true)
                } else {
                    print("❌ Apple Pay confirm error: \(confirmError?.localizedDescription ?? "unknown")")
                    handler(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                    self.completion(false)
                }
            }
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
    }
}

struct BookingView: View {
    let listing: Listing
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var bookingService = BookingService()
    @Environment(\.dismiss) var dismiss

    @State private var checkIn: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
    @State private var checkOut: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400 * 2)
    @State private var licensePlate = ""
    @State private var isRentalCar = false
    @State private var availableSpots: Int?
    @State private var totalSpots: Int?
    @State private var showConfirmation = false
    @State private var cardIsComplete = false
    @State private var cardField: STPPaymentCardTextField?
    @State private var showCardForm = false
    @State private var applePayHandler: ApplePayHandler?
    @State private var isApplePayLoading = false

    private var nights: Int {
        max(1, Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 1)
    }

    private var subtotal: Int {
        nights * (listing.price ?? 0)
    }

    private var serviceFee: Int {
        Int(ceil(Double(subtotal) * BookingService.serviceFeeRate))
    }

    private var total: Int {
        subtotal + serviceFee
    }

    private var isFormValid: Bool {
        checkOut > checkIn && (isRentalCar || !licensePlate.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                listingSummary
                Divider()
                dateSection
                Divider()
                vehicleSection
                Divider()

                if let available = availableSpots, let total = totalSpots {
                    HStack(spacing: 6) {
                        Image(systemName: available > 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(available > 0 ? .green : .red)
                        Text(available > 0 ? "\(available) av \(total) plasser ledig" : "Ingen ledige plasser")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(available > 0 ? .neutral700 : .red)
                    }
                }

                priceBreakdown

                // Card form (expandable)
                if showCardForm {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kortinformasjon")
                            .font(.system(size: 16, weight: .semibold))
                        CardFormView(isComplete: $cardIsComplete, cardField: $cardField)
                            .frame(height: 50)
                    }
                }

                if let error = bookingService.error {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding(20)
        }
        .background(.white)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Divider()

                if showCardForm {
                    // Card payment button
                    Button {
                        Task { await confirmCardPayment() }
                    } label: {
                        Group {
                            if bookingService.isProcessing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Betal \(total) kr")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(cardIsComplete ? Color.primary600 : Color.neutral300)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!cardIsComplete || bookingService.isProcessing)
                    .padding(.horizontal, 20)
                } else {
                    // Apple Pay (one tap — creates booking + presents Apple Pay)
                    if BookingService.canPayWithApplePay {
                        if isApplePayLoading {
                            ProgressView()
                                .frame(height: 50)
                        } else {
                            ApplePayButtonView {
                                Task { await handleApplePay() }
                            }
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                            .opacity(isFormValid && !(availableSpots == 0) ? 1 : 0.4)
                            .allowsHitTesting(isFormValid && !(availableSpots == 0))
                        }
                    }

                    // "Betal med kort" toggle
                    Button {
                        if bookingService.clientSecret == nil {
                            Task {
                                await createBookingIfNeeded()
                                if bookingService.clientSecret != nil {
                                    withAnimation { showCardForm = true }
                                }
                            }
                        } else {
                            withAnimation { showCardForm = true }
                        }
                    } label: {
                        Text("Betal med kort")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary600)
                    }
                    .disabled(!isFormValid || availableSpots == 0)
                    .padding(.bottom, 4)
                }
            }
            .padding(.vertical, 8)
            .background(.white)
        }
        .navigationTitle("Bestill")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showConfirmation) {
            BookingConfirmationView(
                listing: listing,
                checkIn: checkIn,
                checkOut: checkOut,
                total: total
            )
        }
        .task {
            await checkAvailability()
        }
        .onChange(of: checkIn) {
            if checkOut <= checkIn {
                checkOut = Calendar.current.date(byAdding: .day, value: 1, to: checkIn) ?? checkIn
            }
            showCardForm = false
            bookingService.clientSecret = nil
            Task { await checkAvailability() }
        }
        .onChange(of: checkOut) {
            showCardForm = false
            bookingService.clientSecret = nil
            Task { await checkAvailability() }
        }
    }

    // MARK: - Subviews

    private var listingSummary: some View {
        HStack(spacing: 14) {
            if let imageUrl = listing.images?.first, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.neutral100)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .lineLimit(2)
                if let city = listing.city {
                    Text(city)
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }
                HStack(spacing: 4) {
                    Text("\(listing.price ?? 0) kr")
                        .font(.system(size: 14, weight: .bold))
                    Text("/ \(listing.priceUnit?.displayName ?? "natt")")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }
            }
            Spacer()
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Datoer")
                .font(.system(size: 18, weight: .semibold))
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Innsjekk")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.neutral500)
                    DatePicker("", selection: $checkIn, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden()
                        .environment(\.locale, Locale(identifier: "nb"))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Utsjekk")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.neutral500)
                    DatePicker("", selection: $checkOut,
                               in: Calendar.current.date(byAdding: .day, value: 1, to: checkIn)!...,
                               displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden()
                        .environment(\.locale, Locale(identifier: "nb"))
                }
                Spacer()
            }
            Text("\(nights) \(nights == 1 ? "natt" : "netter")")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
        }
    }

    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kjøretøy")
                .font(.system(size: 18, weight: .semibold))
            Toggle("Leiebil (ingen registreringsnummer)", isOn: $isRentalCar)
                .font(.system(size: 14))
                .tint(.primary600)
            if !isRentalCar {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Registreringsnummer")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral700)
                    TextField("F.eks. AB 12345", text: $licensePlate)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Color.neutral50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }
            }
        }
    }

    private var priceBreakdown: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(listing.price ?? 0) kr × \(nights) \(nights == 1 ? "natt" : "netter")")
                    .font(.system(size: 14)).foregroundStyle(.neutral600)
                Spacer()
                Text("\(subtotal) kr").font(.system(size: 14)).foregroundStyle(.neutral600)
            }
            HStack {
                Text("Serviceavgift").font(.system(size: 14)).foregroundStyle(.neutral600)
                Spacer()
                Text("\(serviceFee) kr").font(.system(size: 14)).foregroundStyle(.neutral600)
            }
            Divider()
            HStack {
                Text("Totalt").font(.system(size: 16, weight: .bold))
                Spacer()
                Text("\(total) kr").font(.system(size: 16, weight: .bold))
            }
        }
        .padding(16)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func checkAvailability() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let result = await bookingService.checkAvailability(
            listingId: listing.id,
            checkIn: formatter.string(from: checkIn),
            checkOut: formatter.string(from: checkOut)
        )
        availableSpots = result.available
        totalSpots = result.total
    }

    private func createBookingIfNeeded() async {
        guard bookingService.clientSecret == nil else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = CreateBookingRequest(
            listingId: listing.id,
            checkIn: formatter.string(from: checkIn),
            checkOut: formatter.string(from: checkOut),
            totalPrice: total,
            licensePlate: isRentalCar ? nil : licensePlate.trimmingCharacters(in: .whitespaces).uppercased(),
            isRentalCar: isRentalCar
        )

        _ = await bookingService.createBooking(request: request)
    }

    private func handleApplePay() async {
        isApplePayLoading = true
        await createBookingIfNeeded()
        isApplePayLoading = false

        guard let clientSecret = bookingService.clientSecret else { return }

        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.no.tuno.app"
        request.countryCode = "NO"
        request.currencyCode = "NOK"
        request.supportedNetworks = [.visa, .masterCard, .amex]
        request.merchantCapabilities = .threeDSecure
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: listing.title, amount: NSDecimalNumber(value: total))
        ]

        let handler = ApplePayHandler(clientSecret: clientSecret) { success in
            DispatchQueue.main.async {
                if success {
                    self.showConfirmation = true
                } else {
                    self.bookingService.error = "Apple Pay-betaling feilet"
                }
            }
        }
        self.applePayHandler = handler

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = handler
        await controller.present()
    }

    private func confirmCardPayment() async {
        guard let field = cardField, field.isValid else {
            bookingService.error = "Fyll inn kortinformasjon"
            return
        }

        let pmId: String? = await withCheckedContinuation { continuation in
            STPAPIClient.shared.createPaymentMethod(with: field.paymentMethodParams) { paymentMethod, error in
                if let error {
                    print("❌ Create PM error: \(error)")
                    continuation.resume(returning: nil)
                } else {
                    print("💳 Created PM: \(paymentMethod?.stripeId ?? "?")")
                    continuation.resume(returning: paymentMethod?.stripeId)
                }
            }
        }

        guard let pmId else {
            bookingService.error = "Kunne ikke opprette betalingsmetode"
            return
        }

        let success = await bookingService.confirmCardPayment(paymentMethodId: pmId)
        if success {
            showConfirmation = true
        }
    }
}
