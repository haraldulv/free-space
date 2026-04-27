import SwiftUI
import UIKit

/// Stripe Custom-onboarding gjenbygget med wizard-stilen fra `CreateListingView`:
/// `WizardScreen` for content, `WizardNavBar` i bunnen, store kort for
/// kategori-aktige valg og samme sirkulære keyboard-knapp via `safeAreaInset`.
struct HostOnboardingFlowView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HostOnboardingViewModel()
    @State private var keyboardVisible = false
    @State private var showCancelAlert = false
    /// Felles focus-state på tvers av alle steg. Vi bruker en enum så vi
    /// kan ScrollViewReader.scrollTo(focus) for å sentrere felter over
    /// tastaturet, og bruke .submitLabel(.next) til å hoppe mellom dem.
    @FocusState private var focusedField: OnboardingField?

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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { showCancelAlert = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral700)
                }
                .accessibilityLabel("Avbryt")
            }
        }
        .alert("Avbryt utleier-oppsett?", isPresented: $showCancelAlert, actions: {
            Button("Forkast", role: .destructive) { dismiss() }
            Button("Fortsett", role: .cancel) {}
        }, message: {
            Text("Du må fullføre oppsettet før du kan opprette annonser.")
        })
        .safeAreaInset(edge: .bottom) {
            navBar.transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button(action: focusPrevious) {
                    Image(systemName: "chevron.up")
                }
                .disabled(focusedField == nil || focusedField?.previous(in: viewModel.step) == nil)
                Button(action: focusNext) {
                    Image(systemName: "chevron.down")
                }
                .disabled(focusedField == nil || focusedField?.next(in: viewModel.step) == nil)
                Spacer()
                Button("Ferdig") {
                    focusedField = nil
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary600)
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
            PersonalStep(viewModel: viewModel, focusedField: $focusedField)
        case .address:
            HostOnboardingAddressStep(viewModel: viewModel, focusedField: $focusedField)
        case .bank:
            BankStep(viewModel: viewModel, focusedField: $focusedField)
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

    private var navBar: some View {
        WizardNavBar(
            canGoBack: canGoBack,
            nextLabel: nextLabel,
            nextIcon: nextIcon,
            nextEnabled: viewModel.canAdvance(for: viewModel.step) && !viewModel.isSubmitting,
            nextLoading: viewModel.isSubmitting,
            onBack: handleBack,
            onNext: handleNext
        )
    }

    private var canGoBack: Bool {
        switch viewModel.step {
        case .welcome: return false
        case .personal, .address, .bank: return true
        case .status: return false
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
        focusedField = nil
        switch viewModel.step {
        case .personal: viewModel.step = .welcome
        case .address: viewModel.step = .personal
        case .bank: viewModel.step = .address
        default: break
        }
    }

    private func handleNext() {
        focusedField = nil
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
                onComplete()
            case .idle, .polling:
                break
            }
        }
    }

    private func focusNext() {
        guard let current = focusedField,
              let next = current.next(in: viewModel.step) else { return }
        focusedField = next
    }

    private func focusPrevious() {
        guard let current = focusedField,
              let prev = current.previous(in: viewModel.step) else { return }
        focusedField = prev
    }
}

// MARK: - Focus state

/// Identifiserer hvilket felt som er fokusert på tvers av stegene. Brukes
/// både til keyboard-navigasjon (chevron-knapper) og auto-scroll.
enum OnboardingField: Hashable {
    case firstName, lastName, personnummer, phoneNumber
    case addressLine1, postalCode, city
    case bankAccount, accountHolder

    func next(in step: HostOnboardingStep) -> OnboardingField? {
        switch step {
        case .personal:
            switch self {
            case .firstName: return .lastName
            case .lastName: return .personnummer
            case .personnummer: return .phoneNumber
            default: return nil
            }
        case .address:
            switch self {
            case .addressLine1: return .postalCode
            case .postalCode: return .city
            default: return nil
            }
        case .bank:
            switch self {
            case .bankAccount: return .accountHolder
            default: return nil
            }
        default: return nil
        }
    }

    func previous(in step: HostOnboardingStep) -> OnboardingField? {
        switch step {
        case .personal:
            switch self {
            case .lastName: return .firstName
            case .personnummer: return .lastName
            case .phoneNumber: return .personnummer
            default: return nil
            }
        case .address:
            switch self {
            case .postalCode: return .addressLine1
            case .city: return .postalCode
            default: return nil
            }
        case .bank:
            switch self {
            case .accountHolder: return .bankAccount
            default: return nil
            }
        default: return nil
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
    var focusedField: FocusState<OnboardingField?>.Binding

    var body: some View {
        ScrollViewReader { proxy in
            WizardScreen(
                title: "Hvem er du?",
                subtitle: "Stripe trenger dette for identitetsverifisering. Fødselsdato utleder vi automatisk fra personnummeret."
            ) {
                VStack(spacing: 16) {
                    OnboardingTextField(
                        label: "Fornavn",
                        placeholder: "Kari",
                        text: $viewModel.firstName,
                        error: viewModel.fieldErrors["first_name"],
                        submitLabel: .next
                    )
                    .focused(focusedField, equals: .firstName)
                    .id(OnboardingField.firstName)
                    .onSubmit { focusedField.wrappedValue = .lastName }

                    OnboardingTextField(
                        label: "Etternavn",
                        placeholder: "Nordmann",
                        text: $viewModel.lastName,
                        error: viewModel.fieldErrors["last_name"],
                        submitLabel: .next
                    )
                    .focused(focusedField, equals: .lastName)
                    .id(OnboardingField.lastName)
                    .onSubmit { focusedField.wrappedValue = .personnummer }

                    OnboardingTextField(
                        label: "Personnummer",
                        placeholder: "11 siffer",
                        text: $viewModel.personnummer,
                        keyboard: .numberPad,
                        autocapitalization: .never,
                        error: viewModel.fieldErrors["id_number"],
                        helperText: personnummerHelper,
                        helperIsSuccess: viewModel.personnummerDOB != nil,
                        submitLabel: .next
                    )
                    .focused(focusedField, equals: .personnummer)
                    .id(OnboardingField.personnummer)
                    .onSubmit { focusedField.wrappedValue = .phoneNumber }
                    .onChange(of: viewModel.personnummer) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits.count > 11 {
                            viewModel.personnummer = String(digits.prefix(11))
                        } else if digits != newValue {
                            viewModel.personnummer = digits
                        }
                    }

                    PhoneInputField(
                        countryCode: $viewModel.phoneCountryCode,
                        number: $viewModel.phoneNumber,
                        error: viewModel.fieldErrors["phone"],
                        focused: focusedField.projectedValue,
                        focusValue: .phoneNumber
                    )
                    .id(OnboardingField.phoneNumber)
                }
                .padding(.bottom, 320) // Plass over keyboard for siste felt
            }
            .onChange(of: focusedField.wrappedValue) { _, new in
                guard let new else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private var personnummerHelper: String? {
        let digits = viewModel.personnummer.filter(\.isNumber)
        if digits.isEmpty { return nil }
        if let dob = viewModel.personnummerDOB {
            return "Fødselsdato: \(String(format: "%02d.%02d.%d", dob.day, dob.month, dob.year))"
        }
        if digits.count < 11 {
            return "\(digits.count)/11 siffer"
        }
        return nil
    }
}

// MARK: - Step 3: Address

private struct HostOnboardingAddressStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel
    var focusedField: FocusState<OnboardingField?>.Binding

    var body: some View {
        ScrollViewReader { proxy in
            WizardScreen(
                title: "Hva er hjemmeadressen din?",
                subtitle: "Brukes kun til identitetsverifisering, vises aldri offentlig."
            ) {
                VStack(spacing: 16) {
                    OnboardingTextField(
                        label: "Gateadresse",
                        placeholder: "Storgata 1",
                        text: $viewModel.addressLine1,
                        error: viewModel.fieldErrors["line1"],
                        submitLabel: .next
                    )
                    .focused(focusedField, equals: .addressLine1)
                    .id(OnboardingField.addressLine1)
                    .onSubmit { focusedField.wrappedValue = .postalCode }

                    OnboardingTextField(
                        label: "Postnummer",
                        placeholder: "0155",
                        text: $viewModel.postalCode,
                        keyboard: .numberPad,
                        autocapitalization: .never,
                        error: viewModel.fieldErrors["postal_code"],
                        submitLabel: .next
                    )
                    .focused(focusedField, equals: .postalCode)
                    .id(OnboardingField.postalCode)
                    .onSubmit { focusedField.wrappedValue = .city }
                    .onChange(of: viewModel.postalCode) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits.count > 4 {
                            viewModel.postalCode = String(digits.prefix(4))
                        } else if digits != newValue {
                            viewModel.postalCode = digits
                        }
                    }

                    OnboardingTextField(
                        label: "Poststed",
                        placeholder: "Oslo",
                        text: $viewModel.city,
                        error: viewModel.fieldErrors["city"],
                        submitLabel: .done
                    )
                    .focused(focusedField, equals: .city)
                    .id(OnboardingField.city)
                    .onSubmit { focusedField.wrappedValue = nil }

                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.primary600)
                        Text("Norge")
                            .foregroundStyle(.neutral600)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .padding(.top, 4)
                }
                .padding(.bottom, 280)
            }
            .onChange(of: focusedField.wrappedValue) { _, new in
                guard let new else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Step 4: Bank

private struct BankStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel
    var focusedField: FocusState<OnboardingField?>.Binding

    var body: some View {
        ScrollViewReader { proxy in
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
                        error: viewModel.fieldErrors["bank_account"],
                        helperText: bankAccountHelper,
                        helperIsSuccess: viewModel.previewIBAN != nil,
                        submitLabel: .next
                    )
                    .focused(focusedField, equals: .bankAccount)
                    .id(OnboardingField.bankAccount)
                    .onSubmit { focusedField.wrappedValue = .accountHolder }
                    .onChange(of: viewModel.bankAccount) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits.count > 11 {
                            viewModel.bankAccount = String(digits.prefix(11))
                        } else if digits != newValue {
                            viewModel.bankAccount = digits
                        }
                    }

                    OnboardingTextField(
                        label: "Kontoeier",
                        placeholder: "Navn på kontoen",
                        text: $viewModel.accountHolderName,
                        error: viewModel.fieldErrors["account_holder_name"],
                        submitLabel: .done
                    )
                    .focused(focusedField, equals: .accountHolder)
                    .id(OnboardingField.accountHolder)
                    .onSubmit { focusedField.wrappedValue = nil }
                }
                .padding(.bottom, 280)
            }
            .onChange(of: focusedField.wrappedValue) { _, new in
                guard let new else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private var bankAccountHelper: String? {
        let digits = viewModel.bankAccount.filter(\.isNumber)
        if digits.isEmpty { return nil }
        if let preview = viewModel.previewIBAN {
            return "Sendes som \(preview)"
        }
        if digits.count < 11 {
            return "\(digits.count)/11 siffer"
        }
        return nil
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

// MARK: - Phone input with country code

private struct PhoneInputField: View {
    @Binding var countryCode: String
    @Binding var number: String
    var error: String?
    var focused: FocusState<OnboardingField?>.Binding
    var focusValue: OnboardingField

    private static let countries: [(name: String, code: String, flag: String)] = [
        ("Norge", "+47", "🇳🇴"),
        ("Sverige", "+46", "🇸🇪"),
        ("Danmark", "+45", "🇩🇰"),
        ("Finland", "+358", "🇫🇮"),
        ("Island", "+354", "🇮🇸"),
        ("Tyskland", "+49", "🇩🇪"),
        ("Polen", "+48", "🇵🇱"),
        ("Nederland", "+31", "🇳🇱"),
        ("Storbritannia", "+44", "🇬🇧"),
        ("Frankrike", "+33", "🇫🇷"),
        ("Spania", "+34", "🇪🇸"),
        ("Italia", "+39", "🇮🇹"),
        ("USA", "+1", "🇺🇸"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Telefonnummer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                Menu {
                    ForEach(Self.countries, id: \.code) { c in
                        Button {
                            countryCode = c.code
                        } label: {
                            HStack {
                                Text("\(c.flag)  \(c.name)")
                                Spacer()
                                Text(c.code).foregroundStyle(.secondary)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(flag(for: countryCode))
                            .font(.system(size: 18))
                        Text(countryCode)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.neutral900)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.neutral500)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 52)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.neutral200, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                TextField("123 45 678", text: $number)
                    .focused(focused, equals: focusValue)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .submitLabel(.done)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.neutral900)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(error != nil ? Color.red : (focused.wrappedValue == focusValue ? Color.primary600 : Color.neutral200), lineWidth: focused.wrappedValue == focusValue || error != nil ? 2 : 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

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

    private func flag(for code: String) -> String {
        Self.countries.first(where: { $0.code == code })?.flag ?? "🌐"
    }
}

// MARK: - Shared input

/// Stort tekst-felt for onboarding-flowen. Live-validert helperText kan
/// vises under feltet (grønn ved success, grå ellers).
private struct OnboardingTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words
    var error: String?
    var helperText: String? = nil
    var helperIsSuccess: Bool = false
    var submitLabel: SubmitLabel = .return
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
                .submitLabel(submitLabel)
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
            } else if let helperText {
                HStack(spacing: 4) {
                    if helperIsSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.primary600)
                    }
                    Text(helperText)
                        .font(.system(size: 12))
                        .foregroundStyle(helperIsSuccess ? .primary700 : .neutral500)
                }
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return .red }
        if isFocused { return .primary600 }
        return .neutral200
    }
}
