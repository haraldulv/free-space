import Foundation
import StripeConnect
import StripeCore
import UIKit

/// Bridges the StripeConnect `AccountOnboardingController` (which self-presents
/// as a fullscreen `UINavigationController`) into a SwiftUI host. Owns the
/// `EmbeddedComponentManager`, holds the delegate alive, and re-fetches the
/// client secret from `/api/stripe/connect` whenever Stripe needs a fresh one
/// (the secret expires after ~30 minutes).
@MainActor
final class StripeConnectOnboardingPresenter: NSObject, ObservableObject,
                                              AccountOnboardingControllerDelegate {

    private var manager: EmbeddedComponentManager?
    private var controller: AccountOnboardingController?

    /// Called when the user finishes or dismisses the onboarding sheet.
    var onExit: (() -> Void)?
    /// Called if the embedded component fails to load.
    var onError: ((String) -> Void)?

    /// Configures the manager (one-time per host) and presents the onboarding
    /// sheet from the topmost UIViewController.
    func present(initialClientSecret: String, publishableKey: String) {
        STPAPIClient.shared.publishableKey = publishableKey

        // The first call uses the secret we already fetched. Subsequent calls
        // (Stripe asks for a refresh after expiry) re-POST to the API.
        var firstCall = true
        let manager = EmbeddedComponentManager { [weak self] in
            if firstCall {
                firstCall = false
                return initialClientSecret
            }
            return await self?.fetchFreshClientSecret()
        }
        self.manager = manager

        let controller = manager.createAccountOnboardingController()
        controller.title = "Sett opp utbetalinger"
        controller.delegate = self
        self.controller = controller

        guard let topVC = Self.topViewController() else {
            onError?("Kunne ikke finne presenterende view")
            return
        }
        controller.present(from: topVC)
    }

    // MARK: - Client secret refresh

    private func fetchFreshClientSecret() async -> String? {
        guard let session = try? await supabase.auth.session else { return nil }
        let url = URL(string: "\(AppConfig.siteURL)/api/stripe/connect")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["platform": "ios"])
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["clientSecret"] as? String
        } catch {
            return nil
        }
    }

    // MARK: - AccountOnboardingControllerDelegate

    nonisolated func accountOnboardingDidExit(_ accountOnboarding: AccountOnboardingController) {
        Task { @MainActor in
            self.controller = nil
            self.manager = nil
            self.onExit?()
        }
    }

    nonisolated func accountOnboarding(_ accountOnboarding: AccountOnboardingController,
                                       didFailLoadWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.onError?(message)
        }
    }

    // MARK: - Top view controller lookup

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let window = scene?.windows.first(where: { $0.isKeyWindow })
            ?? scene?.windows.first else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
