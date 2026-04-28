import SwiftUI
import UIKit

/// Wizard-steg for time-bånd-prising (kun parkering per time).
/// Brukeren oppretter standard-bånd som gjelder ALLE uker, og kan dra
/// et bånd til en spesifikk uke i kalenderen for å overstyre den uken.
struct PriceRulesStep: View {
    enum Phase { case ask, editing }

    @ObservedObject var form: ListingFormModel
    @State private var phase: Phase = .ask
    @State private var showAddBandSheet = false
    @State private var bandSheetPrefill: BandPrefill?
    @State private var dropTargetWeekKey: String?

    private let weeksAhead = 12

    private var basePriceHint: Int {
        form.spotMarkers.first?.price ?? 50
    }

    private static var osloCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2  // mandag først
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d. MMM"
        f.locale = Locale(identifier: "nb_NO")
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        return f
    }()

    private static let isoFormatter: DateFormatter = {
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
            // Hvis brukeren går tilbake til steget med eksisterende bånd,
            // hopp rett til editing-fasen.
            if !form.pricingBands.isEmpty { phase = .editing }
        }
        .sheet(isPresented: $showAddBandSheet) {
            AddHourlyBandSheet(
                basePrice: basePriceHint,
                prefill: bandSheetPrefill,
            ) { dayMask, startHour, endHour, price in
                form.pricingBands.append(
                    WizardPricingBand(
                        dayMask: dayMask,
                        startHour: startHour,
                        endHour: endHour,
                        price: price,
                        weekScope: .allWeeks
                    )
                )
            }
        }
    }

    // MARK: - Ask phase ("vil du variere prisen?")

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
                    form.pricingBands.removeAll()
                    form.goNext()
                }

                askChoiceCard(
                    icon: "chart.bar.fill",
                    title: "Ja, varier prisen",
                    subtitle: "Sett ulike priser for tidsbånd og spesifikke uker.",
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

    // MARK: - Editing phase (bånd-editor + uke-kalender)

    private var editingPhase: some View {
        VStack(alignment: .leading, spacing: 0) {
            editingHeader

            ScrollView {
                LazyVStack(spacing: 22) {
                    standardBandsSection
                    weekCalendarSection
                }
                .padding(.bottom, 32)
            }
        }
    }

    private var editingHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    form.pricingBands.removeAll()
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

            Text("Sett priser for tidsperioder")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Lag prisbånd som standard gjelder alle uker. Dra et bånd til en spesifikk uke for å overstyre prisen den uken.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Standard bands (alle uker)

    private var defaultBands: [WizardPricingBand] {
        form.pricingBands.filter { $0.weekScope == .allWeeks }
    }

    private var standardBandsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Standard")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Spacer()
                Text("Gjelder alle uker")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }

            if defaultBands.isEmpty {
                emptyDefaultsHint
            } else {
                VStack(spacing: 8) {
                    ForEach(defaultBands) { band in
                        bandRow(band, isDefault: true)
                    }
                }
            }

            quickAddRow
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.neutral200, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var emptyDefaultsHint: some View {
        VStack(spacing: 6) {
            Text("Ingen prisbånd ennå")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral700)
            Text("Bruk hurtigvalg under, eller legg til et eget bånd. Standard-prisen brukes for timer som ikke faller innenfor et bånd.")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var quickAddRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hurtigvalg")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.neutral600)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(BandPrefill.defaults) { prefill in
                    Button {
                        bandSheetPrefill = prefill
                        showAddBandSheet = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prefill.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.neutral900)
                            Text(prefill.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.neutral500)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.neutral50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                bandSheetPrefill = nil
                showAddBandSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Legg til eget bånd")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary700)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.primary50)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Week calendar (12 uker)

    private struct WeekInfo: Identifiable, Hashable {
        let id: String  // "YYYY-WW"
        let year: Int
        let weekNum: Int
        let monday: Date
        let sunday: Date
    }

    private var weekList: [WeekInfo] {
        let cal = Self.osloCalendar
        let today = cal.startOfDay(for: Date())
        // Mandag i denne uken
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7  // mandag = 0
        guard let mondayThisWeek = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else { return [] }

        return (0..<weeksAhead).compactMap { offset in
            guard let monday = cal.date(byAdding: .day, value: offset * 7, to: mondayThisWeek),
                  let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return nil }
            let year = cal.component(.yearForWeekOfYear, from: monday)
            let weekNum = cal.component(.weekOfYear, from: monday)
            return WeekInfo(
                id: String(format: "%04d-%02d", year, weekNum),
                year: year,
                weekNum: weekNum,
                monday: monday,
                sunday: sunday
            )
        }
    }

    private var weekCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spesielle uker")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Spacer()
                Text("Dra et bånd hit ↓")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }
            .padding(.horizontal, 16)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(weekList) { week in
                        weekCell(week)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            .frame(maxHeight: 360)
        }
    }

    private func bandsForWeek(_ week: WeekInfo) -> [WizardPricingBand] {
        form.pricingBands.filter { band in
            if case .specificWeek(let y, let w) = band.weekScope {
                return y == week.year && w == week.weekNum
            }
            return false
        }
    }

    private func weekCell(_ week: WeekInfo) -> some View {
        let bands = bandsForWeek(week)
        let isDropTarget = dropTargetWeekKey == week.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Uke \(week.weekNum)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text("\(Self.weekRangeFormatter.string(from: week.monday))–\(Self.weekRangeFormatter.string(from: week.sunday))")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
                if !bands.isEmpty {
                    Text("\(bands.count) overstyring\(bands.count == 1 ? "" : "er")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary700)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary50))
                }
            }

            if bands.isEmpty {
                // Stiplet drop-indikator når uken ikke har overstyringer ennå —
                // gjør det åpenbart at man kan dra et bånd hit.
                HStack(spacing: 6) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 11))
                    Text("Dra et bånd hit for å overstyre denne uken")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isDropTarget ? .primary700 : .neutral400)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isDropTarget ? Color.primary600 : Color.neutral300,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4])
                        )
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(bands) { band in
                        bandRow(band, isDefault: false)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDropTarget ? Color.primary50 : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDropTarget ? Color.primary600 : Color.neutral200,
                        lineWidth: isDropTarget ? 2 : 1)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let idStr = items.first, let uuid = UUID(uuidString: idStr),
                  let idx = form.pricingBands.firstIndex(where: { $0.id == uuid }) else { return false }
            form.pricingBands[idx].weekScope = .specificWeek(year: week.year, week: week.weekNum)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        } isTargeted: { isTargeted in
            dropTargetWeekKey = isTargeted ? week.id : nil
        }
    }

    // MARK: - Band row (delt mellom standard og uke-overstyring)

    @ViewBuilder
    private func bandRow(_ band: WizardPricingBand, isDefault: Bool) -> some View {
        HStack(spacing: 10) {
            // Tydeligere drag-handle: 4-veis pil i sirkel — signaliserer
            // at båndet kan dras til en uke i kalenderen under.
            ZStack {
                Circle()
                    .fill(Color.neutral100)
                    .frame(width: 32, height: 32)
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.neutral500)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(formatBandLabel(band))
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral900)
                Text("\(band.price) kr/time")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.neutral600)
            }
            Spacer()
            if !isDefault {
                Button {
                    if let idx = form.pricingBands.firstIndex(where: { $0.id == band.id }) {
                        form.pricingBands[idx].weekScope = .allWeeks
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.neutral100))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tilbake til alle uker")
            }
            Button {
                form.pricingBands.removeAll { $0.id == band.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.neutral100))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .draggable(band.id.uuidString)
    }

    private func formatBandLabel(_ band: WizardPricingBand) -> String {
        let weekdaysMask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
        let weekendMask = (1 << 5) | (1 << 6)
        let allMask = weekdaysMask | weekendMask
        let mask = band.dayMask
        let dayPart: String
        if mask == allMask { dayPart = "Alle dager" }
        else if mask == weekdaysMask { dayPart = "Hverdager" }
        else if mask == weekendMask { dayPart = "Helg" }
        else {
            let names = ["Man", "Tir", "Ons", "Tor", "Fre", "Lør", "Søn"]
            dayPart = (0..<7).compactMap { i in (mask & (1 << i)) != 0 ? names[i] : nil }.joined(separator: ", ")
        }
        let sh = String(format: "%02d", band.startHour)
        let eh = String(format: "%02d", band.endHour)
        return "\(dayPart) · \(sh):00–\(eh):00"
    }
}

extension PriceRulesStep {
    /// ISO-yyyy-MM-dd for mandag/søndag i en gitt ISO-uke. Brukes ved
    /// publisering for å sette start_date/end_date på listing_pricing_rules.
    static func dateRangeForWeek(year: Int, week: Int) -> (start: String, end: String)? {
        let cal = osloCalendar
        var comps = DateComponents()
        comps.weekday = 2  // mandag
        comps.weekOfYear = week
        comps.yearForWeekOfYear = year
        guard let monday = cal.date(from: comps),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return nil }
        return (isoFormatter.string(from: monday), isoFormatter.string(from: sunday))
    }
}
