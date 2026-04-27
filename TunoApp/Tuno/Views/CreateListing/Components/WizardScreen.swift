import SwiftUI

/// Felles wrapper for hver wizard-skjerm — tittel, undertekst, content.
/// Holder vertikal-rytmen konsistent på tvers av alle 11 stegene.
struct WizardScreen<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var topAccessory: AnyView? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let topAccessory = topAccessory {
                    topAccessory
                        .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.neutral900)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 16))
                            .foregroundStyle(.neutral500)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

extension WizardScreen where Content == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.topAccessory = nil
        self.content = { EmptyView() }
    }
}
