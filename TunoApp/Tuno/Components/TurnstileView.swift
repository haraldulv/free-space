import SwiftUI
import UIKit
import WebKit

/// Cloudflare Turnstile i en WKWebView. Laster `AppConfig.siteURL/captcha`
/// (en minimal side på vårt eget domene som rendrer widgeten) og får tokenet
/// tilbake via `window.webkit.messageHandlers.turnstile.postMessage(token)`.
///
/// Brukes som sheet før e-post-login/registrering/passord-reset når
/// `AppConfig.turnstileEnabled` er true.
struct TurnstileSheet: View {
    let onToken: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Bekreft at du ikke er en robot")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.top, 8)
                TurnstileWebView(
                    onToken: { token in
                        onToken(token)
                        dismiss()
                    },
                    onError: { failed = true }
                )
                .frame(height: 120)
                if failed {
                    Text("Kunne ikke laste robotsjekken. Sjekk nettet og prøv igjen.")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}

struct TurnstileWebView: UIViewRepresentable {
    let onToken: (String) -> Void
    let onError: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken, onError: onError) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "turnstile")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: "\(AppConfig.siteURL)/captcha?embed=ios") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "turnstile")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onToken: (String) -> Void
        let onError: () -> Void
        init(onToken: @escaping (String) -> Void, onError: @escaping () -> Void) {
            self.onToken = onToken
            self.onError = onError
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "turnstile" else { return }
            if let token = message.body as? String, !token.isEmpty {
                onToken(token)
            } else if let dict = message.body as? [String: Any], dict["error"] != nil {
                onError()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { onError() }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { onError() }
    }
}
