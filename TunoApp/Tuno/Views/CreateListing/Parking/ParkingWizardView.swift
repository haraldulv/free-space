import SwiftUI
import UIKit

/// Parkering-wizarden (Asker-pivoten): 4 steg i stedet for 17.
/// Adresse → Plass og pris → Bilder → Publiser. Stripe-verifisering kommer
/// ETTER publisering (ParkingStripePrompt), ikke som port foran wizarden.
struct ParkingWizardView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var form = ListingFormModel()
    @StateObject private var placesService = PlacesService()
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var showCancelAlert = false
    @State private var showSuccess = false
    @State private var showStripePrompt = false
    @State private var keyboardVisible = false

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            WizardProgressBar(progress: Double(step + 1) / Double(totalSteps))
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 12)

            errorBanner

            currentStepView
                .id(step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.32), value: step)
        }
        .background(Color.neutral50)
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .safeAreaInset(edge: .bottom) {
            if !keyboardVisible {
                navBar.transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if keyboardVisible {
                keyboardDoneButton
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if step == 0 { dismiss() } else { showCancelAlert = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral700)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Avbryt")
            }
        }
        .alert("Lukk ny annonse?", isPresented: $showCancelAlert) {
            Button("Lukk", role: .destructive) { dismiss() }
            Button("Fortsett å redigere", role: .cancel) { }
        } message: {
            Text("Det du har fylt ut blir ikke lagret.")
        }
        .overlay {
            if showSuccess {
                ListingPublishedCelebration(onDismiss: { dismiss() })
                    .transition(.opacity)
            }
        }
        .overlay {
            if form.isSubmitting {
                WizardSubmitOverlay()
                    .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showStripePrompt, onDismiss: { dismiss() }) {
            ParkingStripePrompt()
        }
        .animation(.easeOut(duration: 0.18), value: form.isSubmitting)
        .animation(.easeInOut(duration: 0.3), value: showSuccess)
        .onAppear {
            form.category = .parking
            form.priceUnit = .time
            form.instantBooking = true
            form.hideExactLocation = true
            form.defaultVehicleTypes = [.car]
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.22)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.22)) { keyboardVisible = false }
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case 0: AddressStep(form: form, placesService: placesService)
        case 1: ParkingPriceStep(form: form)
        case 2: PhotosStep(form: form)
        case 3: ParkingPublishStep(form: form)
        default: EmptyView()
        }
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

    private var navBar: some View {
        WizardNavBar(
            canGoBack: step > 0,
            nextLabel: step == totalSteps - 1 ? "Publiser annonse" : "Neste",
            nextEnabled: validationError == nil && !form.isSubmitting,
            nextLoading: form.isSubmitting,
            onBack: {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation { step -= 1 }
            },
            onNext: {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                if step == totalSteps - 1 {
                    submit()
                } else {
                    withAnimation { step += 1 }
                }
            }
        )
    }

    private var keyboardDoneButton: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } label: {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.ink)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .accessibilityLabel("Skjul tastatur")
    }

    // MARK: - Validering

    private var validationError: String? {
        switch step {
        case 0:
            if form.address.trimmingCharacters(in: .whitespaces).isEmpty { return "Adresse er påkrevd" }
            if form.lat == 0 && form.lng == 0 { return "Velg en lokasjon fra forslagene" }
        case 1:
            if (form.parkingDailyPrice ?? 0) <= 0 { return "Sett en dagspris" }
            if (form.parkingMonthlyPrice ?? 0) <= 0 { return "Sett en månedspris" }
        case 2:
            if form.imageURLs.isEmpty { return "Legg til minst 1 bilde" }
            if !form.uploadingPhotos.isEmpty { return "Vent til bildene er lastet opp" }
        case 3:
            if !form.hasConfirmedOwnership { return "Bekreft at du har rett til å leie ut plassen" }
        default: break
        }
        return nil
    }

    // MARK: - Submit

    private func submit() {
        guard let userId = authManager.currentUser?.id else { return }
        form.isSubmitting = true
        form.error = nil

        Task {
            do {
                let input = form.buildParkingInput(hostId: userId.uuidString.lowercased(), profile: authManager.profile)
                let _: [Listing] = try await supabase
                    .from("listings")
                    .insert(input)
                    .select()
                    .execute()
                    .value

                await authManager.loadProfile()
                form.isSubmitting = false

                if authManager.profile?.stripeOnboardingComplete == true {
                    withAnimation { showSuccess = true }
                } else {
                    showStripePrompt = true
                }
            } catch {
                form.error = "Kunne ikke opprette annonse: \(error.localizedDescription)"
                form.isSubmitting = false
            }
        }
    }
}

// MARK: - Stripe-prompt etter publisering

/// Vises når annonsen er publisert men verten ikke har fullført
/// Stripe-verifiseringen. Annonsen ligger trygt som «Venter», og blir synlig
/// når verifiseringen (og Tuno-godkjenningen) er ferdig.
struct ParkingStripePrompt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.mint.opacity(0.15))
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.mint)
                }

                VStack(spacing: 10) {
                    Text("Annonsen er sendt inn!")
                        .font(.tuno(.display))
                        .foregroundStyle(Color.inkText)
                        .multilineTextAlignment(.center)
                    Text("Ett steg igjen: fullfør verifiseringen, så kan du motta utbetalinger og annonsen blir synlig for leietakere.")
                        .font(.tuno(.body))
                        .foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 12) {
                Button("Fullfør verifisering") {
                    showOnboarding = true
                }
                .buttonStyle(TunoPillButtonStyle(variant: .mint))

                Button {
                    dismiss()
                } label: {
                    Text("Gjør det senere")
                        .font(.tuno(.body))
                        .foregroundStyle(Color.inkMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink.ignoresSafeArea())
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: { dismiss() }) {
            NavigationStack {
                HostOnboardingFlowView {
                    showOnboarding = false
                }
            }
        }
    }
}

// MARK: - Submit-overlay

private struct WizardSubmitOverlay: View {
    var body: some View {
        ZStack {
            Color.appTintSoft.ignoresSafeArea()
            VStack(spacing: 24) {
                LottieOrFallback(name: "loading-utleier") {
                    ZStack {
                        Circle()
                            .fill(Color.appTint)
                            .frame(width: 180, height: 180)
                        ProgressView()
                            .scaleEffect(2.2)
                            .tint(.appAccent)
                    }
                }
                .frame(width: 220, height: 220)

                Text("Publiserer annonsen")
                    .font(.tuno(.title))
                    .foregroundStyle(.neutral900)
            }
        }
    }
}
