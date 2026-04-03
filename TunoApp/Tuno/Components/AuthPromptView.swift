import SwiftUI

struct AuthPromptView: View {
    let icon: String
    let message: String
    @Binding var showLogin: Bool

    var body: some View {
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
                    .background(Color.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}
