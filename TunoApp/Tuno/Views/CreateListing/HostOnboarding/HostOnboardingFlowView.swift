import SwiftUI
import UIKit

/// Stripe Custom-onboarding gjenbygget med wizard-stilen fra `CreateListingView`:
/// `WizardScreen` for content, `WizardNavBar` i bunnen, store kort for
/// kategori-aktige valg og samme sirkulære keyboard-knapp via `safeAreaInset`.
struct HostOnboardingFlowView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = HostOnboardingViewModel()
    @State private var keyboardVisible = false

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProgressHeader(step: viewModel.step)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

            errorBanner

            stepContent
        }
        .navigationTitle("Bli utleier")
        .navigationBarTitleDisplayMode(.inline)
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.22)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.22)) { keyboardVisible = false }
        }
        .task {
            viewModel.prefill(from: authManager.profile)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .welcome:
            HostOnboardingWelcomeStep()
        case .personal:
            PersonalStep(viewModel: viewModel)
        case .address:
            HostOnboardingAddressStep(viewModel: viewModel)
        case .bank:
            BankStep(viewModel: viewModel)
        case .status:
            StatusStep(viewModel: viewModel, onComplete: onComplete)
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.errorMessage {
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

    /// Sirkulær "skjul tastatur"-knapp. Samme mønster som i `CreateListingView`
    /// — `.toolbar(.keyboard)` rendrer ikke pålitelig på numberPad.
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

    private var navBar: some View {
        WizardNavBar(
            canGoBack: canGoBack,
            nextLabel: nextLabel,
            nextIcon: nextIcon,
            nextEnabled: !viewModel.isSubmitting,
            nextLoading: viewModel.isSubmitting,
            onBack: handleBack,
            onNext: handleNext
        )
    }

    private var canGoBack: Bool {
        switch viewModel.step {
        case .welcome: return false
        case .personal, .address, .bank: return true
        case .status: return false   // Status-skjermen har egen "Lukk"/"Lag annonse"-knapp
        }
    }

    private var nextLabel: String {
        switch viewModel.step {
        case .welcome: return "Jeg godtar og fortsetter"
        case .personal: return "Neste"
        case .address: return "Neste"
        case .bank: return "Fullfør oppsett"
        case .status:
            switch viewModel.pollingState {
            case .approved: return "Lag annonse"
            case .timedOut: return "Lukk"
            case .idle, .polling: return "Vent litt..."
            }
        }
    }

    private var nextIcon: String? {
        switch viewModel.step {
        case .status:
            return viewModel.pollingState == .approved ? "arrow.right" : nil
        default:
            return "chevron.right"
        }
    }

    private func handleBack() {
        switch viewModel.step {
        case .personal: viewModel.step = .welcome
        case .address: viewModel.step = .personal
        case .bank: viewModel.step = .address
        default: break
        }
    }

    private func handleNext() {
        switch viewModel.step {
        case .welcome: Task { await viewModel.acceptTOSAndContinue() }
        case .personal: Task { await viewModel.submitPersonal() }
        case .address: Task { await viewModel.submitAddress() }
        case .bank: Task { await viewModel.submitBank() }
        case .status:
            switch viewModel.pollingState {
            case .approved:
                Task {
                    await authManager.loadProfile()
                    onComplete()
                }
            case .timedOut:
                onComplete()  // Sheet lukkes, push-varsel tar over
            case .idle, .polling:
                break
            }
        }
    }
}

// MARK: - Progress header

private struct ProgressHeader: View {
    let step: HostOnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(HostOnboardingStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.primary600 : Color.neutral200)
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - Step 1: Welcome

private struct HostOnboardingWelcomeStep: View {
    var body: some View {
        WizardScreen(
            title: "Velkommen som utleier",
            subtitle: "Vi trenger litt informasjon for å kunne betale ut leieinntektene dine. Alt skjer her i appen."
        ) {
            VStack(spacing: 14) {
                BulletCard(
                    iconName: "person.text.rectangle.fill",
                    title: "Personlig info",
                    subtitle: "Navn, personnummer og telefon"
                )
                BulletCard(
                    iconName: "house.fill",
                    title: "Adresse",
                    subtitle: "Hjemmeadressen din"
                )
                BulletCard(
                    iconName: "creditcard.fill",
                    title: "Bankkonto",
                    subtitle: "Norsk kontonummer for utbetalinger"
                )

                Text("Ved å fortsette godtar du [Stripes tjenestevilkår](https://stripe.com/connect-account/legal/full), Tunos [utleiervilkår](https://tuno.no/utleiervilkar) og [retningslinjer](https://tuno.no/retningslinjer). Tuno bruker Stripe som betalingsleverandør.")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
                    .tint(.primary600)
                    .padding(.top, 8)
            }
        }
    }
}

private struct BulletCard: View {
    let iconName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.primary50)
                    .frame(width: 52, height: 52)
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.primary700)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.neutral200, lineWidth: 1)
        )
    }
}

// MARK: - Step 2: Personal info

private struct PersonalStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel

    var body: some View {
        WizardScreen(
            title: "Hvem er du?",
            subtitle: "Stripe trenger dette for identitetsverifisering. Fødselsdato utleder vi automatisk fra personnummeret."
        ) {
            VStack(spacing: 16) {
                OnboardingTextField(
                    label: "Fornavn",
                    placeholder: "Kari",
                    text: $viewModel.firstName,
                    error: viewModel.fieldErrors["first_name"]
                )
                OnboardingTextField(
                    label: "Etternavn",
                    placeholder: "Nordmann",
                    text: $viewModel.lastName,
                    error: viewModel.fieldErrors["last_name"]
                )
                OnboardingTextField(
                    label: "Personnummer",
                    placeholder: "11 siffer",
                    text: $viewModel.personnummer,
                    keyboard: .numberPad,
                    autocapitalization: .never,
                    error: viewModel.fieldErrors["id_number"]
                )
                OnboardingTextField(
                    label: "Telefonnummer",
                    placeholder: "+47 123 45 678",
                    text: $viewModel.phone,
                    keyboard: .phonePad,
                    autocapitalization: .never,
                    error: viewModel.fieldErrors["phone"]
                )
            }
        }
    }
}

// MARK: - Step 3: Address

private struct HostOnboardingAddressStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel

    var body: some View {
        WizardScreen(
            title: "Hva er hjemmeadressen din?",
            subtitle: "Brukes kun til identitetsverifisering, vises aldri offentlig."
        ) {
            VStack(spacing: 16) {
                OnboardingTextField(
                    label: "Gateadresse",
                    placeholder: "Storgata 1",
                    text: $viewModel.addressLine1,
                    error: viewModel.fieldErrors["line1"]
                )
                OnboardingTextField(
                    label: "Postnummer",
                    placeholder: "0155",
                    text: $viewModel.postalCode,
                    keyboard: .numberPad,
                    autocapitalization: .never,
                    error: viewModel.fieldErrors["postal_code"]
                )
                OnboardingTextField(
                    label: "Poststed",
                    placeholder: "Oslo",
                    text: $viewModel.city,
                    error: viewModel.fieldErrors["city"]
                )

                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.primary600)
                    Text("Norge")
                        .foregroundStyle(.neutral600)
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Step 4: Bank

private struct BankStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel

    var body: some View {
        WizardScreen(
            title: "Hvor skal vi sende pengene?",
            subtitle: "Skriv det norske kontonummeret slik du ser det i nettbanken din. Vi konverterer det automatisk til IBAN-format."
        ) {
            VStack(spacing: 16) {
                OnboardingTextField(
                    label: "Kontonummer",
                    placeholder: "11 siffer",
                    text: $viewModel.bankAccount,
                    keyboard: .numberPad,
                    autocapitalization: .never,
                    error: viewModel.fieldErrors["bank_account"]
                )

                if let preview = viewModel.previewIBAN {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.primary600)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vi sender")
                                .font(.system(size: 12))
                                .foregroundStyle(.neutral500)
                            Text(preview)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.neutral900)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                OnboardingTextField(
                    label: "Kontoeier",
                    placeholder: "Navn på kontoen",
                    text: $viewModel.accountHolderName,
                    error: viewModel.fieldErrors["account_holder_name"]
                )
            }
        }
    }
}

// MARK: - Step 5: Status

private struct StatusStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel
    @EnvironmentObject var authManager: AuthManager
    let onComplete: () -> Void

    var body: some View {
        WizardScreen(title: "") {
            VStack(spacing: 24) {
                switch viewModel.pollingState {
                case .idle, .polling:
                    pollingCard
                case .approved:
                    successCard
                case .timedOut:
                    pendingCard
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
        .task {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    private var pollingCard: some View {
        VStack(spacing: 20) {
            LottieOrFallback(name: "loading-pulse") {
                ZStack {
                    Circle()
                        .fill(Color.primary50)
                        .frame(width: 120, height: 120)
                    ProgressView()
                        .scaleEffect(1.6)
                        .tint(.primary600)
                }
            }
            .frame(width: 160, height: 160)

            VStack(spacing: 8) {
                Text("Vi sjekker med Stripe…")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text("Dette tar vanligvis noen sekunder.")
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral600)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var successCard: some View {
        VStack(spacing: 20) {
            LottieOrFallback(name: "success-confetti") {
                ZStack {
                    Circle()
                        .fill(Color.primary600)
                        .frame(width: 120, height: 120)
                    Image(systemName: "checkmark")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 200, height: 200)

            VStack(spacing: 8) {
                Text("Du er godkjent! 🎉")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text("Klar til å lage din første annonse. Utbetalinger skjer automatisk etter hvert opphold.")
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral600)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var pendingCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 8) {
                Text("Stripe trenger litt mer tid")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.neutral900)
                    .multilineTextAlignment(.center)
                Text("Vi sender deg et varsel så snart kontoen din er godkjent. Det tar vanligvis under en time.")
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral600)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)
            }

            if !viewModel.requirements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dette gjenstår")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.neutral500)
                        .textCase(.uppercase)
                    ForEach(viewModel.requirements, id: \.self) { req in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 8))
                                .foregroundStyle(.neutral400)
                                .padding(.top, 6)
                            Text(humanize(requirement: req))
                                .font(.system(size: 14))
                                .foregroundStyle(.neutral700)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func humanize(requirement: String) -> String {
        switch requirement {
        case "individual.verification.document",
             "individual.verification.additional_document":
            return "Legitimasjon (kommer senere, du kan opprette annonse nå)"
        case "individual.id_number":
            return "Personnummer"
        case "individual.dob.day", "individual.dob.month", "individual.dob.year":
            return "Fødselsdato"
        case "individual.address.line1", "individual.address.postal_code", "individual.address.city":
            return "Adresse"
        case "external_account":
            return "Bankkonto"
        case "tos_acceptance.date", "tos_acceptance.ip":
            return "Godkjenning av tjenestevilkår"
        default:
            return requirement
        }
    }
}

// MARK: - Shared input

/// Stort tekst-felt for onboarding-flowen. Speiler wizard-stilen:
/// generøs padding, fokus-glow med grønn ramme, label over og evt.
/// rød feilmelding under.
private struct OnboardingTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words
    var error: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

            TextField(placeholder, text: $text)
                .focused($isFocused)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.neutral900)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(borderColor, lineWidth: isFocused || error != nil ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .animation(.easeInOut(duration: 0.18), value: isFocused)

            if let error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.red)
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return .red }
        if isFocused { return .primary600 }
        return .neutral200
    }
}
