import UIKit
import UserNotifications

@MainActor
class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()
    @Published var deviceToken: String?

    func requestPermission() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("[Push] Permission granted: \(granted), error: \(error?.localizedDescription ?? "none")")
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func handleToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Push] Got device token: \(token.prefix(12))...")
        self.deviceToken = token
        Task { await registerToken(token) }
    }

    func registerToken(_ token: String) async {
        guard let accessToken = try? await supabase.auth.session.accessToken else {
            print("[Push] No auth session — cannot register token")
            return
        }
        guard let url = URL(string: "\(AppConfig.siteURL)/api/push/register") else {
            print("[Push] Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "token": token,
            "platform": "ios",
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Push] Register response: \(status) — \(body)")
        } catch {
            print("[Push] Register failed: \(error.localizedDescription)")
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])

        // Notify the app to refresh unread counts
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .newPushNotification, object: nil)
        }
    }
}

extension Notification.Name {
    static let newPushNotification = Notification.Name("newPushNotification")
}
