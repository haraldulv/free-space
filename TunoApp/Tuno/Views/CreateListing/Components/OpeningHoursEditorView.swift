import SwiftUI
import UIKit

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
            // Equal-height ved å binde begge til høyeste søsken.
            .fixedSize(horizontal: false, vertical: true)

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

            // Time-pickers eller blank plass av samme bredde, så Stengt-rader
            // står på linje med Åpen-rader.
            if !closed, let parsed = OpeningHoursService.parseRange(raw ?? "") {
                let startMin = parsed.start
                let endMin = parsed.end
                HStack(spacing: 6) {
                    HourPickerButton(
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
                    HourPickerButton(
                        selection: Binding(
                            get: { endMin },
                            set: { newEnd in
                                let safeEnd = max(startMin + 30, newEnd)
                                setDayValue(day, range: rangeString(start: startMin, end: safeEnd))
                            }
                        )
                    )
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 32)
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

// MARK: - HourPickerButton

/// Knapp som åpner et bottom sheet med native UIDatePicker (.wheels) i 30-min
/// step. Brukes per fra/til-tid på hver ukedag.
private struct HourPickerButton: View {
    @Binding var selection: Int
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Text(OpeningHoursService.formatTime(selection))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.neutral900)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            HourPickerSheet(selection: $selection, isPresented: $showSheet)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
    }
}

/// Sheet med stor wheel-time-picker (30-min step) + Ferdig-knapp.
private struct HourPickerSheet: View {
    @Binding var selection: Int
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Velg tid")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Spacer()
                Button("Ferdig") {
                    isPresented = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary700)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            WheelTimePicker(minutes: $selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white)
    }
}

/// UIKit-bro for å bruke UIDatePicker i .wheels-modus med 30-min step.
private struct WheelTimePicker: UIViewRepresentable {
    @Binding var minutes: Int

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = 30
        picker.locale = Locale(identifier: "nb_NO")
        picker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.changed(_:)),
            for: .valueChanged
        )
        // Sett initial dato fra binding.
        picker.date = dateFor(minutes: minutes)
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        let target = dateFor(minutes: minutes)
        if uiView.date != target {
            uiView.date = target
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func dateFor(minutes: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    final class Coordinator: NSObject {
        let parent: WheelTimePicker
        init(_ parent: WheelTimePicker) { self.parent = parent }

        @objc func changed(_ picker: UIDatePicker) {
            let h = Calendar.current.component(.hour, from: picker.date)
            let m = Calendar.current.component(.minute, from: picker.date)
            parent.minutes = h * 60 + m
        }
    }
}
