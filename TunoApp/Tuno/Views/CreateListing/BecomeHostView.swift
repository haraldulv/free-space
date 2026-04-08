import SwiftUI

/// Entry point for the "Bli utleier" flow. If the user has already completed
/// the Stripe Custom-account onboarding, jump straight to `CreateListingView`.
/// Otherwise present the native multi-step onboarding wizard.
struct BecomeHostView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var onboardingCompleted = false

    var body: some View {
        Group {
            if authManager.profile?.stripeOnboardingComplete == true || onboardingCompleted {
                CreateListingView()
            } else {
                HostOnboardingFlowView {
                    onboardingCompleted = true
                }
            }
        }
    }
}
