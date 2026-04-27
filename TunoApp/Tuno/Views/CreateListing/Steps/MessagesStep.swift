import SwiftUI

struct MessagesStep: View {
    @ObservedObject var form: ListingFormModel

    private let hourOptions = [1, 2, 3, 6, 12, 24]

    var body: some View {
        WizardScreen(
            title: "Send automatiske meldinger?",
            subtitle: "Spar tid med ferdige meldinger som sendes til gjesten ved innsjekk og før utsjekk. Du kan endre dette senere."
        ) {
            VStack(alignment: .leading, spacing: 20) {
                // Velkomstmelding
                messageCard(
                    icon: "hand.wave.fill",
                    iconColor: .primary600,
                    title: "Velkomstmelding",
                    subtitle: "Sendes automatisk på ankomstdagen",
                    text: $form.checkinMessage,
                    placeholder: "Hei! Velkommen til oss. Plassen din ligger merket med skilt..."
                )

                // Utsjekk-melding
                messageCard(
                    icon: "moon.fill",
                    iconColor: .primary500,
                    title: "Utsjekk-melding",
                    subtitle: "Sendes \(form.checkoutMessageSendHoursBefore) time\(form.checkoutMessageSendHoursBefore == 1 ? "" : "r") før utsjekk",
                    text: $form.checkoutMessage,
                    placeholder: "Tusen takk for at du var her! Vennligst tøm søppel før utsjekk..."
                )

                // Hvor lenge før utsjekk
                if !form.checkoutMessage.trimmingCharacters(in: .whitespaces).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Send utsjekk-melding hvor lenge før?")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.neutral700)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(hourOptions, id: \.self) { h in
                                    Button {
                                        form.checkoutMessageSendHoursBefore = h
                                    } label: {
                                        Text("\(h)t")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(form.checkoutMessageSendHoursBefore == h ? .white : .neutral700)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(form.checkoutMessageSendHoursBefore == h ? Color.primary600 : Color.white)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(form.checkoutMessageSendHoursBefore == h ? Color.primary600 : Color.neutral200, lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private func messageCard(icon: String, iconColor: Color, title: String, subtitle: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.primary50).frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
            }

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                        .padding(.horizontal, 12)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .font(.system(size: 14))
                    .frame(minHeight: 90)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.neutral50)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neutral200, lineWidth: 1))
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200, lineWidth: 1))
    }
}
