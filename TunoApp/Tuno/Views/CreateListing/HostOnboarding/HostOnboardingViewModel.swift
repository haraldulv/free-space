import Foundation
import SwiftUI

enum HostOnboardingStep: Int, CaseIterable {
    case welcome
    case personal
    case address
    case bank
    case status
}

@MainActor
final class HostOnboardingViewModel: ObservableObject {
    // Step management
    @Published var step: HostOnboardingStep = .welcome
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var fieldErrors: [String: String] = [:]

    // Step 2 — Personal info
    // Fødselsdato spørres ikke lenger — vi utleder den fra personnummeret
    // (DDMMYY + århundre fra individnummer) i `submitPersonal()` via
    // `PersonnummerHelper.dateOfBirth`.
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var personnummer: String = ""
    /// Telefon er splittet i landskode (dropdown) og nasjonalt nummer.
    /// Vi sender `phoneCountryCode + phoneNumber` til Stripe via `fullPhone`.
    @Published var phoneCountryCode: String = "+47"
    @Published var phoneNumber: String = ""

    var fullPhone: String { phoneCountryCode + phoneNumber }

    /// Live-validert fødselsdato fra personnummer. Vises som hint under
    /// feltet når brukeren har skrevet 11 gyldige siffer (MOD-11 OK + reell
    /// dato). Brukes også som enabled-sjekk på Neste-knappen.
    var personnummerDOB: PersonnummerHelper.DateOfBirth? {
        PersonnummerHelper.dateOfBirth(from: personnummer)
    }

    // Step 3 — Address
    @Published var addressLine1: String = ""
    @Published var postalCode: String = ""
    @Published var city: String = ""

    // Step 4 — Bank
    // Vi spør om norsk kontonummer (BBAN, 11 siffer) og konverterer til
    // IBAN lokalt med MOD-97 i `submitBank()` via `IBANGenerator`.
    // `previewIBAN` brukes til å vise brukeren hva vi sender til Stripe.
    @Published var bankAccount: String = ""
    @Published var accountHolderName: String = ""

    var previewIBAN: String? {
        guard let iban = IBANGenerator.ibanFromBBAN(bankAccount) else { return nil }
        return IBANGenerator.formatForDisplay(iban)
    }

    // Step 5 — Result
    @Published var requirements: [String] = []
    @Published var chargesEnabled: Bool = false
    @Published var payoutsEnabled: Bool = false

    /// Pollerens livssyklus i StatusStep — styrer hvilken UI som rendres.
    /// `idle` brukes mens vi venter på første respons; `polling` mens vi
    /// kaller refresh hvert N sekund; `approved` når Stripe sier OK;
    /// `timedOut` når vi har gitt opp og lover push-varsel i stedet.
    enum PollingState {
        case idle
        case polling
        case approved
        case timedOut
    }
    @Published var pollingState: PollingState = .idle
    private var pollingTask: Task<Void, Never>?

    private let service = HostOnboardingService()

    // Prefill from the authenticated profile. Called once when the flow appears.
    func prefill(from profile: Profile?) {
        guard let profile else { return }
        if firstName.isEmpty, lastName.isEmpty,
           let fullName = profile.fullName, !fullName.isEmpty {
            let parts = fullName.trimmingCharacters(in: .whitespaces).split(separator: " ")
            firstName = parts.first.map(String.init) ?? ""
            if parts.count > 1 {
                lastName = parts.dropFirst().joined(separator: " ")
            }
        }
        if accountHolderName.isEmpty {
            accountHolderName = [firstName, lastName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }

    // MARK: - Step transitions

    func acceptTOSAndContinue() async {
        await run {
            // Ensure the Stripe account exists (first call creates it)
            _ = try await service.ensureAccount()
            // Accept TOS
            let req = AccountUpdateRequest(
                individual: nil,
                tos_acceptance: AccountUpdateTOSAcceptance(accepted: true),
            )
            _ = try await service.updateAccount(req)
            step = .personal
        }
    }

    func submitPersonal() async {
        fieldErrors = [:]
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors["first_name"] = "Fornavn er påkrevd"
        }
        if lastName.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors["last_name"] = "Etternavn er påkrevd"
        }
        let pnr = personnummer.trimmingCharacters(in: .whitespaces)
        // Personnummer-validering går gjennom `PersonnummerHelper`, som
        // også gir oss fødselsdatoen. Dekker både MOD-11-feil og umulige
        // datoer (f.eks. 31. februar) med samme melding.
        let dob = PersonnummerHelper.dateOfBirth(from: pnr)
        if dob == nil {
            fieldErrors["id_number"] = "Ugyldig personnummer"
        }
        if phoneNumber.filter(\.isNumber).count < 8 {
            fieldErrors["phone"] = "Gyldig telefonnummer er påkrevd"
        }
        guard fieldErrors.isEmpty, let dob else { return }

        let individual = AccountUpdateIndividual(
            first_name: firstName,
            last_name: lastName,
            dob: AccountUpdateIndividualDOB(
                day: dob.day,
                month: dob.month,
                year: dob.year,
            ),
            id_number: pnr,
            phone: fullPhone,
            email: nil,
            address: nil,
        )
        await run {
            let req = AccountUpdateRequest(individual: individual, tos_acceptance: nil)
            _ = try await service.updateAccount(req)
            if accountHolderName.isEmpty {
                accountHolderName = "\(firstName) \(lastName)"
            }
            step = .address
        }
    }

    func submitAddress() async {
        fieldErrors = [:]
        if addressLine1.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors["line1"] = "Gateadresse er påkrevd"
        }
        if postalCode.trimmingCharacters(in: .whitespaces).count < 4 {
            fieldErrors["postal_code"] = "Postnummer er påkrevd"
        }
        if city.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors["city"] = "Poststed er påkrevd"
        }
        guard fieldErrors.isEmpty else { return }

        let individual = AccountUpdateIndividual(
            address: AccountUpdateIndividualAddress(
                line1: addressLine1,
                postal_code: postalCode,
                city: city,
                country: "NO",
            ),
        )
        await run {
            let req = AccountUpdateRequest(individual: individual, tos_acceptance: nil)
            _ = try await service.updateAccount(req)
            step = .bank
        }
    }

    func submitBank() async {
        fieldErrors = [:]
        // Brukeren skriver norsk kontonummer (11 siffer) — vi konverterer
        // til IBAN lokalt med MOD-97. MOD-11 på selve kontonummeret fanger
        // skrivefeil før vi når Stripe.
        let iban = IBANGenerator.ibanFromBBAN(bankAccount)
        if iban == nil {
            fieldErrors["bank_account"] = "Ugyldig norsk kontonummer"
        }
        if accountHolderName.trimmingCharacters(in: .whitespaces).count < 2 {
            fieldErrors["account_holder_name"] = "Kontoeier må oppgis"
        }
        guard fieldErrors.isEmpty, let iban else { return }

        await run {
            let status = try await service.submitBank(
                iban: iban,
                accountHolderName: accountHolderName,
            )
            applyStatus(status)
            step = .status
        }
    }

    func refreshStatus() async {
        await run {
            let status = try await service.ensureAccount()
            applyStatus(status)
        }
    }

    /// Polleren kjører fra StatusStep. Vi kaller refresh hvert 3. sekund i
    /// inntil `maxSeconds` sekunder. Hvis Stripe bekrefter underveis, settes
    /// `pollingState = .approved` og loopen avsluttes. Ellers `.timedOut`.
    /// Push-varsel via webhook (account.updated) tar over når brukeren har
    /// lukket sheetet.
    func startPolling(maxSeconds: Int = 30, intervalSeconds: Int = 3) {
        // Hvis allerede godkjent, hopp rett til approved.
        if isOnboardingComplete {
            pollingState = .approved
            return
        }
        pollingTask?.cancel()
        pollingState = .polling
        pollingTask = Task { [weak self] in
            guard let self else { return }
            let deadline = Date().addingTimeInterval(TimeInterval(maxSeconds))
            while Date() < deadline {
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
                if Task.isCancelled { return }
                await self.refreshStatus()
                if self.isOnboardingComplete {
                    self.pollingState = .approved
                    return
                }
            }
            if !self.isOnboardingComplete {
                self.pollingState = .timedOut
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Helpers

    private func applyStatus(_ status: AccountStatus) {
        requirements = status.requirements.currently_due
        chargesEnabled = status.charges_enabled
        payoutsEnabled = status.payouts_enabled
    }

    /// Wrap an async throwing call with loading state + error handling.
    private func run(_ operation: () async throws -> Void) async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await operation()
        } catch let apiError as HostOnboardingAPIError {
            errorMessage = apiError.errorDescription
            if let field = apiError.field {
                fieldErrors[field] = apiError.errorDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    var isOnboardingComplete: Bool {
        chargesEnabled && payoutsEnabled && requirements.isEmpty
    }

    /// Sjekker om obligatoriske felter på gjeldende steg er fylt ut.
    /// WizardNavBar bruker denne til å disable Neste-knappen så brukeren
    /// ikke kan gå videre med ugyldige data.
    func canAdvance(for step: HostOnboardingStep) -> Bool {
        switch step {
        case .welcome:
            return true
        case .personal:
            let firstOK = !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            let lastOK = !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            let pnrOK = personnummerDOB != nil
            let phoneOK = phoneNumber.filter(\.isNumber).count >= 8
            return firstOK && lastOK && pnrOK && phoneOK
        case .address:
            let line1OK = !addressLine1.trimmingCharacters(in: .whitespaces).isEmpty
            let postalOK = postalCode.filter(\.isNumber).count == 4
            let cityOK = !city.trimmingCharacters(in: .whitespaces).isEmpty
            return line1OK && postalOK && cityOK
        case .bank:
            return previewIBAN != nil
                && accountHolderName.trimmingCharacters(in: .whitespaces).count >= 2
        case .status:
            return true
        }
    }
}
