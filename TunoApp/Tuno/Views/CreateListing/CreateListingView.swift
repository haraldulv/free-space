import SwiftUI
import UIKit

/// Tuno's "Ny annonse"-wizard. 11 steg, ett spørsmål per skjerm. Hvert steg
/// ligger i sin egen fil under `Steps/`. Container'en holder kun
/// progress-bar, error-banner, swipe-bar mellom stegene og submit-logikk.
struct CreateListingView: View {
    var onCreated: ((Listing) -> Void)? = nil
    /// Hvis satt: gjenoppta wizarden fra dette utkastet ved første visning.
    var initialDraft: DraftListing? = nil

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var form = ListingFormModel()
    @StateObject private var placesService = PlacesService()

    @Environment(\.dismiss) private var dismiss
    @State private var showCancelAlert = false
    @State private var showSuccess = false
    @State private var newListing: Listing?
    /// True når iOS-tastaturet er åpent. Skjuler WizardNavBar så den ikke
    /// kolliderer med "Ferdig"-knappen i tastatur-toolbaren.
    @State private var keyboardVisible = false

    var body: some View {
        mainContent
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)
            .toolbar(content: cancelToolbar)
            .toolbar(content: spotIndicatorToolbar)
            .alert("Lukk wizarden?", isPresented: $showCancelAlert, actions: {
                Button("Forkast utkast", role: .destructive) {
                    if let userId = authManager.currentUser?.id.uuidString {
                        form.clearDraft(userId: userId)
                    }
                    dismiss()
                }
                Button("Lukk og lagre", role: .cancel) {
                    if let userId = authManager.currentUser?.id.uuidString {
                        form.saveDraft(userId: userId)
                    }
                    dismiss()
                }
            }, message: {
                Text("Vi lagrer fremdriften din som utkast så du kan fortsette senere fra Mine annonser.")
            })
            .overlay { successOverlay }
            .animation(.easeInOut(duration: 0.3), value: showSuccess)
            .onAppear {
                if let draft = initialDraft {
                    form.loadFromDraft(draft)
                }
            }
            .onChange(of: form.currentStep) { _, newStep in
                // Auto-lagre etter hver steg-overgang så bruker aldri mister
                // progress hvis appen drepes eller terminerer i bakgrunnen.
                guard newStep > 0, let userId = authManager.currentUser?.id.uuidString else { return }
                form.saveDraft(userId: userId)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeOut(duration: 0.22)) { keyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.22)) { keyboardVisible = false }
            }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if !form.fullscreenStep {
                WizardProgressBar(progress: form.displayProgress)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            errorBanner

            stepsTabView
        }
        // Opaque bg så iOS 26 fullScreenCover ikke render-er translucent og
        // viser dashboard-listen gjennom wizarden når brukeren re-åpner draft.
        .background(Color.white)
        .animation(.easeInOut(duration: 0.22), value: form.fullscreenStep)
        // Tap utenfor felter lukker tastaturet — standard iOS-mønster.
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .safeAreaInset(edge: .bottom) {
            if keyboardVisible {
                keyboardDoneBar.transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                navBar.transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Vises i stedet for navBar når tastaturet er åpent. SwiftUI sin
    /// `.toolbar(placement: .keyboard)` rendrer ikke pålitelig på numberPad,
    /// så vi bygger vår egen "Ferdig"-knapp som ligger over tastaturet via
    /// safeAreaInset. Floating sirkel uten bakgrunnsboks.
    private var keyboardDoneBar: some View {
        HStack {
            Spacer()
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.primary600)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            }
            .accessibilityLabel("Skjul tastatur")
        }
        .padding(.trailing, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = form.error {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(error)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Custom switch-based step container. Erstatter TabView(.page) som
    /// tillot horisontal sveiping forbi deaktiverte Neste-knapper. Nå
    /// styres flyten utelukkende av WizardNavBar-knappene.
    @ViewBuilder
    private func currentStepView() -> some View {
        switch form.currentStep {
        case 0: WelcomeStep(form: form)
        case 1: CategoryStep(form: form)
        case 2: AddressStep(form: form, placesService: placesService)
        case 3: SpotCountStep(form: form)
        case 4: MarkSpotsStep(form: form)
        case 5: SpotDetailsStep(form: form)
        case 6: OpeningHoursStep(form: form)
        case 7: SpotPriceStep(form: form)
        case 8: SpotPriceVariationStep(form: form)
        case 9: SpotExtrasStep(form: form)
        case 10: SpotDiscountsStep(form: form)
        case 11: InstantBookingStep(form: form)
        case 12: DescriptionStep(form: form)
        case 13: PhotosStep(form: form)
        case 14: AmenitiesStep(form: form)
        case 15: MessagesStep(form: form)
        case 16: CalendarStep(form: form)
        case 17: PublishStep(form: form)
        default: EmptyView()
        }
    }

    private var stepsTabView: some View {
        currentStepView()
            .id(form.currentStep)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.32), value: form.currentStep)
    }

    private var navBar: some View {
        WizardNavBar(
            canGoBack: form.currentStep > 0,
            nextLabel: nextLabel,
            nextEnabled: form.canAdvance && !form.isSubmitting,
            nextLoading: form.isSubmitting,
            skipLabel: nil,
            onBack: handleBack,
            onNext: handleNext,
            onSkip: nil
        )
    }

    /// Plass-indikator i nav-barens prinsipale slot — vises bare på
    /// mini-wizard-steg (Kjøretøy/Pris/Tillegg) når det er flere enn én plass.
    /// Plassert sammen med Avbryt-krysset så den ikke spiser plass i selve
    /// innholdsområdet.
    @ToolbarContentBuilder
    private func spotIndicatorToolbar() -> some ToolbarContent {
        if form.currentStepHasMiniWizard && form.spotMarkers.count > 1 {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 5) {
                    Text("Plass \(form.currentSpotIndex + 1)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary600)
                        .contentTransition(.numericText())
                    Text("av \(form.spotMarkers.count)")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.neutral500)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: form.currentSpotIndex)
            }
        }
    }

    @ViewBuilder
    private var successOverlay: some View {
        if showSuccess {
            ListingPublishedCelebration(onDismiss: {
                if let l = newListing {
                    onCreated?(l)
                }
                dismiss()
            })
            .transition(.opacity)
        }
    }

    @ToolbarContentBuilder
    private func cancelToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            // True native iOS toolbar dismiss — plain xmark glyph, ingen sirkel.
            // Matcher det Apple bruker i Mail/Settings/etc. når man lukker en modal.
            // Skjules i fullscreenStep (kalender-editor) for å gi mer plass.
            if !form.fullscreenStep {
                Button(action: { showCancelAlert = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral700)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Avbryt")
            }
        }
    }

    // MARK: - Computed labels

    private var stepLabel: String? {
        guard form.currentStep < form.stepLabels.count else { return nil }
        let label = form.stepLabels[form.currentStep]
        if form.currentStep == 0 { return nil }
        return "Steg \(form.currentStep) av \(form.totalSteps - 1) · \(label)"
    }

    private var nextLabel: String {
        switch form.currentStep {
        case 0: return "Kom i gang"
        case form.totalSteps - 1: return "Publiser annonse"
        default: return "Neste"
        }
    }

    // MARK: - Handlers

    private func handleBack() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        form.goBack()
    }

    private func handleNext() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if form.currentStep == form.totalSteps - 1 {
            submitListing()
        } else {
            form.goNext()
        }
    }

    // MARK: - Submit

    private func submitListing() {
        guard let userId = authManager.currentUser?.id else { return }

        // Defensiv gate: BecomeHostView blokkerer normalt før vi når hit,
        // men vi sjekker likevel slik at en bruker som omgår UI-laget
        // (deep link, debug, race-condition under loadProfile) ikke kan
        // publisere uten godkjent Stripe-konto.
        if authManager.profile?.stripeOnboardingComplete != true {
            form.error = "Du må fullføre utleier-oppsettet før du kan publisere en annonse."
            return
        }

        form.isSubmitting = true
        form.error = nil

        Task {
            do {
                let input = form.buildInput(hostId: userId.uuidString.lowercased(), profile: authManager.profile)
                let inserted: [Listing] = try await supabase
                    .from("listings")
                    .insert(input)
                    .select()
                    .execute()
                    .value

                await authManager.loadProfile()
                if let listing = inserted.first {
                    // Persist tilgjengelighets-bånd + pris-overstyring per plass.
                    // For hver plass:
                    //   1) Default-bånd-rad per tilgjengelighets-bånd (price=basePerHour, alle uker)
                    //   2) Override-bånd-rader for hvert bandPriceOverride (per uke-scope)
                    //   3) Date-overrides → listing_pricing_overrides (per dato)
                    for spot in form.spotMarkers {
                        guard let spotId = spot.id else { continue }
                        let avail = form.availability(for: spotId)
                        let basePerHour = spot.pricePerHour ?? 0
                        // 1) Default-bånd-rader (per allWeeks default-pris).
                        // Bruk bandets egen pris hvis satt — det lar verten ha
                        // ulike priser per bånd (f.eks. dag/kveld/natt eller
                        // sommer/vinter for camping).
                        for band in avail.bands {
                            let bandBasePrice = band.price > 0 ? band.price : basePerHour
                            if band.isSeasonal, let bStart = band.startDate, let bEnd = band.endDate {
                                // Camping-sesongbånd → kind='season'.
                                // dayMask=0 betyr "alle dager" (server tolker 0 som
                                // ingen filter). Sender 0 i stedet for NULL slik at
                                // vi unngår å avhenge av en migration som relakser
                                // NOT NULL-constraintet.
                                try? await PricingService.addSeasonBandRule(
                                    listingId: listing.id,
                                    dayMask: band.dayMask,
                                    startDate: bStart,
                                    endDate: bEnd,
                                    price: bandBasePrice,
                                    spotId: spotId,
                                    colorIndex: band.colorIndex
                                )
                            } else {
                                // Parking-time-bånd → kind='hourly'
                                try? await PricingService.addHourlyBandRule(
                                    listingId: listing.id,
                                    dayMask: band.dayMask,
                                    startHour: band.startHour,
                                    startMinute: band.startMinute,
                                    endHour: band.endHour,
                                    endMinute: band.endMinute,
                                    price: bandBasePrice,
                                    startDate: nil,
                                    endDate: nil,
                                    spotId: spotId,
                                    colorIndex: band.colorIndex
                                )
                            }
                        }
                        // 2) Override-bånd-rader: én rad per uke i scope
                        for override in avail.bandPriceOverrides {
                            guard let band = avail.bands.first(where: { $0.id == override.bandId }) else { continue }
                            switch override.weekScope {
                            case .allWeeks:
                                try? await PricingService.addHourlyBandRule(
                                    listingId: listing.id,
                                    dayMask: band.dayMask,
                                    startHour: band.startHour,
                                    startMinute: band.startMinute,
                                    endHour: band.endHour,
                                    endMinute: band.endMinute,
                                    price: override.price,
                                    startDate: nil,
                                    endDate: nil,
                                    spotId: spotId
                                )
                            case .specificWeeks(let weeks):
                                for week in weeks {
                                    guard let range = WizardPricingCalendarView.dateRangeForWeek(year: week.year, week: week.weekNum) else { continue }
                                    try? await PricingService.addHourlyBandRule(
                                        listingId: listing.id,
                                        dayMask: band.dayMask,
                                        startHour: band.startHour,
                                        startMinute: band.startMinute,
                                        endHour: band.endHour,
                                        endMinute: band.endMinute,
                                        price: override.price,
                                        startDate: range.start,
                                        endDate: range.end,
                                        spotId: spotId
                                    )
                                }
                            }
                        }
                        // 3) Date-overrides
                        for dateOverride in avail.dateOverrides {
                            try? await PricingService.setOverride(
                                listingId: listing.id,
                                date: dateOverride.date,
                                price: dateOverride.price,
                                spotId: spotId
                            )
                        }
                    }

                    newListing = listing
                }
                form.isSubmitting = false
                // Publisering vellykket — slett utkastet så verten ikke ser
                // det som "Fortsett utkast" i Mine annonser.
                form.clearDraft(userId: userId.uuidString)
                withAnimation { showSuccess = true }
            } catch {
                form.error = "Kunne ikke opprette annonse: \(error.localizedDescription)"
                form.isSubmitting = false
            }
        }
    }
}
