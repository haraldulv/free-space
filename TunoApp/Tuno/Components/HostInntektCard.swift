import SwiftUI

/// Full-bredde kompakt inntekt-kort for verter. Viser denne månedens
/// netto-inntekt (etter Tunos fee) + antall bookings. Trykk for å
/// åpne full EarningsView.
struct HostInntektCard: View {
    let monthName: String
    let netIncome: Int
    let bookingCount: Int
    let trend: Trend?

    enum Trend {
        case up(Int)
        case down(Int)
        case flat
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Inntekt")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.neutral600)
                Text(monthName)
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatKr(netIncome))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.neutral900)
                HStack(spacing: 4) {
                    if let trend {
                        switch trend {
                        case .up(let pct):
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(pct)%")
                                .font(.system(size: 11, weight: .semibold))
                        case .down(let pct):
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(pct)%")
                                .font(.system(size: 11, weight: .semibold))
                        case .flat:
                            EmptyView()
                        }
                    }
                    Text(bookingText)
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                }
                .foregroundStyle(trendColor)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200, lineWidth: 1))
    }

    private var bookingText: String {
        "\(bookingCount) \(bookingCount == 1 ? "booking" : "bookinger")"
    }

    private var trendColor: Color {
        guard let trend else { return .neutral500 }
        switch trend {
        case .up: return Color(hex: "#10b981")
        case .down: return Color(hex: "#dc2626")
        case .flat: return .neutral500
        }
    }

    private func formatKr(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: value)) ?? "\(value)") kr"
    }
}
