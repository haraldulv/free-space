import SwiftUI

/// Steg 6 — verten setter min/maks antall dager gjester kan booke.
/// Eget steg etter Booking-modus så det er klart adskilt fra direkte/forespørsel.
struct StayLengthStep: View {
    @ObservedObject var form: ListingFormModel

    private var unitWord: String {
        form.category == .parking ? "dag" : "døgn"
    }

    var body: some View {
        WizardScreen(
            title: "Lengde på opphold",
            subtitle: "Sett minimum og maksimum antall \(unitWord) gjester kan booke. La maksimum stå tomt hvis du ikke vil ha en øvre grense."
        ) {
            VStack(spacing: 16) {
                stayCard(
                    label: "Minimum",
                    value: $form.minStayDays,
                    minValue: 1,
                    maxValue: nil,
                    description: "Korteste opphold gjest kan booke.",
                    placeholder: "1"
                )

                stayCard(
                    label: "Maksimum",
                    value: $form.maxStayDays,
                    minValue: max(form.minStayDays ?? 1, 1),
                    maxValue: nil,
                    description: "Lengste opphold gjest kan booke.",
                    placeholder: ""
                )

                if let err = validationError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 14))
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    @ViewBuilder
    private func stayCard(
        label: String,
        value: Binding<Int?>,
        minValue: Int?,
        maxValue: Int?,
        description: String,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.neutral900)
            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)
            KrStepper(
                value: value,
                step: 1,
                minValue: minValue,
                maxValue: maxValue,
                unitLabel: pluralizeUnit(for: value.wrappedValue ?? 0),
                placeholder: placeholder
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200, lineWidth: 1))
    }

    private func pluralizeUnit(for count: Int) -> String {
        if form.category == .parking {
            return count == 1 ? "dag" : "dager"
        }
        return "døgn"
    }

    private var validationError: String? {
        if let minD = form.minStayDays, let maxD = form.maxStayDays, minD > maxD {
            return "Maksimum kan ikke være mindre enn minimum."
        }
        return nil
    }
}
