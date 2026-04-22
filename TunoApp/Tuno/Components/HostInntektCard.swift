import SwiftUI
import Charts

/// Full-bredde kompakt inntekt-kort for verter. Viser denne månedens
/// netto-inntekt (etter Tunos fee), antall bookings, og en liten bar chart
/// med de siste 3 månedene plassert mellom label og beløp.
struct HostInntektCard: View {
    let monthName: String
    let netIncome: Int
    let bookingCount: Int
    let recentMonths: [MonthlyEarning]

    struct MonthlyEarning: Identifiable, Hashable {
        let id: String  // YYYY-MM
        let shortLabel: String  // "mar"
        let earnings: Int
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
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
            .fixedSize()

            if !recentMonths.isEmpty {
                miniChart
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer()
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatKr(netIncome))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text(bookingText)
                    .font(.system(size: 11))
                    .foregroundStyle(.neutral500)
            }
            .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200.opacity(0.5), lineWidth: 0.5))
    }

    private var miniChart: some View {
        Chart {
            ForEach(recentMonths) { month in
                BarMark(
                    x: .value("Måned", month.shortLabel),
                    y: .value("kr", month.earnings),
                    width: .fixed(14)
                )
                .foregroundStyle(
                    month.id == currentMonthKey
                        ? Color.primary600
                        : Color.primary600.opacity(0.28)
                )
                .cornerRadius(3)
            }
        }
        .chartXScale(range: .plotDimension(padding: 2))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 9))
                    .foregroundStyle(.neutral500)
            }
        }
        .frame(maxWidth: 110)
    }

    private var currentMonthKey: String {
        recentMonths.last?.id ?? ""
    }

    private var bookingText: String {
        "\(bookingCount) \(bookingCount == 1 ? "booking" : "bookinger")"
    }

    private func formatKr(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: value)) ?? "\(value)") kr"
    }
}
