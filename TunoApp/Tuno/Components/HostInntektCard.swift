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

    /// Parkering-designet (palett C): inntektskortet er en svart markedsflate
    /// med mint-aksenter — matcher hero/booking-bar. Camping beholder det
    /// gamle lyse gradient-kortet.
    private var isInk: Bool { AppConfig.parkingOnly }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Inntekt")
                        .font(.app(size: 16, weight: .semibold))
                }
                .foregroundStyle(isInk ? Color.mint : .appAccentDeep)
                Text(monthName)
                    .font(.app(size: 13))
                    .foregroundStyle(isInk ? Color.inkMuted : .neutral600)
                if let trend = trendLabel {
                    HStack(spacing: 3) {
                        Image(systemName: trend.isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(trend.text)
                            .font(.app(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(trend.isPositive ? (isInk ? Color.mint : .green) : Color(hex: "#f87171"))
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
                    .font(.app(size: 30, weight: .bold))
                    .foregroundStyle(isInk ? Color.inkText : .neutral900)
                Text(bookingText)
                    .font(.app(size: 12))
                    .foregroundStyle(isInk ? Color.inkMuted : .neutral500)
            }
            .fixedSize()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .background {
            if isInk {
                Color.ink
            } else {
                LinearGradient(
                    colors: [Color.appTintSoft, Color.appCard],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isInk ? Color.white.opacity(0.08) : Color.appTintLine.opacity(0.6), lineWidth: isInk ? 1 : 0.5))
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
                        ? (isInk ? Color.mint : Color.appAccent)
                        : (isInk ? Color.mint.opacity(0.25) : Color.appAccent.opacity(0.28))
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
                    .foregroundStyle(isInk ? Color.inkMuted : .neutral500)
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
