import SwiftUI
import Charts

/// Full-bredde kompakt inntekt-kort for verter. Viser denne månedens
/// netto-inntekt (etter Tunos fee), antall bookings, og en mini bar chart
/// med de siste 6 månedene.
struct HostInntektCard: View {
    let monthName: String
    let netIncome: Int
    let bookingCount: Int
    let recentMonths: [MonthlyEarning]
    let trend: Trend?

    struct MonthlyEarning: Identifiable, Hashable {
        let id: String  // YYYY-MM
        let shortLabel: String  // "mar"
        let earnings: Int
    }

    enum Trend {
        case up(Int)
        case down(Int)
        case flat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            if !recentMonths.isEmpty {
                miniChart
                    .frame(height: 48)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200, lineWidth: 1))
    }

    private var miniChart: some View {
        Chart {
            ForEach(recentMonths) { month in
                BarMark(
                    x: .value("Måned", month.shortLabel),
                    y: .value("kr", month.earnings),
                    width: .ratio(0.6)
                )
                .foregroundStyle(
                    month.id == currentMonthKey
                        ? Color.primary600
                        : Color.primary600.opacity(0.35)
                )
                .cornerRadius(4)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(.neutral500)
            }
        }
    }

    private var currentMonthKey: String {
        recentMonths.last?.id ?? ""
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
