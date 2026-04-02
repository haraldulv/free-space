import SwiftUI

struct InputField: View {
    let label: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.neutral700)
            TextField(label, text: $text)
                .textFieldStyle(.plain)
                .padding(14)
                .background(.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.neutral200, lineWidth: 1)
                )
                .textContentType(contentType)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
        }
    }
}

struct SecureInputField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.neutral700)
            SecureField(label, text: $text)
                .textFieldStyle(.plain)
                .padding(14)
                .background(.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.neutral200, lineWidth: 1)
                )
                .textContentType(.password)
        }
    }
}
