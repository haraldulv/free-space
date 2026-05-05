import SwiftUI

/// Speil av components/features/OpeningHoursEditor.tsx — gir verten en
/// døgnåpent/med-åpningstid-toggle, og når begrenset: per-ukedag fra/til-velger.
///
/// Binder til en `OpeningHours?` der `nil` = døgnåpent. Gjenbrukes både i
/// wizard og i EditListingView.
struct OpeningHoursEditorView: View {
    @Binding var value: OpeningHours?

    private var isLimited: Bool { value != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                modeCard(
                    selected: !isLimited,
                    icon: "clock",
                    title: "Døgnåpent",
                    subtitle: "Plassen er alltid tilgjengelig."
                ) {
                    value = nil
                }
                modeCard(
                    selected: isLimited,
                    icon: "clock.badge",
                    title: "Med åpningstid",
                    subtitle: "Sett tider per ukedag."
                ) {
                    if value == nil { value = OpeningHours.defaultLimited }
                }
            }

            if isLimited, let oh = value {
                weekdayGrid(oh: oh)
            }
        }
    }

    @ViewBuilder
    private func modeCard(
        selected: Bool,
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? .primary600 : .neutral500)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .background(selected ? Color.primary50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func weekdayGrid(oh: OpeningHours) -> some View {
        VStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { day in
                weekdayRow(day: day, raw: oh.value(for: day))
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    @ViewBuilder
    private func weekdayRow(day: Weekday, raw: String?) -> some View {
        let closed = raw == nil
        HStack(spacing: 10) {
            Text(weekdayLabel(day))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.neutral700)
                .frame(width: 56, alignment: .leading)

            Button {
                setDayValue(day, range: closed ? "09:00-17:00" : nil)
            } label: {
                Text(closed ? "Stengt" : "Åpen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(closed ? .neutral500 : .primary700)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(closed ? Color.neutral100 : Color.primary50)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            if !closed, let parsed = OpeningHoursService.parseRange(raw ?? "") {
                let startMin = parsed.start
                let endMin = parsed.end
                HourPicker(
                    selection: Binding(
                        get: { startMin },
                        set: { newStart in
                            let safeEnd = max(newStart + 30, endMin)
                            setDayValue(day, range: rangeString(start: newStart, end: safeEnd))
                        }
                    )
                )
                Text("–")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral400)
                HourPicker(
                    selection: Binding(
                        get: { endMin },
                        set: { newEnd in
                            let safeEnd = max(startMin + 30, newEnd)
                            setDayValue(day, range: rangeString(start: startMin, end: safeEnd))
                        }
                    )
                )
            } else {
                Spacer()
            }
        }
    }

    private func setDayValue(_ day: Weekday, range: String?) {
        var current = value ?? OpeningHours()
        current.set(range, for: day)
        // Hvis alle dager er stengt, blir det fortsatt "Med åpningstid" (men 0 åpne dager).
        // Verten må eksplisitt klikke "Døgnåpent" for å slette helt.
        value = current
    }

    private func rangeString(start: Int, end: Int) -> String {
        return "\(OpeningHoursService.formatTime(start))-\(OpeningHoursService.formatTime(end))"
    }

    private func weekdayLabel(_ day: Weekday) -> String {
        switch day {
        case .mon: return "Mandag"
        case .tue: return "Tirsdag"
        case .wed: return "Onsdag"
        case .thu: return "Torsdag"
        case .fri: return "Fredag"
        case .sat: return "Lørdag"
        case .sun: return "Søndag"
        }
    }
}

/// Kompakt time-velger med 30-min steg. Viser HH:mm.
private struct HourPicker: View {
    @Binding var selection: Int

    private static let options: [Int] = stride(from: 0, through: 23 * 60 + 30, by: 30).map { $0 }

    var body: some View {
        Menu {
            ForEach(Self.options, id: \.self) { minutes in
                Button {
                    selection = minutes
                } label: {
                    Text(OpeningHoursService.formatTime(minutes))
                }
            }
        } label: {
            Text(OpeningHoursService.formatTime(selection))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.neutral900)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200, lineWidth: 1))
        }
    }
}
