import SwiftUI

struct BookingConfirmationView: View {
    let listing: Listing
    let checkIn: Date
    let checkOut: Date
    let total: Int
    @Environment(\.dismiss) var dismiss

    private var nights: Int {
        max(1, Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 1)
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "nb")
        return f
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("Bestilling bekreftet!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text("Du vil motta en bekreftelse snart.")
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral500)
            }

            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    if let imageUrl = listing.images?.first, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color.neutral100)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        if let city = listing.city {
                            Text(city)
                                .font(.system(size: 13))
                                .foregroundStyle(.neutral500)
                        }
                    }
                    Spacer()
                }

                Divider()

                detailRow(label: "Innsjekk", value: dateFormatter.string(from: checkIn))
                detailRow(label: "Utsjekk", value: dateFormatter.string(from: checkOut))
                detailRow(label: "Varighet", value: "\(nights) \(nights == 1 ? "natt" : "netter")")

                Divider()

                HStack {
                    Text("Totalt betalt")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text("\(total) kr")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .padding(20)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.neutral200, lineWidth: 1)
            )

            Spacer()

            Button {
                NotificationCenter.default.post(name: .switchToBookingsTab, object: nil)
            } label: {
                Text("Se mine bestillinger")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .background(.white)
        .navigationBarBackButtonHidden(true)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.neutral700)
        }
    }
}
