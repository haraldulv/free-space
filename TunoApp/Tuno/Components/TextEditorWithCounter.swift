import SwiftUI

/// TextEditor med tegnteller + maks-grense. Brukes for beskrivelser og
/// velkomstmeldinger der hosten kan skrive mye tekst men vi vil unngå
/// ubegrenset input.
struct TextEditorWithCounter: View {
    @Binding var text: String
    let maxLength: Int
    var minHeight: CGFloat = 100
    var placeholder: String? = nil

    private var nearLimit: Bool {
        text.count > Int(Double(maxLength) * 0.9)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .frame(minHeight: minHeight)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200)
                    )
                    .onChange(of: text) { _, new in
                        if new.count > maxLength {
                            text = String(new.prefix(maxLength))
                        }
                    }

                if text.isEmpty, let placeholder {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundStyle(.neutral400)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Spacer()
                Text("\(text.count) / \(maxLength)")
                    .font(.system(size: 11))
                    .foregroundStyle(nearLimit ? Color.orange : Color.neutral400)
                    .monospacedDigit()
            }
        }
    }
}
