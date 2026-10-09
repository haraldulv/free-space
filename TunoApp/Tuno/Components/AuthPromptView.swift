import SwiftUI

struct AuthPromptView: View {
    let icon: String
    let message: String
    @Binding var showLogin: Bool

    var body: some View {
        if AppConfig.parkingOnly {
            parkingBody
        } else {
            campingBody
        }
    }

    /// Parkering (palett C): papirflate, Schibsted Grotesk, ink-knapp.
    private var parkingBody: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.neutral400)

            Text(message)
                .font(.tuno(.body))
                .foregroundStyle(.neutral600)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showLogin = true
            } label: {
                Text("Logg inn")
            }
            .buttonStyle(TunoPillButtonStyle(variant: .ink))
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper.ignoresSafeArea())
    }

    /// Camping: opprinnelig stil, urørt.
    private var campingBody: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(.neutral300)

            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.neutral500)
                .multilineTextAlignment(.center)

            Button {
                showLogin = true
            } label: {
                Text("Logg inn")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}
