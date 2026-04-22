import SwiftUI
import UIKit

/// TextEditor med tegnteller + maks-grense. Brukes for beskrivelser og
/// velkomstmeldinger der hosten kan skrive mye tekst men vi vil unngå
/// ubegrenset input.
struct TextEditorWithCounter: View {
    @Binding var text: String
    let maxLength: Int
    var minHeight: CGFloat = 100
    var placeholder: String? = nil
    var showCopyPaste: Bool = false

    private var nearLimit: Bool {
        text.count > Int(Double(maxLength) * 0.9)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showCopyPaste {
                CopyPasteRow(text: $text, maxLength: maxLength)
            }

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

/// Liten knappe-rad for å kopiere/lime inn tekst i et felt.
/// Brukes f.eks. på velkomstmelding så hosten slipper å taste inn samme tekst flere steder.
struct CopyPasteRow: View {
    @Binding var text: String
    var maxLength: Int = .max
    @State private var justCopied = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                UIPasteboard.general.string = text
                withAnimation(.easeInOut(duration: 0.2)) { justCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { justCopied = false }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                    Text(justCopied ? "Kopiert" : "Kopier")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(justCopied ? Color.primary600 : Color.neutral600)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.neutral50)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
            .opacity(text.isEmpty ? 0.4 : 1)

            Button {
                if let pasted = UIPasteboard.general.string {
                    let combined = text + pasted
                    text = String(combined.prefix(maxLength))
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Lim inn")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.neutral600)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.neutral50)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!UIPasteboard.general.hasStrings)
            .opacity(UIPasteboard.general.hasStrings ? 1 : 0.4)

            Spacer()
        }
    }
}
