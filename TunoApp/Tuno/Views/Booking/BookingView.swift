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
    /// Optional: forvalg plass (brukes når man klikker på et Plasser-kort fra
    /// annonsesiden — da pre-velges den plassen i selectedSpotIds).
    var preSelectedSpotId: String? = nil

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var bookingService = BookingService()
    @Environment(\.dismiss) var dismiss

    @State private var checkIn: Date? = nil
    @State private var checkOut: Date? = nil
    @State private var showCalendar = false
    /// Hvilken dato (innsjekk vs utsjekk) som redigeres når calendarSheet
    /// åpnes for hourly-modus. true = innsjekk, false = utsjekk.
    @State private var calendarEditingStart = true
    /// For hourly-mode: brukeren velger én dato + start-/slutt-time.
    /// Disse settes etter dato-velg og driver checkIn/checkOut (selve datoene
    /// kombineres med timene før insert).
    /// Innsjekk-dato for hourly booking (uten klokke).
    @State private var hourlyDate: Date? = nil
    /// Utsjekk-dato — settes automatisk = hourlyDate, men kan overstyres
    /// hvis brukeren parkerer over natt (f.eks. innsjekk 22:00, utsjekk 08:00 dagen etter).
    @State private var hourlyEndDate: Date? = nil
    /// Totalminutter siden midnatt (0..1440, 30-min step). Default = nåværende
    /// tid rundet opp til nærmeste 30 min (samme som kartsøket). End = +1 time.
    @State private var startMinutes: Int = BookingView.roundedNowMinutes()
    @State private var endMinutes: Int = min(24 * 60, BookingView.roundedNowMinutes() + 60)

    /// Nåværende klokkeslett rundet opp til nærmeste hele 30 minutter.
    private static func roundedNowMinutes() -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let total = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let snapped = ((total + 29) / 30) * 30
        return min(snapped, 24 * 60)
    }
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
    @State private var nightlyPriceBreakdown: [NightlyPriceEntry] = []
    @State private var hourlyPriceBreakdown: [HourlyPriceEntry] = []
    @State private var loadingBreakdown = false

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

    private var hours: Int {
        guard isHourly, let ci = checkIn, let co = checkOut else { return 0 }
        return max(1, Calendar.current.dateComponents([.hour], from: ci, to: co).hour ?? 1)
    }

    /// Antall enheter for pris-beregning — timer for parkering per time, netter ellers.
    private var unitsCount: Int { isHourly ? hours : nights }

    /// Hvilken pris-modell denne bookingen følger. Per-time krever at ALLE valgte plasser
    /// er .hour (eller listing-nivå er .hour). Mixed-mode er ikke støttet for booking;
    /// fallback til natt/døgn.
    private var effectiveBookingPriceUnit: PriceUnit {
        // Parkering er per-time-only — døgn-rabatt-flow tar over senere.
        if listing.category == .parking { return .hour }
        if !selectedSpots.isEmpty {
            let units = selectedSpots.compactMap { $0.priceUnit }
            if !units.isEmpty, units.allSatisfy({ $0 == .hour }) { return .hour }
        }
        return listing.priceUnit ?? .natt
    }

    private var isHourly: Bool { effectiveBookingPriceUnit == .hour }

    private var hasDates: Bool { checkIn != nil && checkOut != nil }

    private var baseTotal: Int {
        let units = unitsCount
        if hasSpotLevelPricing && !selectedSpots.isEmpty {
            return selectedSpots.reduce(0) { $0 + ($1.price ?? listing.price ?? 0) * units }
        }
        if isHourly, !hourlyPriceBreakdown.isEmpty {
            // hourlyPriceBreakdown brukes for parkering per time (band-basert per-time-pris).
            return hourlyPriceBreakdown.reduce(0) { $0 + $1.price }
        }
        if !nightlyPriceBreakdown.isEmpty, !isHourly {
            // nightlyPriceBreakdown brukes kun for camping/døgn (regler-basert per-natt-pris).
            let perNight = nightlyPriceBreakdown.reduce(0) { $0 + $1.price }
            let spotMultiplier = selectedSpots.count > 1 ? selectedSpots.count : 1
            return perNight * spotMultiplier
        }
        return units * (listing.price ?? 0)
    }

    private func loadPriceBreakdown() {
        if isHourly {
            loadHourlyPriceBreakdown()
            return
        }
        guard let checkIn, let checkOut, nights > 0, !hasSpotLevelPricing else {
            nightlyPriceBreakdown = []
            return
        }
        loadingBreakdown = true
        Task {
            let breakdown = await PricingService.nightlyPrices(
                listingId: listing.id,
                basePrice: listing.price ?? 0,
                checkIn: checkIn,
                checkOut: checkOut,
            )
            await MainActor.run {
                nightlyPriceBreakdown = breakdown
                loadingBreakdown = false
            }
        }
    }

    private func loadHourlyPriceBreakdown() {
        guard let ci = checkIn, let co = checkOut, hours > 0, !hasSpotLevelPricing else {
            hourlyPriceBreakdown = []
            return
        }
        loadingBreakdown = true
        Task {
            let breakdown = await PricingService.hourlyPriceBreakdown(
                listingId: listing.id,
                baseHourlyPrice: listing.price ?? 0,
                start: ci,
                end: co,
            )
            await MainActor.run {
                hourlyPriceBreakdown = breakdown
                loadingBreakdown = false
            }
        }
    }

    /// `perNight` på extras betyr "per natt/døgn" — for hourly bookings betales
    /// extras alltid som engangsbeløp (1 enhet), uansett antall timer.
    private var extrasUnits: Int { isHourly ? 1 : nights }

    private var listingExtrasTotal: Int {
        (listing.extras ?? []).reduce(0) { sum, extra in
            let qty = listingExtrasQty[extra.id] ?? 0
            return sum + extra.price * (extra.perNight ? extrasUnits : 1) * qty
        }
    }

    private var spotExtrasTotal: Int {
        selectedSpots.reduce(0) { sum, spot in
            guard let sid = spot.id, let map = spotExtrasQty[sid] else { return sum }
            let perSpot = (spot.extras ?? []).reduce(0) { acc, extra in
                acc + extra.price * (extra.perNight ? extrasUnits : 1) * (map[extra.id] ?? 0)
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
        let datesOK = isHourly ? (hourlyDate != nil && endMinutes > startMinutes) : hasDates
        return datesOK && vehicleOK && spotOK
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                listingSummary

                // Døgn-banner vises kun for parkering som IKKE er per-time
                // (per-time parkering har full booking-flow nå).
                if listing.category == .parking && !isHourly {
                    parkingPreviewBanner
                }

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

                if listing.instantBooking == true && nights > 7 {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                        Text("Opphold på mer enn 7 netter krever godkjenning fra utleier. Beløpet reserveres på kortet ditt og belastes først når utleier godkjenner.")
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral700)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

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
        .sheet(isPresented: $showCalendar) {
            calendarSheet
        }
        .task {
            // Forvalg plass hvis brukeren klikket seg inn fra et Plasser-kort.
            if let preId = preSelectedSpotId, selectedSpotIds.isEmpty {
                selectedSpotIds.insert(preId)
            }
            // Pre-fyll datoer/tidspunkter fra kartsøket — brukeren slipper å
            // skrive samme info to ganger. Bare når lokal state er null.
            let ctx = SearchContextStore.shared
            if checkIn == nil, let storedIn = ctx.checkIn { checkIn = storedIn }
            if checkOut == nil, let storedOut = ctx.checkOut { checkOut = storedOut }
            if isHourly {
                // Pre-fyll fra context (kartsøk), eller default til i dag.
                if hourlyDate == nil {
                    if let storedIn = ctx.checkIn {
                        hourlyDate = Calendar.current.startOfDay(for: storedIn)
                    } else {
                        hourlyDate = Calendar.current.startOfDay(for: Date())
                    }
                }
                if hourlyEndDate == nil {
                    if let storedOut = ctx.checkOut {
                        hourlyEndDate = Calendar.current.startOfDay(for: storedOut)
                    } else {
                        hourlyEndDate = hourlyDate
                    }
                }
                if let s = ctx.startMinutes { startMinutes = s }
                if let e = ctx.endMinutes { endMinutes = e }
                syncHourlyToCheckInOut()
            }
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
            loadPriceBreakdown()
        }
        .onChange(of: checkOut) {
            showCardForm = false
            bookingService.clientSecret = nil
            deselectBlockedSpots()
            Task { await checkAvailability() }
            loadPriceBreakdown()
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

    /// Vises kun for parking-listings inntil time-spesifikk booking lanseres (Fase 2).
    /// Booking i dag bruker hele døgn — vi gjør dette eksplisitt for gjesten.
    private var parkingPreviewBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.primary600)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text("Parkering bookes per døgn foreløpig")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("Time-spesifikk parkering kommer snart. Inntil videre regnes hvert valgte døgn som ett 24-timers opphold.")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral600)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary200, lineWidth: 1))
    }

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

    @ViewBuilder
    private var dateSection: some View {
        if isHourly { hourlyDateSection } else { nightlyDateSection }
    }

    private var nightlyDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Datoer")
                .font(.system(size: 18, weight: .semibold))
            Button {
                showCalendar = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.neutral500)
                    if let ci = checkIn, let co = checkOut {
                        Text("\(formatShort(ci)) – \(formatShort(co))")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.neutral900)
                    } else if let ci = checkIn {
                        Text("Fra \(formatShort(ci)), velg utsjekk")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.neutral700)
                    } else {
                        Text("Velg datoer")
                            .font(.system(size: 15))
                            .foregroundStyle(.neutral500)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
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

            if hasDates {
                let unitLabel = (effectiveBookingPriceUnit == .time) ? "døgn" : "natt"
                Text("\(nights) \(nights == 1 ? unitLabel : unitLabel + (unitLabel == "døgn" ? "" : "er"))")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
            }
        }
    }

    private var hourlyDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Når ankommer du?")
                .font(.system(size: 18, weight: .semibold))

            // Hurtigknapper for varighet — synlig umiddelbart så brukeren
            // raskt kan velge "1 time / 2 timer / 4 timer" uten å måtte
            // navigere kalender og tidspunkt-velgere først.
            HStack(spacing: 8) {
                durationQuickChip(label: "1 time", hours: 1)
                durationQuickChip(label: "2 timer", hours: 2)
                durationQuickChip(label: "4 timer", hours: 4)
            }

            // Innsjekk + utsjekk dato-velgere
            HStack(spacing: 8) {
                hourlyDateChip(label: "Innsjekk", date: hourlyDate, isStart: true)
                hourlyDateChip(label: "Utsjekk", date: hourlyEndDate ?? hourlyDate, isStart: false)
            }

            // Tids-rullehjul — alltid synlig (samme som kartsøket).
            HStack(spacing: 16) {
                TimeWheelPicker(label: "Fra", minutes: Binding(
                    get: { startMinutes },
                    set: { startMinutes = $0 ?? startMinutes }
                ))
                .frame(maxWidth: .infinity)
                TimeWheelPicker(label: "Til", minutes: Binding(
                    get: { endMinutes },
                    set: { endMinutes = $0 ?? endMinutes }
                ))
                .frame(maxWidth: .infinity)
            }

            if hours > 0 {
                Text("\(hours) \(hours == 1 ? "time" : "timer")")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
            }
        }
        .onChange(of: hourlyDate) { _, newDate in
            // Default utsjekk = innsjekk hvis ikke satt eller utsjekk er før innsjekk
            if let nd = newDate {
                if hourlyEndDate == nil { hourlyEndDate = nd }
                else if let end = hourlyEndDate, end < nd { hourlyEndDate = nd }
            }
            syncHourlyToCheckInOut()
        }
        .onChange(of: hourlyEndDate) { _, _ in syncHourlyToCheckInOut() }
        .onChange(of: startMinutes) { _, newValue in
            if (hourlyEndDate ?? hourlyDate) == hourlyDate, endMinutes <= newValue {
                endMinutes = min(24 * 60, newValue + 30)
            }
            syncHourlyToCheckInOut()
        }
        .onChange(of: endMinutes) { _, _ in syncHourlyToCheckInOut() }
    }

    /// Kompakt dato-chip for innsjekk/utsjekk i parkering-flyt. Tap åpner
    /// dato-kalender-sheet og setter hourlyDate (innsjekk) eller hourlyEndDate (utsjekk).
    private func hourlyDateChip(label: String, date: Date?, isStart: Bool) -> some View {
        Button {
            calendarEditingStart = isStart
            // Pre-fyll calendar-binding med eksisterende dato så brukeren ser hvor de er.
            checkIn = isStart ? hourlyDate : (hourlyEndDate ?? hourlyDate)
            showCalendar = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.neutral500)
                Text(date.map(formatShort) ?? "Velg dato")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(date == nil ? .neutral400 : .neutral900)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Hurtigvalg for varighet (samme som kartsøk). Setter endMinutes/endDate
    /// basert på startMinutes + N timer. Hvis det krysser midnatt, bumper utsjekk-dato.
    private func durationQuickChip(label: String, hours: Int) -> some View {
        let totalMinutes = startMinutes + hours * 60
        let crossesMidnight = totalMinutes > 24 * 60
        let targetEndMinutes = crossesMidnight ? totalMinutes - 24 * 60 : totalMinutes
        let isSelected: Bool = {
            guard endMinutes == targetEndMinutes else { return false }
            if crossesMidnight {
                guard let start = hourlyDate, let end = hourlyEndDate else { return false }
                let cal = Calendar.current
                return cal.dateComponents([.day], from: start, to: end).day == 1
            } else {
                return (hourlyEndDate ?? hourlyDate) == hourlyDate
            }
        }()
        return Button {
            endMinutes = targetEndMinutes
            if let start = hourlyDate {
                hourlyEndDate = crossesMidnight
                    ? Calendar.current.date(byAdding: .day, value: 1, to: start)
                    : start
            }
            syncHourlyToCheckInOut()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .neutral900)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.neutral900 : Color.neutral50)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Bygg checkIn/checkOut Date-objekter fra hourlyDate (start) + hourlyEndDate +
    /// start/endMinutes. Innsjekk og utsjekk er ofte samme dag, men hourlyEndDate
    /// kan også være senere for parkering over natt.
    private func syncHourlyToCheckInOut() {
        guard isHourly, let startDay = hourlyDate else { return }
        let cal = Calendar.current
        let inDay = cal.startOfDay(for: startDay)
        let outDay = cal.startOfDay(for: hourlyEndDate ?? startDay)
        checkIn = cal.date(byAdding: .minute, value: startMinutes, to: inDay)
        checkOut = cal.date(byAdding: .minute, value: endMinutes, to: outDay)
    }

    private var calendarSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isHourly {
                    // Hourly: én dato. Bruker en lokal "anchor"-dato i checkIn-binding,
                    // og setter hourlyDate når brukeren bekrefter.
                    BookingCalendarView(
                        checkIn: $checkIn,
                        checkOut: .constant(nil),
                        blockedDates: calendarBlockedDates,
                        minDate: Calendar.current.startOfDay(for: Date())
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                } else {
                    BookingCalendarView(
                        checkIn: $checkIn,
                        checkOut: $checkOut,
                        blockedDates: calendarBlockedDates,
                        minDate: Calendar.current.startOfDay(for: Date())
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }
                Spacer(minLength: 0)
                Divider()
                HStack {
                    Button("Nullstill") {
                        checkIn = nil
                        checkOut = nil
                        hourlyDate = nil
                    }
                    .disabled(checkIn == nil && checkOut == nil && hourlyDate == nil)
                    .foregroundStyle(.neutral600)
                    Spacer()
                    Button {
                        if isHourly, let ci = checkIn {
                            let day = Calendar.current.startOfDay(for: ci)
                            if calendarEditingStart {
                                hourlyDate = day
                                // Sørg for at utsjekk ikke er før innsjekk
                                if let end = hourlyEndDate, end < day { hourlyEndDate = day }
                            } else {
                                hourlyEndDate = day
                            }
                            syncHourlyToCheckInOut()
                        }
                        showCalendar = false
                    } label: {
                        Text((isHourly ? checkIn != nil : hasDates) ? "Bekreft" : "Lukk")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background((isHourly ? checkIn != nil : hasDates) ? Color.primary600 : Color.neutral400)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
            }
            .navigationTitle(isHourly ? "Velg dato" : "Velg datoer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk") { showCalendar = false }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
            if let groups = hourlyGroups, groups.count > 1 {
                ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                    HStack(spacing: 4) {
                        Text("\(g.price) kr × \(g.count) \(g.count == 1 ? "time" : "timer")")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral600)
                        Text("(\(hourlySourceLabel(g.source)))")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral400)
                        Spacer()
                        Text("\(g.price * g.count) kr")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral600)
                    }
                }
            } else if let groups = nightlyGroups, groups.count > 1 {
                ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                    HStack(spacing: 4) {
                        Text("\(g.price) kr × \(g.count) \(g.count == 1 ? "natt" : "netter")")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral600)
                        Text("(\(sourceLabel(g.source)))")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral400)
                        Spacer()
                        Text("\(g.price * g.count) kr")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral600)
                    }
                }
                if selectedSpots.count > 1 {
                    HStack {
                        Text("× \(selectedSpots.count) plasser")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral500)
                        Spacer()
                        Text("\(baseTotal) kr")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral500)
                    }
                }
            } else {
                HStack {
                    Text(baseLineLabel).font(.system(size: 14)).foregroundStyle(.neutral600)
                    Spacer()
                    Text("\(baseTotal) kr").font(.system(size: 14)).foregroundStyle(.neutral600)
                }
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

    private var nightlyGroups: [(price: Int, source: String, count: Int)]? {
        guard !nightlyPriceBreakdown.isEmpty, !hasSpotLevelPricing else { return nil }
        var result: [(price: Int, source: String, count: Int)] = []
        for entry in nightlyPriceBreakdown {
            if let last = result.last, last.price == entry.price, last.source == entry.source {
                result[result.count - 1].count += 1
            } else {
                result.append((price: entry.price, source: entry.source, count: 1))
            }
        }
        return result
    }

    private var hourlyGroups: [(price: Int, source: String, count: Int)]? {
        guard isHourly, !hourlyPriceBreakdown.isEmpty, !hasSpotLevelPricing else { return nil }
        var result: [(price: Int, source: String, count: Int)] = []
        for entry in hourlyPriceBreakdown {
            if let last = result.last, last.price == entry.price, last.source == entry.source {
                result[result.count - 1].count += 1
            } else {
                result.append((price: entry.price, source: entry.source, count: 1))
            }
        }
        return result
    }

    private func sourceLabel(_ source: String) -> String {
        switch source {
        case "weekend": return "helg"
        case "season": return "sesong"
        case "override": return "tilpasset"
        default: return "standard"
        }
    }

    private func hourlySourceLabel(_ source: String) -> String {
        switch source {
        case "hourly": return "tidsbånd"
        case "override": return "tilpasset"
        default: return "standard"
        }
    }

    private var baseLineLabel: String {
        if isHourly {
            if hasSpotLevelPricing && !selectedSpots.isEmpty {
                return "\(selectedSpots.count) plass\(selectedSpots.count > 1 ? "er" : "") × \(hours) \(hours == 1 ? "time" : "timer")"
            }
            return "\(listing.price ?? 0) kr × \(hours) \(hours == 1 ? "time" : "timer")"
        }
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
                        Text(isBlocked ? "Ikke tilgjengelig for disse datoene" : "\(price) kr/\((spot.priceUnit ?? listing.priceUnit ?? .natt).displayName)")
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        // For hourly: check_in/check_out skal være samme dato (selve timene ligger i checkInAt/checkOutAt).
        // For daily: check_in/check_out er ulike datoer.
        let dateForCheckIn = isHourly ? Calendar.current.startOfDay(for: ci) : ci
        let dateForCheckOut = isHourly ? Calendar.current.startOfDay(for: ci) : co

        let request = CreateBookingRequest(
            listingId: listing.id,
            checkIn: dateFormatter.string(from: dateForCheckIn),
            checkOut: dateFormatter.string(from: dateForCheckOut),
            checkInAt: isHourly ? isoFormatter.string(from: ci) : nil,
            checkOutAt: isHourly ? isoFormatter.string(from: co) : nil,
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
