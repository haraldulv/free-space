import SwiftUI

// MARK: - SpotVehicleContent
//
// Innhold for én plass i SpotVehicleStep (steg 5) — beskrivelse, kjøretøytyper, maks lengde.

struct SpotVehicleContent: View {
    @ObservedObject var form: ListingFormModel
    let index: Int

    private var spot: SpotMarker? {
        form.spotMarkers.indices.contains(index) ? form.spotMarkers[index] : nil
    }

    private var hasMultipleSpots: Bool { form.spots > 1 }
    private var descriptionLabel: String {
        hasMultipleSpots ? "Beskrivelse av denne plassen" : "Beskrivelse"
    }
    private var descriptionHelper: String? {
        hasMultipleSpots
            ? "Vises på plass-fanen. Annonsen har en egen overordnet beskrivelse."
            : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Beskrivelse (frivillig)
            field(label: descriptionLabel, optional: true) {
                VStack(alignment: .leading, spacing: 6) {
                    TextEditor(text: Binding(
                        get: { spot?.description ?? "" },
                        set: { form.spotMarkers[index].description = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.neutral50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.neutral200, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if let helper = descriptionHelper {
                        Text(helper)
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral500)
                    }
                }
            }

            // Kjøretøytype (multi-select) — samme card-stil som ParkingType
            VStack(alignment: .leading, spacing: 10) {
                Text("Kjøretøytyper")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)

                let availableTypes = VehicleType.available(for: form.category ?? .camping)
                let selectedTypes = spot?.effectiveVehicleTypes ?? []
                FlowLayout(spacing: 8) {
                    ForEach(availableTypes, id: \.self) { type in
                        let selected = selectedTypes.contains(type)
                        Button {
                            var current = form.spotMarkers[index].effectiveVehicleTypes
                            if let i = current.firstIndex(of: type) {
                                if current.count > 1 { current.remove(at: i) }
                            } else {
                                current.append(type)
                            }
                            form.spotMarkers[index].vehicleTypes = current
                            form.spotMarkers[index].vehicleType = nil
                        } label: {
                            VStack(spacing: 6) {
                                Image(type.lucideIcon)
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(selected ? Color.primary700 : Color.neutral600)
                                Text(type.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(selected ? Color.primary700 : Color.neutral700)
                            }
                            .frame(width: 96)
                            .padding(.vertical, 12)
                            .background(selected ? Color.primary50 : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: selected ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }

            // Maks lengde — kun for plasser med store kjøretøy (bobil/campingbil)
            // og kun for camping (parkering bruker dedikert dimensjoner-card).
            let needsLength = (spot?.effectiveVehicleTypes ?? []).contains(where: { !$0.isCompact })
            if needsLength && form.category != .parking {
                BigLengthInput(
                    length: Binding(
                        get: { spot?.vehicleMaxLength ?? 0 },
                        set: { form.spotMarkers[index].vehicleMaxLength = $0 > 0 ? $0 : nil }
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(label: String, optional: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                if optional {
                    Text("(valgfritt)")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral400)
                }
                Spacer()
            }
            content()
        }
    }
}

// MARK: - SpotPriceContent
//
// Innhold for én plass i SpotPriceStep (steg 6) — pris-modell + stor pris-display.

struct SpotPriceContent: View {
    @ObservedObject var form: ListingFormModel
    let index: Int
    @State private var showLongerStay: Bool = false

    private var spot: SpotMarker? {
        form.spotMarkers.indices.contains(index) ? form.spotMarkers[index] : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if form.category == .parking, let s = spot {
                // Parkering per døgn (24t). Lengre opphold-rabatter ligger
                // kollapset under prisen så samme side dekker hele pris-modellen.
                BigPriceInput(
                    price: Binding(
                        get: { s.price ?? 0 },
                        set: { newValue in
                            form.spotMarkers[index].price = newValue
                            form.spotMarkers[index].pricePerHour = nil
                            form.spotMarkers[index].pricePerNight = nil
                            form.spotMarkers[index].priceUnit = .time
                        }
                    ),
                    unitLabel: "dag"
                )
                FeeBreakdownCard(subtotal: s.price ?? 0, unitLabel: "dag")

                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showLongerStay.toggle() }
                } label: {
                    HStack {
                        Text("Lengre opphold-rabatter")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.neutral900)
                        Spacer()
                        Image(systemName: showLongerStay ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.neutral500)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
                }
                .buttonStyle(.plain)

                if showLongerStay {
                    InlineRentalPeriodsView(form: form, spotIndex: index)
                }
            } else if let s = spot {
                // Camping: kun per natt
                BigPriceInput(
                    price: Binding(
                        get: { s.pricePerNight ?? s.price ?? 0 },
                        set: { newValue in
                            form.spotMarkers[index].pricePerNight = newValue > 0 ? newValue : nil
                            form.spotMarkers[index].price = newValue > 0 ? newValue : nil
                            form.spotMarkers[index].priceUnit = .natt
                        }
                    ),
                    unitLabel: PriceUnit.natt.displayName
                )
                FeeBreakdownCard(subtotal: s.pricePerNight ?? s.price ?? 0, unitLabel: PriceUnit.natt.displayName)
            }
        }
        .onAppear {
            // Sikre invariant for parkering: price (kr/døgn) er settet pris-felt;
            // legacy pricePerHour og pricePerNight skal alltid være nil.
            guard form.spotMarkers.indices.contains(index) else { return }
            let s = form.spotMarkers[index]
            if form.category == .parking {
                if s.price == nil {
                    form.spotMarkers[index].price = 0
                }
                if s.pricePerHour != nil {
                    form.spotMarkers[index].pricePerHour = nil
                }
                if s.pricePerNight != nil {
                    form.spotMarkers[index].pricePerNight = nil
                }
                form.spotMarkers[index].priceUnit = .time
            }
        }
    }
}

// MARK: - FeeBreakdownCard
//
// Airbnb-stil oppsummering som viser host-pris, gjest-fee, gjestens totalpris
// og host-utbetaling. Forutsetter at SERVICE_FEE legges på TOPPEN av host-prisen
// (samme logikk som lib/config.ts → splitHostAndFee).

struct FeeBreakdownCard: View {
    let subtotal: Int
    let unitLabel: String

    private var fee: Int { PricingService.feeFromSubtotal(subtotal) }
    private var guestPrice: Int { subtotal + fee }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                row(label: "Grunnpris", value: subtotal, bold: false)
                Divider().padding(.vertical, 10)
                row(label: "Tjenestegebyr for gjester", value: fee, bold: false)
                Divider().padding(.vertical, 10)
                row(label: "Gjestens pris per \(unitLabel)", value: guestPrice, bold: true)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.neutral200.opacity(0.7), lineWidth: 1)
            )

            HStack {
                Text("Du tjener")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Spacer()
                Text(formatKr(subtotal))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.primary50.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.neutral200.opacity(0.5), lineWidth: 1)
            )
        }
        .opacity(subtotal > 0 ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: subtotal)
    }

    @ViewBuilder
    private func row(label: String, value: Int, bold: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 14, weight: bold ? .semibold : .regular))
                .foregroundStyle(.neutral900)
            Spacer()
            Text(formatKr(value))
                .font(.system(size: 14, weight: bold ? .semibold : .regular))
                .foregroundStyle(.neutral900)
        }
    }

    private func formatKr(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: value)) ?? "\(value)") kr"
    }
}

// MARK: - BigPriceInput
//
// Stor leken pris-input — sentrert tall (font 56) med pluss/minus-stepper.
// Tap på tallet åpner direkte input via TextField.

struct BigPriceInput: View {
    @Binding var price: Int
    let unitLabel: String
    @FocusState private var isFocused: Bool
    /// Intern tekst-state slik at vi kan tømme feltet når brukeren tapper —
    /// TextField med Int-binding tolker tom streng som 0 og viser dermed
    /// alltid "0" som standard. Med String-binding kan vi vise placeholder.
    @State private var text: String = ""

    private let step = 50
    private let maxPrice = 9999

    var body: some View {
        VStack(spacing: 12) {
            Text("Pris per \(unitLabel)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.neutral900)

            HStack(spacing: 20) {
                stepperButton(systemName: "minus", enabled: price >= step) {
                    price = max(0, price - step)
                }

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("", text: $text)
                            .keyboardType(.numberPad)
                            .focused($isFocused)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary600)
                            .frame(minWidth: 80)
                            .fixedSize()
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: price)
                        Text("kr")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.neutral500)
                    }
                    Text(isFocused ? "Trykk Ferdig når du er ferdig" : "per \(unitLabel) · tap for å skrive")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                }
                .frame(minWidth: 140)

                stepperButton(systemName: "plus", enabled: price < maxPrice) {
                    price = min(maxPrice, price + step)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.primary50)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .onAppear {
            text = price > 0 ? "\(price)" : ""
        }
        .onChange(of: isFocused) { _, focused in
            // Tap → tøm feltet alltid så brukeren kan skrive ny verdi direkte
            // uten å måtte slette eksisterende tegn først.
            if focused {
                text = ""
            } else if text.isEmpty {
                // Forlot feltet uten å skrive — normaliser til 0.
                text = "0"
                price = 0
            }
        }
        .onChange(of: text) { _, newValue in
            let cleaned = newValue.filter(\.isNumber)
            if cleaned != newValue {
                text = cleaned
                return
            }
            let parsed = Int(cleaned) ?? 0
            let clamped = min(maxPrice, max(0, parsed))
            if clamped != parsed {
                text = clamped > 0 ? "\(clamped)" : ""
            }
            if clamped != price { price = clamped }
        }
        .onChange(of: price) { _, newValue in
            // Hold tekst-state synkronisert med stepper-knappene.
            if !isFocused {
                text = newValue > 0 ? "\(newValue)" : "0"
            } else if newValue > 0 && (Int(text) ?? -1) != newValue {
                // Kun når focused: synk fra stepper-knappene. Hvis price=0
                // og bruker nettopp tappet (text=""), MÅ vi la text være tom
                // ellers hopper feltet til "0" og bruker får "05" etter første
                // tast.
                text = "\(newValue)"
            }
        }
    }

    private func stepperButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(enabled ? .primary700 : .neutral300)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(enabled ? Color.primary200 : Color.neutral200, lineWidth: 1.5))
                .shadow(color: enabled ? .black.opacity(0.06) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - BigLengthInput
//
// Leken meter-input som matcher BigPriceInput-stilen.

struct BigLengthInput: View {
    @Binding var length: Int
    @FocusState private var isFocused: Bool
    @State private var text: String = ""

    private let step = 1
    private let maxLength = 30

    var body: some View {
        VStack(spacing: 12) {
            Text("Maks kjøretøy-lengde")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.neutral900)

            Text("Største kjøretøy som passer på plassen, i meter. Påkrevd for bobil og campingbil.")
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 20) {
                stepperButton(systemName: "minus", enabled: length >= step) {
                    length = max(0, length - step)
                }

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("", text: $text)
                            .keyboardType(.numberPad)
                            .focused($isFocused)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary600)
                            .frame(minWidth: 60)
                            .fixedSize()
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: length)
                        Text("m")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.neutral500)
                    }
                    Text(isFocused ? "Trykk Ferdig når du er ferdig" : "meter · tap for å skrive")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                }
                .frame(minWidth: 120)

                stepperButton(systemName: "plus", enabled: length < maxLength) {
                    length = min(maxLength, length + step)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.primary50)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .onAppear {
            text = length > 0 ? "\(length)" : ""
        }
        .onChange(of: isFocused) { _, focused in
            // Tap → tøm feltet alltid så brukeren kan skrive ny verdi direkte.
            if focused {
                text = ""
            } else if text.isEmpty {
                text = "0"
                length = 0
            }
        }
        .onChange(of: text) { _, newValue in
            let cleaned = newValue.filter(\.isNumber)
            if cleaned != newValue {
                text = cleaned
                return
            }
            let parsed = Int(cleaned) ?? 0
            let clamped = min(maxLength, max(0, parsed))
            if clamped != parsed {
                text = clamped > 0 ? "\(clamped)" : ""
            }
            if clamped != length { length = clamped }
        }
        .onChange(of: length) { _, newValue in
            if !isFocused {
                text = newValue > 0 ? "\(newValue)" : "0"
            } else if newValue > 0 && (Int(text) ?? -1) != newValue {
                text = "\(newValue)"
            }
        }
    }

    private func stepperButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(enabled ? .primary700 : .neutral300)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(enabled ? Color.primary200 : Color.neutral200, lineWidth: 1.5))
                .shadow(color: enabled ? .black.opacity(0.06) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
