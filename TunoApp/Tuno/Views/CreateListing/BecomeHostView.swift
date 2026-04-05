import SwiftUI
import SafariServices

struct BecomeHostView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoadingStripe = false
    @State private var stripeError: String?
    @State private var showCreateListing = false
    @State private var safariURL: URL?

    var body: some View {
        Group {
            if authManager.profile?.stripeOnboardingComplete == true {
                // Stripe is ready — show wizard
                CreateListingView()
            } else {
                stripeOnboardingPrompt
            }
        }
        .navigationTitle("Bli utleier")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stripeOnboardingComplete)) { _ in
            // Close Safari and reload profile
            safariURL = nil
            Task {
                await authManager.loadProfile()
            }
        }
    }

    private var stripeOnboardingPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.primary50)
                    .frame(width: 80, height: 80)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.primary600)
            }

            VStack(spacing: 12) {
                Text("Sett opp utbetalinger")
                    .font(.system(size: 24, weight: .bold))

                Text("Før du kan opprette en annonse, må du koble til Stripe for å motta utbetalinger fra gjester.")
                    .font(.system(size: 16))
                    .foregroundStyle(.neutral600)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if let error = stripeError {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Button {
                startStripeOnboarding()
            } label: {
                HStack(spacing: 8) {
                    if isLoadingStripe {
                        ProgressView().tint(.white)
                    } else {
                        Text("Koble til Stripe")
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primary600)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoadingStripe)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private func startStripeOnboarding() {
        isLoadingStripe = true
        stripeError = nil

        Task {
            do {
                guard let session = try? await supabase.auth.session else {
                    stripeError = "Du må være innlogget"
                    isLoadingStripe = false
                    return
                }

                let apiURL = URL(string: "\(AppConfig.siteURL)/api/stripe/connect")!
                var request = URLRequest(url: apiURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["platform": "ios"])

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    stripeError = "Kunne ikke starte Stripe-oppsett"
                    isLoadingStripe = false
                    return
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let urlString = json["url"] as? String,
                      let url = URL(string: urlString) else {
                    stripeError = "Ugyldig respons fra server"
                    isLoadingStripe = false
                    return
                }

                safariURL = url
                isLoadingStripe = false
            } catch {
                stripeError = "Noe gikk galt: \(error.localizedDescription)"
                isLoadingStripe = false
            }
        }
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(red: 0.102, green: 0.310, blue: 0.839, alpha: 1)
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// Make URL work with .sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// Notification for Stripe callback
extension Notification.Name {
    static let stripeOnboardingComplete = Notification.Name("stripeOnboardingComplete")
}
