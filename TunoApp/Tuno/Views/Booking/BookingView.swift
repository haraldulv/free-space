import SwiftUI
import StripePaymentSheet

struct BookingView: View {
    let listing: Listing
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var bookingService = BookingService()
    @Environment(\.dismiss) var dismiss

    @State private var checkIn: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
    @State private var checkOut: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400 * 2)
    @State private var licensePlate = ""
    @State private var isRentalCar = false
    @State private var availableSpots: Int?
    @State private var totalSpots: Int?
    @State private var showConfirmation = false
    @State private var paymentResult: PaymentSheetResult?

    private var nights: Int {
        max(1, Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 1)
    }

    private var subtotal: Int {
        nights * (listing.price ?? 0)
    }

    private var serviceFee: Int {
        Int(ceil(Double(subtotal) * BookingService.serviceFeeRate))
    }

    private var total: Int {
        subtotal + serviceFee
    }

    private var blockedDateSet: Set<DateComponents> {
        var set = Set<DateComponents>()
        for dateStr in listing.blockedDates ?? [] {
            let parts = dateStr.split(separator: "-")
            if parts.count == 3,
               let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) {
                set.insert(DateComponents(year: y, month: m, day: d))
            }
        }
        return set
    }

    private var isValid: Bool {
        checkOut > checkIn && (isRentalCar || !licensePlate.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Listing summary
                listingSummary

                Divider()

                // Date selection
                dateSection

                Divider()

                // Vehicle info
                vehicleSection

                Divider()

                // Availability
                if let available = availableSpots, let total = totalSpots {
                    HStack(spacing: 6) {
                        Image(systemName: available > 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(available > 0 ? .green : .red)
                        Text(available > 0 ? "\(available) av \(total) plasser ledig" : "Ingen ledige plasser")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(available > 0 ? .neutral700 : .red)
                    }
                }

                // Price breakdown
                priceBreakdown

                // Error
                if let error = bookingService.error {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding(20)
        }
        .background(.white)
        .safeAreaInset(edge: .bottom) {
            // Pay button
            VStack(spacing: 0) {
                Divider()
                Button {
                    Task { await handlePayment() }
                } label: {
                    Group {
                        if bookingService.isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "apple.logo")
                                Text("Betal \(total) kr")
                            }
                            .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isValid && !(availableSpots == 0) ? Color.black : Color.neutral300)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isValid || bookingService.isProcessing || availableSpots == 0)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(.white)
        }
        .navigationTitle("Bestill")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showConfirmation) {
            BookingConfirmationView(
                listing: listing,
                checkIn: checkIn,
                checkOut: checkOut,
                total: total
            )
        }
        .task {
            await checkAvailability()
        }
        .onChange(of: checkIn) {
            if checkOut <= checkIn {
                checkOut = Calendar.current.date(byAdding: .day, value: 1, to: checkIn) ?? checkIn
            }
            Task { await checkAvailability() }
        }
        .onChange(of: checkOut) {
            Task { await checkAvailability() }
        }
    }

    // MARK: - Subviews

    private var listingSummary: some View {
        HStack(spacing: 14) {
            if let imageUrl = listing.images?.first, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.neutral100)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .lineLimit(2)
                if let city = listing.city {
                    Text(city)
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }
                HStack(spacing: 4) {
                    Text("\(listing.price ?? 0) kr")
                        .font(.system(size: 14, weight: .bold))
                    Text("/ \(listing.priceUnit?.displayName ?? "natt")")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }
            }

            Spacer()
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Datoer")
                .font(.system(size: 18, weight: .semibold))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Innsjekk")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.neutral500)
                    DatePicker("", selection: $checkIn,
                               in: Date()...,
                               displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "nb"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Utsjekk")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.neutral500)
                    DatePicker("", selection: $checkOut,
                               in: Calendar.current.date(byAdding: .day, value: 1, to: checkIn)!...,
                               displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "nb"))
                }

                Spacer()
            }

            Text("\(nights) \(nights == 1 ? "natt" : "netter")")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
        }
    }

    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kjøretøy")
                .font(.system(size: 18, weight: .semibold))

            Toggle("Leiebil (ingen registreringsnummer)", isOn: $isRentalCar)
                .font(.system(size: 14))
                .tint(.primary600)

            if !isRentalCar {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Registreringsnummer")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral700)
                    TextField("F.eks. AB 12345", text: $licensePlate)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Color.neutral50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.neutral200, lineWidth: 1)
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }
            }
        }
    }

    private var priceBreakdown: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(listing.price ?? 0) kr × \(nights) \(nights == 1 ? "natt" : "netter")")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral600)
                Spacer()
                Text("\(subtotal) kr")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral600)
            }

            HStack {
                Text("Serviceavgift")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral600)
                Spacer()
                Text("\(serviceFee) kr")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral600)
            }

            Divider()

            HStack {
                Text("Totalt")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("\(total) kr")
                    .font(.system(size: 16, weight: .bold))
            }
        }
        .padding(16)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func checkAvailability() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let result = await bookingService.checkAvailability(
            listingId: listing.id,
            checkIn: formatter.string(from: checkIn),
            checkOut: formatter.string(from: checkOut)
        )
        availableSpots = result.available
        totalSpots = result.total
    }

    private func handlePayment() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = CreateBookingRequest(
            listingId: listing.id,
            checkIn: formatter.string(from: checkIn),
            checkOut: formatter.string(from: checkOut),
            totalPrice: total,
            licensePlate: isRentalCar ? nil : licensePlate.trimmingCharacters(in: .whitespaces).uppercased(),
            isRentalCar: isRentalCar
        )

        let success = await bookingService.createBookingAndPreparePayment(
            request: request,
            listingTitle: listing.title
        )

        guard success, let paymentSheet = bookingService.paymentSheet else { return }

        paymentSheet.present(from: UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController ?? UIViewController()
        ) { result in
            switch result {
            case .completed:
                showConfirmation = true
            case .canceled:
                break
            case .failed(let error):
                bookingService.error = error.localizedDescription
            }
        }
    }
}
