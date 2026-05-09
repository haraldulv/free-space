import SwiftUI

/// Strukturert offer-boble i chatten. Brukes for messages.kind == 'offer'.
/// Viser pris, datoer, avsender, utløp, og handlinger (Godta / Endre pris)
/// for mottakeren.
struct OfferMessageBubble: View {
    let metadata: OfferMetadata
    /// True hvis det er gjeldende bruker som la tilbudet (avsender-perspektiv).
    let isFromMe: Bool
    /// True hvis dette er det aktive tilbudet i forhandlingen (current_offer_id).
    let isActive: Bool
    /// Hvilken rolle den innloggede har i denne samtalen ("host" eller "guest").
    /// Brukes til å rendre riktig accept-label — host godtar uten å betale,
    /// gjest betaler ved aksept.
    let viewerRole: String?
    /// Handlinger — bare relevant når tilbudet er aktivt og isFromMe == false.
    let onAccept: (() -> Void)?
    let onCounter: (() -> Void)?
    let onDecline: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary600)
                Text(roleLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.neutral700)
                Spacer()
                if let countdownText {
                    Text(countdownText)
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\((metadata.totalPrice ?? 0).formatted(.number.locale(Locale(identifier: "nb_NO"))))")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text("kr")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral500)
            }

            if let dates = dateRangeLabel {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(dates)
                        .font(.system(size: 13))
                }
                .foregroundStyle(.neutral600)
            }

            if !isActive {
                statusBadge
            } else if isFromMe {
                Text("Venter på svar fra \(opposingPartyLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            } else {
                actionButtons
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isActive ? Color.primary300 : Color.neutral200, lineWidth: isActive ? 1.5 : 1)
        )
        .frame(maxWidth: 280, alignment: .leading)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button(action: { onAccept?() }) {
                Text(acceptLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 8) {
                Button(action: { onCounter?() }) {
                    Text("Endre pris")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.neutral300, lineWidth: 1)
                        )
                }
                Button(action: { onDecline?() }) {
                    Text("Avslå")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
    }

    /// "Godta og betal" for gjest (gjest betaler ved aksept), "Godta forespørselen"
    /// for host (host trigger payment-flyt hos gjest, betaler ikke selv).
    private var acceptLabel: String {
        viewerRole == "host" ? "Godta forespørselen" : "Godta og betal"
    }

    private var statusBadge: some View {
        Text("Erstattet av nyere tilbud")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.neutral500)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.neutral100)
            .clipShape(Capsule())
    }

    // MARK: - Helpers

    private var roleLabel: String {
        switch metadata.proposedByRole {
        case "host": return isFromMe ? "Du foreslår" : "Utleier foreslår"
        case "guest": return isFromMe ? "Du foreslår" : "Gjest foreslår"
        default: return "Tilbud"
        }
    }

    private var opposingPartyLabel: String {
        metadata.proposedByRole == "host" ? "gjest" : "utleier"
    }

    private var dateRangeLabel: String? {
        guard let inStr = metadata.checkIn, let outStr = metadata.checkOut else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let start = parser.date(from: inStr), let end = parser.date(from: outStr) else { return nil }

        let day = DateFormatter()
        day.dateFormat = "d."
        day.locale = Locale(identifier: "nb_NO")
        let dayMonth = DateFormatter()
        dayMonth.dateFormat = "d. MMM"
        dayMonth.locale = Locale(identifier: "nb_NO")

        let cal = Calendar(identifier: .gregorian)
        if cal.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(day.string(from: start))–\(dayMonth.string(from: end))"
        }
        return "\(dayMonth.string(from: start))–\(dayMonth.string(from: end))"
    }

    private var countdownText: String? {
        guard let iso = metadata.expiresAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: iso)
        }
        guard let d = date else { return nil }
        let interval = d.timeIntervalSinceNow
        if interval <= 0 { return "Utløpt" }
        let hours = Int(interval / 3600)
        if hours >= 1 { return "Utløper om \(hours)t" }
        let minutes = Int(interval / 60)
        return "Utløper om \(minutes)m"
    }
}
