import Foundation
import UIKit

/// Bygger en lesbar kvittering-tekst for en gjest-booking. Brukes i
/// "Send kvittering"-flyt på fullførte bookinger; vises i UIActivityViewController
/// så bruker kan sende den som mail / SMS / kopiere.
enum ReceiptBuilder {

    static func buildText(for booking: Booking, guestName: String?) -> String {
        var lines: [String] = []
        lines.append("Tuno — kvittering")
        lines.append(String(repeating: "─", count: 36))
        lines.append("")

        if let title = booking.listing?.title {
            lines.append(title)
        }
        if let city = booking.listing?.city, !city.isEmpty {
            lines.append(city)
        }
        lines.append("")

        lines.append("Bestillings-ID: \(booking.id)")
        if let createdAt = formatTimestamp(booking.createdAt) {
            lines.append("Bestilt: \(createdAt)")
        }
        if let name = guestName, !name.isEmpty {
            lines.append("Gjest: \(name)")
        }
        lines.append("")

        lines.append("Innsjekk: \(formatDate(booking.checkIn))")
        if let t = booking.checkInTimeSnapshot { lines.append("  Fra: \(t)") }
        lines.append("Utsjekk: \(formatDate(booking.checkOut))")
        if let t = booking.checkOutTimeSnapshot { lines.append("  Til: \(t)") }
        lines.append("")

        lines.append("Total: \(booking.totalPrice) kr")
        if booking.status == .cancelled, let refund = booking.refundAmount, refund > 0 {
            lines.append("Refundert: \(refund) kr")
        }
        lines.append("")

        lines.append("Tuno AS · support@tuno.no · tuno.no")
        return lines.joined(separator: "\n")
    }

    @MainActor
    static func presentShareSheet(_ text: String, sourceView: UIView? = nil) {
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
        if let pop = activity.popoverPresentationController {
            pop.sourceView = sourceView ?? root.view
            pop.sourceRect = sourceView?.bounds ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        presenter.present(activity, animated: true)
    }

    private static func formatDate(_ iso: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Oslo")
        guard let d = f.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "d. MMM yyyy"
        out.locale = Locale(identifier: "nb_NO")
        return out.string(from: d)
    }

    private static func formatTimestamp(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) {
            return formatDate(DateFormatter().also { $0.dateFormat = "yyyy-MM-dd"; $0.timeZone = TimeZone(identifier: "Europe/Oslo") }.string(from: d))
        }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        if let d = f2.date(from: iso) {
            return formatDate(DateFormatter().also { $0.dateFormat = "yyyy-MM-dd"; $0.timeZone = TimeZone(identifier: "Europe/Oslo") }.string(from: d))
        }
        return nil
    }
}

private extension DateFormatter {
    func also(_ block: (DateFormatter) -> Void) -> DateFormatter {
        block(self)
        return self
    }
}
