import SwiftUI

/// Lekker grønn knapp som kopierer felter fra forrige plass i wizardens
/// per-plass-steg. Brukes på SpotDetailsStep, SpotAvailabilityStep,
/// SpotPriceStep og SpotExtrasStep slik at vert ikke må fylle alt på nytt
/// når plassene ligner.
struct CopyFromPreviousSpotButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.appAccentDeep)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.appTintSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appTintLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
