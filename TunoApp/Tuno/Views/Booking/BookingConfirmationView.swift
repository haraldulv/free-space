import SwiftUI

enum BookingConfirmationMode {
    case confirmed
    case requested(conversationId: String?)
}

struct BookingConfirmationView: View {
    let listing: Listing
    let checkIn: Date
    let checkOut: Date
    let total: Int
    var mode: BookingConfirmationMode = .confirmed
    @Environment(\.dismiss) var dismiss

    private var nights: Int {
        max(1, Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 1)
    }

    /// "dag"/"dager" for parkering, "døgn" for camping. Brukes i Varighet-raden.
    private func durationUnit(count: Int) -> String {
        if listing.category == .parking {
            return count == 1 ? "dag" : "dager"
        }
        return "døgn"
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "nb")
        return f
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text(titleText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text(subtitleText)
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral500)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    if let imageUrl = listing.images?.first, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color.neutral100)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        if let city = listing.city {
                            Text(city)
                                .font(.system(size: 13))
                                .foregroundStyle(.neutral500)
                        }
                    }
                    Spacer()
                }

                Divider()

                detailRow(label: "Innsjekk", value: dateFormatter.string(from: checkIn))
                detailRow(label: "Utsjekk", value: dateFormatter.string(from: checkOut))
                detailRow(label: "Varighet", value: "\(nights) \(durationUnit(count: nights))")

                Divider()

                HStack {
                    Text(totalLabel)
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text("\(total) kr")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .padding(20)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.neutral200, lineWidth: 1)
            )

            Spacer()

            Button {
                handleCTA()
            } label: {
                Text(ctaText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .background(.white)
        .navigationBarBackButtonHidden(true)
    }

    private var titleText: String {
        switch mode {
        case .confirmed: return "Bestilling bekreftet!"
        case .requested: return "Forespørsel sendt!"
        }
    }

    private var subtitleText: String {
        switch mode {
        case .confirmed: return "Du vil motta en bekreftelse snart."
        case .requested: return "Utleier får 24 timer på å svare. Du blir varslet når det skjer."
        }
    }

    private var totalLabel: String {
        switch mode {
        case .confirmed: return "Totalt betalt"
        case .requested: return "Foreslått pris"
        }
    }

    private var ctaText: String {
        switch mode {
        case .confirmed: return "Se mine bestillinger"
        case .requested: return "Se i meldinger"
        }
    }

    private func handleCTA() {
        switch mode {
        case .confirmed:
            NotificationCenter.default.post(name: .switchToBookingsTab, object: nil)
        case .requested(let conversationId):
            if let id = conversationId {
                PushRouter.shared.pendingConversationId = id
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.neutral700)
        }
    }
}
