import SwiftUI
import UIKit

/// Wizard-steg for pris-variasjon (parkering). Ask-fase spør "Vil du variere
/// prisen?" — Nei = fast pris og hopp videre, Ja = åpne kalender-redigerer
/// (WizardPricingCalendarView) der brukeren tapper datoer og setter pris-overstyringer.
struct PriceRulesStep: View {
    enum Phase { case ask, editing }

    @ObservedObject var form: ListingFormModel
    @State private var phase: Phase = .ask

    static var osloCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        Group {
            switch phase {
            case .ask: askPhase
            case .editing: editingPhase
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: phase)
        .onAppear {
            // Hvis brukeren har overstyringer fra før (gikk tilbake), gjenoppta editing.
            if !form.listingDateOverrides.isEmpty { phase = .editing }
        }
    }

    // MARK: - Ask phase

    private var askPhase: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vil du variere prisen?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text("Mange tar høyere pris i rushtiden eller helger. Du kan også beholde én fast pris hele uken.")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                askChoiceCard(
                    icon: "checkmark.circle.fill",
                    title: "Nei, fast pris",
                    subtitle: "Bruk samme pris hele uken og hopp videre.",
                    accent: .neutral900
                ) {
                    form.listingDateOverrides.removeAll()
                    form.goNext()
                }

                askChoiceCard(
                    icon: "chart.bar.fill",
                    title: "Ja, varier prisen",
                    subtitle: "Sett ulike priser for spesifikke dager eller perioder.",
                    accent: .primary600
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) { phase = .editing }
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private func askChoiceCard(icon: String, title: String, subtitle: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.10))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral400)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Editing phase (kalender)

    private var editingPhase: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        form.listingDateOverrides.removeAll()
                        phase = .ask
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Tilbake til fast pris")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.neutral600)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            WizardPricingCalendarView(form: form)
        }
    }

    // MARK: - Helpers (publish)

    /// ISO-yyyy-MM-dd for mandag/søndag i en gitt ISO-uke. Brukes ved
    /// publisering for å sette start_date/end_date på listing_pricing_rules.
    static func dateRangeForWeek(year: Int, week: Int) -> (start: String, end: String)? {
        let cal = osloCalendar
        var comps = DateComponents()
        comps.weekday = 2
        comps.weekOfYear = week
        comps.yearForWeekOfYear = year
        guard let monday = cal.date(from: comps),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return nil }
        return (isoFormatter.string(from: monday), isoFormatter.string(from: sunday))
    }
}
