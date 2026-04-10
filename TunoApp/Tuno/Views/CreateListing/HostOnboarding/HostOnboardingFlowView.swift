import SwiftUI

struct HostOnboardingFlowView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = HostOnboardingViewModel()

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProgressHeader(step: viewModel.step)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)

            ScrollView {
                Group {
                    switch viewModel.step {
                    case .welcome:
                        WelcomeStep(viewModel: viewModel)
                    case .personal:
                        PersonalStep(viewModel: viewModel)
                    case .address:
                        AddressStep(viewModel: viewModel)
                    case .bank:
                        BankStep(viewModel: viewModel)
                    case .status:
                        StatusStep(viewModel: viewModel, onComplete: onComplete)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Bli utleier")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.prefill(from: authManager.profile)
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

// MARK: - Shared UI

private struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.neutral600)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 24)
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.neutral700)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.neutral50)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(error != nil ? Color.red : Color.neutral200, lineWidth: 1),
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isEnabled ? Color.primary600 : Color.neutral300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isEnabled || isLoading)
    }
}

private struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Step 1: Welcome + TOS

private struct WelcomeStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepTitle(
                title: "Velkommen som utleier",
                subtitle: "Vi trenger litt informasjon for å kunne betale ut leieinntektene dine. Alt skjer her i appen.",
            )

            VStack(alignment: .leading, spacing: 12) {
                BulletRow(icon: "person.text.rectangle", text: "Navn, fødselsdato og personnummer")
                BulletRow(icon: "house", text: "Adresse")
                BulletRow(icon: "creditcard", text: "Bankkonto for utbetalinger")
            }
            .padding(16)
            .background(Color.primary50)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Ved å fortsette godtar du [Stripes tjenestevilkår](https://stripe.com/connect-account/legal/full), Tunos [utleiervilkår](https://tuno.no/utleiervilkar) og [retningslinjer for annonser](https://tuno.no/retningslinjer). Tuno bruker Stripe som betalingsleverandør.")
                .font(.system(size: 13))
                .foregroundStyle(.neutral600)
                .tint(.primary600)

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            PrimaryButton(
                title: "Jeg godtar og fortsetter",
                isLoading: viewModel.isSubmitting,
            ) {
                Task { await viewModel.acceptTOSAndContinue() }
            }
        }
    }
}

private struct BulletRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.primary600)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.neutral800)
            Spacer()
        }
    }
}

// MARK: - Step 2: Personal info

private struct PersonalStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(
                title: "Personlig informasjon",
                subtitle: "Stripe krever dette for identitetsverifisering.",
            )

            LabeledField(
                label: "Fornavn",
                placeholder: "Kari",
                text: $viewModel.firstName,
                error: viewModel.fieldErrors["first_name"],
            )
            LabeledField(
                label: "Etternavn",
                placeholder: "Nordmann",
                text: $viewModel.lastName,
                error: viewModel.fieldErrors["last_name"],
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Fødselsdato")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.neutral700)
                DatePicker(
                    "",
                    selection: $viewModel.dob,
                    in: ...Date(),
                    displayedComponents: .date,
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            LabeledField(
                label: "Personnummer (11 siffer)",
                placeholder: "01019912345",
                text: $viewModel.personnummer,
                keyboard: .numberPad,
                error: viewModel.fieldErrors["id_number"],
            )
            LabeledField(
                label: "Telefonnummer",
                placeholder: "+47 123 45 678",
                text: $viewModel.phone,
                keyboard: .phonePad,
                error: viewModel.fieldErrors["phone"],
            )

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            PrimaryButton(title: "Neste", isLoading: viewModel.isSubmitting) {
                Task { await viewModel.submitPersonal() }
            }
        }
    }
}

// MARK: - Step 3: Address

private struct AddressStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(
                title: "Adresse",
                subtitle: "Hjemmeadressen din. Brukes kun til identitetsverifisering.",
            )

            LabeledField(
                label: "Gateadresse",
                placeholder: "Storgata 1",
                text: $viewModel.addressLine1,
                error: viewModel.fieldErrors["line1"],
            )
            LabeledField(
                label: "Postnummer",
                placeholder: "0155",
                text: $viewModel.postalCode,
                keyboard: .numberPad,
                error: viewModel.fieldErrors["postal_code"],
            )
            LabeledField(
                label: "Poststed",
                placeholder: "Oslo",
                text: $viewModel.city,
                error: viewModel.fieldErrors["city"],
            )

            HStack(spacing: 6) {
                Image(systemName: "flag")
                Text("Norge")
            }
            .font(.system(size: 14))
            .foregroundStyle(.neutral600)

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            PrimaryButton(title: "Neste", isLoading: viewModel.isSubmitting) {
                Task { await viewModel.submitAddress() }
            }
        }
    }
}

// MARK: - Step 4: Bank

private struct BankStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(
                title: "Bankkonto",
                subtitle: "Kontoen Stripe skal bruke for å betale ut leieinntektene dine.",
            )

            LabeledField(
                label: "IBAN",
                placeholder: "NO93 8601 1117 947",
                text: $viewModel.iban,
                keyboard: .asciiCapable,
                error: viewModel.fieldErrors["iban"],
            )
            LabeledField(
                label: "Kontoeier",
                placeholder: "Navn på kontoen",
                text: $viewModel.accountHolderName,
                error: viewModel.fieldErrors["account_holder_name"],
            )

            Text("Du finner IBAN i nettbanken din. Norske IBAN starter med NO og har 15 tegn.")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            PrimaryButton(title: "Fullfør oppsett", isLoading: viewModel.isSubmitting) {
                Task { await viewModel.submitBank() }
            }
        }
    }
}

// MARK: - Step 5: Status / result

private struct StatusStep: View {
    @ObservedObject var viewModel: HostOnboardingViewModel
    @EnvironmentObject var authManager: AuthManager
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.isOnboardingComplete {
                successCard
            } else {
                pendingCard
            }

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            PrimaryButton(
                title: viewModel.isOnboardingComplete ? "Fortsett til annonse" : "Oppdater status",
                isLoading: viewModel.isSubmitting,
            ) {
                if viewModel.isOnboardingComplete {
                    Task {
                        await authManager.loadProfile()
                        onComplete()
                    }
                } else {
                    Task { await viewModel.refreshStatus() }
                }
            }
        }
    }

    private var successCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary50)
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary600)
            }
            Text("Klar til å ta imot bookinger!")
                .font(.system(size: 22, weight: .bold))
            Text("Kontoen din er satt opp og du kan opprette annonser nå. Utbetalinger skjer automatisk etter hvert opphold.")
                .font(.system(size: 15))
                .foregroundStyle(.neutral600)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "clock")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.orange)
            }
            Text("Oppsettet er nesten ferdig")
                .font(.system(size: 22, weight: .bold))
            Text("Stripe trenger litt mer informasjon før vi kan aktivere utbetalingene dine:")
                .font(.system(size: 15))
                .foregroundStyle(.neutral600)
            ForEach(viewModel.requirements, id: \.self) { req in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(humanize(requirement: req))
                        .font(.system(size: 14))
                }
                .foregroundStyle(.neutral700)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func humanize(requirement: String) -> String {
        switch requirement {
        case "individual.verification.document",
             "individual.verification.additional_document":
            return "Legitimasjon (kommer senere — du kan opprette annonse nå)"
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
