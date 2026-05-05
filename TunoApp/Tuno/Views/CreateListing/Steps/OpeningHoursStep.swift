import SwiftUI

/// Wizard-steg for åpningstid (parkering only).
///
/// Speiler web-flyten: verten velger "Døgnåpent" eller "Med åpningstid".
/// Per-plass-overstyring kommer post-launch — her settes kun listing-nivå.
struct OpeningHoursStep: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        WizardScreen(
            title: "Når er plassen åpen?",
            subtitle: "Velg om plassen er åpen hele døgnet, eller sett spesifikke åpningstider per ukedag."
        ) {
            VStack(alignment: .leading, spacing: 20) {
                OpeningHoursEditorView(value: $form.openingHours)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary600)
                    Text("Gjester ser åpningstidene på annonsen og blir varslet før booking. Du kan endre dette senere.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral600)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary50)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
