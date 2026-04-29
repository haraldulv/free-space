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

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Beskrivelse (frivillig)
            field(label: "Beskrivelse", optional: true) {
                TextEditor(text: Binding(
                    get: { spot?.description ?? "" },
                    set: { form.spotMarkers[index].description = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 70)
                .padding(8)
                .background(Color.neutral50)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.neutral200, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Kjøretøytype (multi-select)
            VStack(alignment: .leading, spacing: 8) {
                Text("Kjøretøytyper")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("Velg én eller flere typer kjøretøy som passer her.")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)

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
                            HStack(spacing: 5) {
                                Image(type.lucideIcon)
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                                Text(type.displayName).font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(selected ? .white : .neutral700)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selected ? Color.primary600 : Color.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }

            // Maks lengde — kun for plasser med store kjøretøy (bobil/campingbil)
            let needsLength = (spot?.effectiveVehicleTypes ?? []).contains(where: { !$0.isCompact })
            if needsLength {
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
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

    private var spot: SpotMarker? {
        form.spotMarkers.indices.contains(index) ? form.spotMarkers[index] : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if form.category == .parking {
                parkingDualPricing
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
            }
        }
    }

    @ViewBuilder
    private var parkingDualPricing: some View {
        if let s = spot {
            let hourEnabled = (s.pricePerHour ?? 0) > 0 || s.priceUnit == .hour
            let nightEnabled = (s.pricePerNight ?? 0) > 0
            VStack(spacing: 14) {
                pricingRow(
                    label: "Per time",
                    enabled: hourEnabled,
                    price: Binding(
                        get: { s.pricePerHour ?? 0 },
                        set: { newValue in
                            form.spotMarkers[index].pricePerHour = newValue > 0 ? newValue : nil
                            updatePrimaryPriceUnit()
                        }
                    ),
                    unitLabel: "time",
                    onToggle: { isOn in
                        if isOn {
                            if (form.spotMarkers[index].pricePerHour ?? 0) == 0 {
                                form.spotMarkers[index].pricePerHour = 50
                            }
                        } else {
                            form.spotMarkers[index].pricePerHour = nil
                        }
                        updatePrimaryPriceUnit()
                    }
                )
                pricingRow(
                    label: "Per døgn (24t)",
                    enabled: nightEnabled,
                    price: Binding(
                        get: { s.pricePerNight ?? 0 },
                        set: { newValue in
                            form.spotMarkers[index].pricePerNight = newValue > 0 ? newValue : nil
                            updatePrimaryPriceUnit()
                        }
                    ),
                    unitLabel: "døgn",
                    onToggle: { isOn in
                        if isOn {
                            if (form.spotMarkers[index].pricePerNight ?? 0) == 0 {
                                form.spotMarkers[index].pricePerNight = 200
                            }
                        } else {
                            form.spotMarkers[index].pricePerNight = nil
                        }
                        updatePrimaryPriceUnit()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func pricingRow(
        label: String,
        enabled: Bool,
        price: Binding<Int>,
        unitLabel: String,
        onToggle: @escaping (Bool) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { onToggle(!enabled) }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(enabled ? Color.primary600 : Color.white)
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(enabled ? Color.primary600 : Color.neutral300, lineWidth: 2)
                            )
                        if enabled {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(enabled ? .neutral900 : .neutral500)
                Spacer()
            }
            if enabled {
                BigPriceInput(price: price, unitLabel: unitLabel)
            } else {
                disabledPriceCard(unitLabel: unitLabel)
            }
        }
        .padding(16)
        .background(enabled ? Color.primary50 : Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(enabled ? Color.primary200 : Color.neutral200, lineWidth: 1)
        )
    }

    private func disabledPriceCard(unitLabel: String) -> some View {
        HStack {
            Spacer()
            Text("Tap for å aktivere")
                .font(.system(size: 13))
                .foregroundStyle(.neutral400)
            Spacer()
        }
        .frame(height: 60)
    }

    /// Primær pris-enhet på spot.priceUnit — peker på det som skal vises i søk.
    /// Default = hour hvis hour er på (matcher screen-design "per time default").
    private func updatePrimaryPriceUnit() {
        guard form.spotMarkers.indices.contains(index) else { return }
        let s = form.spotMarkers[index]
        if (s.pricePerHour ?? 0) > 0 {
            form.spotMarkers[index].priceUnit = .hour
            form.spotMarkers[index].price = s.pricePerHour
        } else if (s.pricePerNight ?? 0) > 0 {
            form.spotMarkers[index].priceUnit = form.category == .parking ? .time : .natt
            form.spotMarkers[index].price = s.pricePerNight
        } else {
            form.spotMarkers[index].price = nil
        }
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
