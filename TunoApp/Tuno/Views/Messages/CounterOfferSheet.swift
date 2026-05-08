import SwiftUI

/// Sheet hvor en part skriver et motbud — pris (og evt. valgfri begrunnelse).
/// Datoer/spots/extras arves fra forrige tilbud serverside.
struct CounterOfferSheet: View {
    let bookingId: String
    let currentOfferPrice: Int
    /// Kort beskrivelse av siste tilbud (f.eks. "1 450 kr fra utleier")
    let currentOfferLabel: String
    let onSent: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var bookingService = BookingService()

    @State private var priceText: String = ""
    @State private var note: String = ""
    @State private var sending = false
    @State private var errorMessage: String?

    private var priceValue: Int? {
        let cleaned = priceText.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "kr", with: "")
        return Int(cleaned)
    }

    private var canSend: Bool {
        guard let p = priceValue else { return false }
        return p >= 3 && !sending
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Forrige tilbud")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.neutral500)
                        Text(currentOfferLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.neutral900)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ditt motbud")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.neutral700)
                        HStack(spacing: 8) {
                            TextField("F.eks. \(currentOfferPrice)", text: $priceText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 18, weight: .semibold))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Color.neutral50)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text("kr")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.neutral500)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Begrunnelse (valgfritt)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.neutral700)
                        TextField("Forklar gjerne hvorfor", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(Color.neutral50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            if sending {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Send motbud")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSend ? Color.primary600 : Color.neutral300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSend)
                }
                .padding(20)
            }
            .navigationTitle("Send motbud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Avbryt") { dismiss() }
                }
            }
        }
    }

    private func send() async {
        guard let p = priceValue else { return }
        sending = true
        errorMessage = nil

        let payload = BookingService.OfferPayload(
            bookingId: bookingId,
            totalPrice: p,
            checkIn: nil,
            checkOut: nil,
            message: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let response = await bookingService.sendOffer(payload: payload)
        sending = false

        if response?.offerId != nil {
            onSent()
            dismiss()
        } else {
            errorMessage = bookingService.error ?? "Kunne ikke sende motbud"
        }
    }
}
