import SwiftUI

/// Tidsvelger som lagrer verdien som "HH:mm" string men bruker native
/// Apple-hjul for valget (compact-stil som åpner wheel ved tap).
///
/// Brukes i stedet for rå TextField for check-in/check-out-tider der vi
/// vil unngå feiltyping av format.
struct TimePickerField: View {
    @Binding var timeString: String
    var defaultTime: String = "15:00"

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "nb_NO")
        f.timeZone = TimeZone(identifier: "Europe/Oslo")
        return f
    }()

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                TimePickerField.formatter.date(from: timeString)
                    ?? TimePickerField.formatter.date(from: defaultTime)
                    ?? Date()
            },
            set: { newDate in
                timeString = TimePickerField.formatter.string(from: newDate)
            }
        )
    }

    var body: some View {
        DatePicker("", selection: dateBinding, displayedComponents: .hourAndMinute)
            .datePickerStyle(.compact)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "nb_NO"))
    }
}
