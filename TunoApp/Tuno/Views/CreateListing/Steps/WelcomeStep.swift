import SwiftUI

struct WelcomeStep: View {
    @ObservedObject var form: ListingFormModel
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(authManager.hasListings ? "Det er lett å lage en ny annonse" : "Det er lett å komme i gang på Tuno")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.neutral900)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 40)

                StepRow(
                    number: 1,
                    title: "Fortell oss om stedet ditt",
                    subtitle: "Del litt grunnleggende informasjon, for eksempel hvor stedet er, og hvor mange plasser det er.",
                    iconName: "new-listing-home"
                )

                Divider()
                    .background(Color.neutral200)
                    .padding(.vertical, 32)

                StepRow(
                    number: 2,
                    title: "Sørg for å skille deg ut",
                    subtitle: "Legg til fem eller flere bilder, en tittel og en beskrivelse. Vi hjelper deg.",
                    iconName: "new-listing-stand-out"
                )

                Divider()
                    .background(Color.neutral200)
                    .padding(.vertical, 32)

                StepRow(
                    number: 3,
                    title: "Sett en pris og publiser",
                    subtitle: "Velg en startpris, bekreft noen opplysninger og publiser annonsen.",
                    iconName: "new-listing-complete"
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }
}

private struct StepRow: View {
    let number: Int
    let title: String
    let subtitle: String
    let iconName: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(number)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral600)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 22)
            }
            Spacer(minLength: 12)
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
        }
    }
}
