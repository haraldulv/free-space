import SwiftUI
import UIKit

/// Tuno's "Ny annonse"-wizard. 11 steg, ett spørsmål per skjerm. Hvert steg
/// ligger i sin egen fil under `Steps/`. Container'en holder kun
/// progress-bar, error-banner, swipe-bar mellom stegene og submit-logikk.
struct CreateListingView: View {
    var onCreated: ((Listing) -> Void)? = nil

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
            .alert("Avbryt og forkast?", isPresented: $showCancelAlert, actions: {
                Button("Forkast", role: .destructive) { dismiss() }
                Button("Fortsett å redigere", role: .cancel) {}
            }, message: {
                Text("Du mister alt du har skrevet inn.")
            })
            .overlay { successOverlay }
            .animation(.easeInOut(duration: 0.3), value: showSuccess)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeOut(duration: 0.22)) { keyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.22)) { keyboardVisible = false }
            }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            WizardProgressBar(progress: form.displayProgress)
                .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 12)

            errorBanner

            stepsTabView
        }
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
    /// så vi bygger vår egen "Ferdig"-bar som ligger over tastaturet via
    /// safeAreaInset.
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
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            }
            .accessibilityLabel("Skjul tastatur")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Color(UIColor.systemBackground)
                .opacity(0.95)
                .ignoresSafeArea()
        )
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

    private var stepsTabView: some View {
        TabView(selection: $form.currentStep) {
            WelcomeStep(form: form).tag(0)
            CategoryStep(form: form).tag(1)
            AddressStep(form: form, placesService: placesService).tag(2)
            SpotCountStep(form: form).tag(3)
            MarkSpotsStep(form: form).tag(4)
            SpotDetailsStep(form: form).tag(5)
            SpotPriceStep(form: form).tag(6)
            SpotExtrasStep(form: form).tag(7)
            InstantBookingStep(form: form).tag(8)
            DescriptionStep(form: form).tag(9)
            PhotosStep(form: form).tag(10)
            AmenitiesStep(form: form).tag(11)
            MessagesStep(form: form).tag(12)
            PriceRulesStep(form: form).tag(13)
            CalendarStep(form: form).tag(14)
            PublishStep(form: form).tag(15)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
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
            Button(action: { showCancelAlert = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral700)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Avbryt")
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
                    // Persist time-bånd-regler (parkering per time) etter at listing-id finnes.
                    // Uke-spesifikke bånd (dragget til en uke i kalenderen) får
                    // start_date/end_date for den ISO-uken; default-bånd er nil/nil.
                    for band in form.pricingBands {
                        var startDate: String? = nil
                        var endDate: String? = nil
                        if case .specificWeek(let y, let w) = band.weekScope,
                           let range = PriceRulesStep.dateRangeForWeek(year: y, week: w) {
                            startDate = range.start
                            endDate = range.end
                        }
                        try? await PricingService.addHourlyBandRule(
                            listingId: listing.id,
                            dayMask: band.dayMask,
                            startHour: band.startHour,
                            endHour: band.endHour,
                            price: band.price,
                            startDate: startDate,
                            endDate: endDate
                        )
                    }
                    newListing = listing
                }
                form.isSubmitting = false
                withAnimation { showSuccess = true }
            } catch {
                form.error = "Kunne ikke opprette annonse: \(error.localizedDescription)"
                form.isSubmitting = false
            }
        }
    }
}
