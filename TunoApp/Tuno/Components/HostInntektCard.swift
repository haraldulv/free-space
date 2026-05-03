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
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Inntekt")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.primary700)
                Text(monthName)
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral600)
                if let trend = trendLabel {
                    HStack(spacing: 3) {
                        Image(systemName: trend.isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(trend.text)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(trend.isPositive ? .green : .red)
                    .padding(.top, 2)
                }
            }
            .fixedSize()

            if !recentMonths.isEmpty {
                miniChart
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer()
            }

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatKr(netIncome))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text(bookingText)
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }
            .fixedSize()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .background(
            LinearGradient(
                colors: [Color.primary50, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary200.opacity(0.6), lineWidth: 0.5))
    }

    /// Beregner endring fra forrige måned. Returnerer nil hvis vi mangler
    /// minst to måneder med data eller forrige måned var 0 (kan ikke regne %).
    private var trendLabel: (text: String, isPositive: Bool)? {
        guard recentMonths.count >= 2 else { return nil }
        let prev = recentMonths[recentMonths.count - 2].earnings
        let curr = recentMonths.last?.earnings ?? netIncome
        guard prev > 0 else { return nil }
        let diff = curr - prev
        let percent = Int((Double(abs(diff)) / Double(prev)) * 100)
        let prevLabel = recentMonths[recentMonths.count - 2].shortLabel
        let arrow = diff >= 0 ? "+" : "-"
        return ("\(arrow)\(percent)% vs \(prevLabel)", diff >= 0)
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
