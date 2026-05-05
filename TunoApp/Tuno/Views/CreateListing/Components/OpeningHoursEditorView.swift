import SwiftUI
import UIKit

/// Speil av components/features/OpeningHoursEditor.tsx — gir verten en
/// døgnåpent/med-åpningstid-toggle, og når begrenset: per-ukedag fra/til-velger.
///
/// Binder til en `OpeningHours?` der `nil` = døgnåpent. Gjenbrukes både i
/// wizard og i EditListingView.
struct OpeningHoursEditorView: View {
    @Binding var value: OpeningHours?

    /// Hvilken ukedag som redigeres i sheet-en. nil = ingen sheet åpen.
    @State private var editingDay: Weekday? = nil

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
            .fixedSize(horizontal: false, vertical: true)

            if isLimited, let oh = value {
                weekdayGrid(oh: oh)
            }
        }
        .sheet(item: $editingDay) { day in
            let raw = value?.value(for: day) ?? "09:00-17:00"
            let parsed = OpeningHoursService.parseRange(raw) ?? (start: 9 * 60, end: 17 * 60)
            DayHoursPickerSheet(
                day: day,
                initialStart: parsed.start,
                initialEnd: parsed.end,
                onSave: { newStart, newEnd in
                    setDayValue(day, range: rangeString(start: newStart, end: newEnd))
                    editingDay = nil
                },
                onCancel: { editingDay = nil }
            )
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.visible)
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
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
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
                .frame(width: 64, alignment: .leading)

            Button {
                setDayValue(day, range: closed ? "09:00-17:00" : nil)
            } label: {
                Text(closed ? "Stengt" : "Åpen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(closed ? .neutral500 : .primary700)
                    .frame(width: 56)
                    .padding(.vertical, 5)
                    .background(closed ? Color.neutral100 : Color.primary50)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Time-display: tap åpner kombinert fra/til-sheet for hele dagen.
            if !closed, let parsed = OpeningHoursService.parseRange(raw ?? "") {
                Button {
                    editingDay = day
                } label: {
                    HStack(spacing: 6) {
                        timePill(text: OpeningHoursService.formatTime(parsed.start))
                        Text("–")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral400)
                        timePill(text: OpeningHoursService.formatTime(parsed.end))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 32)
    }

    private func timePill(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.neutral900)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200, lineWidth: 1))
    }

    private func setDayValue(_ day: Weekday, range: String?) {
        var current = value ?? OpeningHours()
        current.set(range, for: day)
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

// Weekday må være Identifiable for å brukes med .sheet(item:).
extension Weekday: Identifiable {
    public var id: String { rawValue }
}

// MARK: - DayHoursPickerSheet

/// Sheet med Fra og Til side-ved-side. Verten ser begge tidene samtidig
/// og kan justere begge før de trykker Ferdig.
private struct DayHoursPickerSheet: View {
    let day: Weekday
    let onSave: (Int, Int) -> Void
    let onCancel: () -> Void

    @State private var startMinutes: Int
    @State private var endMinutes: Int

    init(
        day: Weekday,
        initialStart: Int,
        initialEnd: Int,
        onSave: @escaping (Int, Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.day = day
        _startMinutes = State(initialValue: initialStart)
        _endMinutes = State(initialValue: initialEnd)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var isValid: Bool { endMinutes > startMinutes }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Avbryt") { onCancel() }
                    .font(.system(size: 16))
                    .foregroundStyle(.neutral600)
                Spacer()
                Text(weekdayLongLabel(day))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Spacer()
                Button("Ferdig") {
                    let safeEnd = max(startMinutes + 30, endMinutes)
                    onSave(startMinutes, safeEnd)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isValid ? .primary700 : .neutral400)
                .disabled(!isValid)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            HStack(spacing: 0) {
                timeColumn(label: "Fra", minutes: $startMinutes)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.neutral200)
                    .frame(width: 1, height: 200)

                timeColumn(label: "Til", minutes: $endMinutes)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)

            if !isValid {
                Text("Slutt-tid må være etter start-tid.")
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .background(Color.white)
    }

    @ViewBuilder
    private func timeColumn(label: String, minutes: Binding<Int>) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

            HStack(spacing: 0) {
                Picker("", selection: hourBinding(minutes)) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()

                Picker("", selection: minuteBinding(minutes)) {
                    Text("00").tag(0)
                    Text("30").tag(30)
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
            }
        }
    }

    private func hourBinding(_ minutes: Binding<Int>) -> Binding<Int> {
        Binding(
            get: { minutes.wrappedValue / 60 },
            set: { newHour in
                let m = minutes.wrappedValue % 60
                minutes.wrappedValue = newHour * 60 + m
            }
        )
    }

    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Int> {
        Binding(
            get: { minutes.wrappedValue % 60 == 30 ? 30 : 0 },
            set: { newMin in
                let h = minutes.wrappedValue / 60
                minutes.wrappedValue = h * 60 + newMin
            }
        )
    }

    private func weekdayLongLabel(_ day: Weekday) -> String {
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
