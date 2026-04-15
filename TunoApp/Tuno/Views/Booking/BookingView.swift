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

    @State private var checkIn: Date? = nil
    @State private var checkOut: Date? = nil
    @State private var showCalendar = false
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
    @State private var selectedSpotIds: Set<String> = []
    @State private var listingExtrasQty: [String: Int] = [:]
    @State private var spotExtrasQty: [String: [String: Int]] = [:]
    @State private var bookedDates: BookingService.BookedDates?

    private var hasSpotLevelPricing: Bool {
        (listing.spotMarkers ?? []).contains { $0.price != nil || !($0.extras?.isEmpty ?? true) }
    }

    private var selectedSpots: [SpotMarker] {
        (listing.spotMarkers ?? []).filter { spot in
            guard let id = spot.id else { return false }
            return selectedSpotIds.contains(id)
        }
    }

    private var nights: Int {
        guard let ci = checkIn, let co = checkOut else { return 0 }
        return max(1, Calendar.current.dateComponents([.day], from: ci, to: co).day ?? 1)
    }

    private var hasDates: Bool { checkIn != nil && checkOut != nil }

    private var baseTotal: Int {
        if hasSpotLevelPricing && !selectedSpots.isEmpty {
            return selectedSpots.reduce(0) { $0 + ($1.price ?? listing.price ?? 0) * nights }
        }
        return nights * (listing.price ?? 0)
    }

    private var listingExtrasTotal: Int {
        (listing.extras ?? []).reduce(0) { sum, extra in
            let qty = listingExtrasQty[extra.id] ?? 0
            return sum + extra.price * (extra.perNight ? nights : 1) * qty
        }
    }

    private var spotExtrasTotal: Int {
        selectedSpots.reduce(0) { sum, spot in
            guard let sid = spot.id, let map = spotExtrasQty[sid] else { return sum }
            let perSpot = (spot.extras ?? []).reduce(0) { acc, extra in
                acc + extra.price * (extra.perNight ? nights : 1) * (map[extra.id] ?? 0)
            }
            return sum + perSpot
        }
    }

    private var subtotal: Int {
        baseTotal + listingExtrasTotal + spotExtrasTotal
    }

    private var serviceFee: Int {
        Int(ceil(Double(subtotal) * BookingService.serviceFeeRate))
    }

    private var total: Int {
        subtotal + serviceFee
    }

    private var isFormValid: Bool {
        let vehicleOK = isRentalCar || !licensePlate.trimmingCharacters(in: .whitespaces).isEmpty
        let spotOK = !hasSpotLevelPricing || !selectedSpotIds.isEmpty
        return hasDates && vehicleOK && spotOK
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

                if !hasSpotLevelPricing, let available = availableSpots, let total = totalSpots {
                    HStack(spacing: 6) {
                        Image(systemName: available > 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(available > 0 ? .green : .red)
                        Text(available > 0 ? "\(available) av \(total) plasser ledig" : "Ingen ledige plasser")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(available > 0 ? .neutral700 : .red)
                    }
                }

                if hasSpotLevelPricing {
                    spotPickerSection
                    Divider()
                }

                if !(listing.extras ?? []).isEmpty {
                    listingExtrasSection
                    Divider()
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
                checkIn: checkIn ?? Date(),
                checkOut: checkOut ?? Date(),
                total: total
            )
        }
        .task {
            async let avail: () = checkAvailability()
            async let booked = bookingService.fetchBookedDates(listingId: listing.id)
            _ = await avail
            bookedDates = await booked
        }
        .onChange(of: checkIn) {
            showCardForm = false
            bookingService.clientSecret = nil
            deselectBlockedSpots()
            Task { await checkAvailability() }
        }
        .onChange(of: checkOut) {
            showCardForm = false
            bookingService.clientSecret = nil
            deselectBlockedSpots()
            if hasDates {
                withAnimation(.easeInOut(duration: 0.2)) { showCalendar = false }
            }
            Task { await checkAvailability() }
        }
    }

    private func deselectBlockedSpots() {
        let stillOk = selectedSpotIds.filter { id in
            guard let spot = (listing.spotMarkers ?? []).first(where: { $0.id == id }) else { return false }
            return !isSpotBlockedByDates(spot)
        }
        if stillOk.count != selectedSpotIds.count {
            selectedSpotIds = Set(stillOk)
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
                    Text("\(listing.displayPriceText) kr")
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
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showCalendar.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.neutral500)
                    if let ci = checkIn, let co = checkOut {
                        Text("\(formatShort(ci)) – \(formatShort(co))")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.neutral900)
                    } else if let ci = checkIn {
                        Text("Fra \(formatShort(ci)) — velg utsjekk")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.neutral700)
                    } else {
                        Text("Velg datoer")
                            .font(.system(size: 15))
                            .foregroundStyle(.neutral500)
                    }
                    Spacer()
                    Image(systemName: showCalendar ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.neutral400)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.neutral50)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if showCalendar {
                BookingCalendarView(
                    checkIn: $checkIn,
                    checkOut: $checkOut,
                    blockedDates: calendarBlockedDates,
                    minDate: Calendar.current.startOfDay(for: Date())
                )
                .frame(height: 320)
                .padding(.top, 4)
                .transition(.opacity)
            }

            if hasDates {
                Text("\(nights) \(nights == 1 ? "natt" : "netter")")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
            }
        }
    }

    private func formatShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb")
        f.dateFormat = "d. MMM"
        return f.string(from: date)
    }

    /// Datoer som skal vises greyed ut i kalenderen: listing.blockedDates,
    /// datoer der kapasitet er full, og datoer der alle spots er blokkert.
    private var calendarBlockedDates: Set<String> {
        var set = Set(listing.blockedDates ?? [])
        let totalSpots = listing.spots ?? 1
        if let counts = bookedDates?.perDateCount {
            for (date, count) in counts where count >= totalSpots {
                set.insert(date)
            }
        }
        let markers = listing.spotMarkers ?? []
        if !markers.isEmpty {
            let perSpot = markers.map { effectiveSpotBlockedDates($0) }
            var candidates = Set<String>()
            perSpot.forEach { $0.forEach { candidates.insert($0) } }
            for d in candidates where perSpot.allSatisfy({ $0.contains(d) }) {
                set.insert(d)
            }
        }
        return set
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
                Text(baseLineLabel).font(.system(size: 14)).foregroundStyle(.neutral600)
                Spacer()
                Text("\(baseTotal) kr").font(.system(size: 14)).foregroundStyle(.neutral600)
            }
            if listingExtrasTotal + spotExtrasTotal > 0 {
                HStack {
                    Text("Tilleggstjenester").font(.system(size: 14)).foregroundStyle(.neutral600)
                    Spacer()
                    Text("\(listingExtrasTotal + spotExtrasTotal) kr").font(.system(size: 14)).foregroundStyle(.neutral600)
                }
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

    private var baseLineLabel: String {
        if hasSpotLevelPricing && !selectedSpots.isEmpty {
            return "\(selectedSpots.count) plass\(selectedSpots.count > 1 ? "er" : "") × \(nights) \(nights == 1 ? "natt" : "netter")"
        }
        return "\(listing.price ?? 0) kr × \(nights) \(nights == 1 ? "natt" : "netter")"
    }

    private var spotPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Velg plasser").font(.system(size: 18, weight: .semibold))
            ForEach(Array((listing.spotMarkers ?? []).enumerated()), id: \.offset) { idx, spot in
                if let sid = spot.id {
                    spotRow(spot: spot, index: idx, spotId: sid)
                }
            }
        }
    }

    private func effectiveSpotBlockedDates(_ spot: SpotMarker) -> Set<String> {
        var set = Set(spot.blockedDates ?? [])
        if let sid = spot.id, let booked = bookedDates?.perSpot[sid] {
            booked.forEach { set.insert($0) }
        }
        return set
    }

    private func isSpotBlockedByDates(_ spot: SpotMarker) -> Bool {
        guard let ci = checkIn, let co = checkOut else { return false }
        let blocked = effectiveSpotBlockedDates(spot)
        guard !blocked.isEmpty else { return false }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var cursor = Calendar.current.startOfDay(for: ci)
        let end = Calendar.current.startOfDay(for: co)
        while cursor < end {
            if blocked.contains(fmt.string(from: cursor)) { return true }
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return false
    }

    private func spotRow(spot: SpotMarker, index: Int, spotId: String) -> some View {
        let isSelected = selectedSpotIds.contains(spotId)
        let price = spot.price ?? listing.price ?? 0
        let isBlocked = isSpotBlockedByDates(spot)

        return VStack(spacing: 0) {
            Button {
                guard !isBlocked else { return }
                if isSelected { selectedSpotIds.remove(spotId) }
                else { selectedSpotIds.insert(spotId) }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(isBlocked ? Color.neutral100 : isSelected ? Color.primary600 : Color.neutral100).frame(width: 32, height: 32)
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(isBlocked ? .neutral400 : isSelected ? .white : .neutral500)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spot.label ?? "Plass \(index + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isBlocked ? .neutral400 : .neutral900)
                        Text(isBlocked ? "Ikke tilgjengelig for disse datoene" : "\(price) kr/natt")
                            .font(.system(size: 12)).foregroundStyle(.neutral500)
                    }
                    Spacer()
                    if !isBlocked {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color.primary600 : Color.neutral300, lineWidth: 2)
                                .frame(width: 20, height: 20)
                            if isSelected {
                                RoundedRectangle(cornerRadius: 4).fill(Color.primary600).frame(width: 20, height: 20)
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                    }
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            .disabled(isBlocked)
            .opacity(isBlocked ? 0.6 : 1.0)

            if isSelected, let extras = spot.extras, !extras.isEmpty {
                Divider().padding(.horizontal, 12)
                VStack(spacing: 8) {
                    ForEach(extras) { extra in
                        extraQtyRow(
                            name: extra.name,
                            price: extra.price,
                            perNight: extra.perNight,
                            qty: spotExtrasQty[spotId]?[extra.id] ?? 0,
                            onChange: { delta in
                                var map = spotExtrasQty[spotId] ?? [:]
                                let next = max(0, (map[extra.id] ?? 0) + delta)
                                if next == 0 { map.removeValue(forKey: extra.id) }
                                else { map[extra.id] = next }
                                if map.isEmpty { spotExtrasQty.removeValue(forKey: spotId) }
                                else { spotExtrasQty[spotId] = map }
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(isSelected ? Color.primary50 : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: isSelected ? 2 : 1))
    }

    private var listingExtrasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tilleggstjenester").font(.system(size: 18, weight: .semibold))
            ForEach(listing.extras ?? []) { extra in
                extraQtyRow(
                    name: extra.name,
                    price: extra.price,
                    perNight: extra.perNight,
                    qty: listingExtrasQty[extra.id] ?? 0,
                    onChange: { delta in
                        let next = max(0, (listingExtrasQty[extra.id] ?? 0) + delta)
                        if next == 0 { listingExtrasQty.removeValue(forKey: extra.id) }
                        else { listingExtrasQty[extra.id] = next }
                    }
                )
            }
        }
    }

    private func extraQtyRow(name: String, price: Int, perNight: Bool, qty: Int, onChange: @escaping (Int) -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14)).foregroundStyle(.neutral700)
                Text("\(price) kr\(perNight ? "/natt" : "")")
                    .font(.system(size: 11)).foregroundStyle(.neutral500)
            }
            Spacer()
            if qty > 0 {
                Text("\(price * (perNight ? nights : 1) * qty) kr")
                    .font(.system(size: 12)).foregroundStyle(.neutral500)
            }
            Button { onChange(-1) } label: {
                Image(systemName: "minus.circle").foregroundStyle(qty == 0 ? .neutral300 : .neutral500)
            }
            .disabled(qty == 0)
            .buttonStyle(.plain)
            Text("\(qty)").font(.system(size: 14, weight: .medium)).frame(width: 20)
            Button { onChange(1) } label: {
                Image(systemName: "plus.circle").foregroundStyle(.neutral500)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func checkAvailability() async {
        guard let ci = checkIn, let co = checkOut else {
            availableSpots = nil
            totalSpots = nil
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let result = await bookingService.checkAvailability(
            listingId: listing.id,
            checkIn: formatter.string(from: ci),
            checkOut: formatter.string(from: co)
        )
        availableSpots = result.available
        totalSpots = result.total
    }

    private func buildSelectedExtrasPayload() -> SelectedExtras? {
        var listingEntries: [SelectedExtraEntry] = []
        for extra in (listing.extras ?? []) {
            let qty = listingExtrasQty[extra.id] ?? 0
            if qty > 0 {
                listingEntries.append(SelectedExtraEntry(
                    id: extra.id, name: extra.name, price: extra.price,
                    perNight: extra.perNight, quantity: qty
                ))
            }
        }

        var spotEntries: [String: [SelectedExtraEntry]] = [:]
        for spot in selectedSpots {
            guard let sid = spot.id, let map = spotExtrasQty[sid] else { continue }
            let items = (spot.extras ?? []).compactMap { extra -> SelectedExtraEntry? in
                let qty = map[extra.id] ?? 0
                guard qty > 0 else { return nil }
                return SelectedExtraEntry(
                    id: extra.id, name: extra.name, price: extra.price,
                    perNight: extra.perNight, quantity: qty
                )
            }
            if !items.isEmpty { spotEntries[sid] = items }
        }

        if listingEntries.isEmpty && spotEntries.isEmpty { return nil }
        return SelectedExtras(
            listing: listingEntries.isEmpty ? nil : listingEntries,
            spots: spotEntries.isEmpty ? nil : spotEntries
        )
    }

    private func createBookingIfNeeded() async {
        guard bookingService.clientSecret == nil else { return }
        guard let ci = checkIn, let co = checkOut else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = CreateBookingRequest(
            listingId: listing.id,
            checkIn: formatter.string(from: ci),
            checkOut: formatter.string(from: co),
            licensePlate: isRentalCar ? nil : licensePlate.trimmingCharacters(in: .whitespaces).uppercased(),
            isRentalCar: isRentalCar,
            selectedSpotIds: selectedSpotIds.isEmpty ? nil : Array(selectedSpotIds),
            selectedExtras: buildSelectedExtrasPayload()
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
