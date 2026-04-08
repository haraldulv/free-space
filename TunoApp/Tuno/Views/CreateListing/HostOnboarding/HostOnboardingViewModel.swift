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
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var dob: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @Published var personnummer: String = ""
    @Published var phone: String = ""

    // Step 3 — Address
    @Published var addressLine1: String = ""
    @Published var postalCode: String = ""
    @Published var city: String = ""

    // Step 4 — Bank
    @Published var iban: String = ""
    @Published var accountHolderName: String = ""

    // Step 5 — Result
    @Published var requirements: [String] = []
    @Published var chargesEnabled: Bool = false
    @Published var payoutsEnabled: Bool = false

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
        if pnr.count != 11 || !pnr.allSatisfy(\.isNumber) {
            fieldErrors["id_number"] = "Personnummer må være 11 siffer"
        }
        if phone.trimmingCharacters(in: .whitespaces).count < 8 {
            fieldErrors["phone"] = "Gyldig telefonnummer er påkrevd"
        }
        guard fieldErrors.isEmpty else { return }

        let comps = Calendar.current.dateComponents([.day, .month, .year], from: dob)
        let individual = AccountUpdateIndividual(
            first_name: firstName,
            last_name: lastName,
            dob: AccountUpdateIndividualDOB(
                day: comps.day ?? 1,
                month: comps.month ?? 1,
                year: comps.year ?? 2000,
            ),
            id_number: pnr,
            phone: phone,
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
        let normalized = iban.replacingOccurrences(of: " ", with: "").uppercased()
        let ibanMatches = normalized.range(of: "^NO\\d{13}$", options: .regularExpression) != nil
        if !ibanMatches {
            fieldErrors["iban"] = "Ugyldig norsk IBAN (NO + 13 siffer)"
        }
        if accountHolderName.trimmingCharacters(in: .whitespaces).count < 2 {
            fieldErrors["account_holder_name"] = "Kontoeier må oppgis"
        }
        guard fieldErrors.isEmpty else { return }

        await run {
            let status = try await service.submitBank(
                iban: normalized,
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
}
