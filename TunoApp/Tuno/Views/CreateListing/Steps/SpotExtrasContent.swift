import SwiftUI

/// Innhold for én plass i SpotExtrasStep — editerbare presets + egendefinert tillegg.
struct SpotExtrasContent: View {
    @ObservedObject var form: ListingFormModel
    let index: Int

    @State private var showAddCustom = false
    @State private var customName = ""
    @State private var customPrice = ""
    @State private var customPerNight = false

    private var spot: SpotMarker? {
        form.spotMarkers.indices.contains(index) ? form.spotMarkers[index] : nil
    }

    private var category: ListingCategory { form.category ?? .camping }
    private var presets: [ExtraType] {
        ExtraType.available(for: category, scope: .siteSpecific)
    }
    private var unitLabel: String {
        guard let s = spot else { return "natt" }
        return form.effectivePriceUnit(for: s).displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Preset-tillegg (kategori-relevante)
            if !presets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Vanlige tillegg")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.neutral500)
                    ForEach(presets, id: \.rawValue) { preset in
                        presetRow(preset)
                    }
                }
            }

            // Egendefinerte tillegg som allerede er lagt til
            let customExtras = (spot?.extras ?? []).filter { extra in
                !presets.contains(where: { $0.rawValue == extra.id })
            }
            if !customExtras.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Egendefinerte tillegg")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.neutral500)
                    ForEach(customExtras, id: \.id) { extra in
                        customExtraRow(extra)
                    }
                }
            }

            // Legg til egendefinert
            Button {
                customName = ""
                customPrice = ""
                customPerNight = false
                showAddCustom = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 17))
                    Text("Legg til eget tillegg")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.primary700)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primary50)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundColor(.primary300)
                )
            }
            .padding(.top, 4)
        }
        .sheet(isPresented: $showAddCustom) {
            customExtraSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Preset row med editerbar pris

    private func presetRow(_ preset: ExtraType) -> some View {
        let extras = spot?.extras ?? []
        let existing = extras.first(where: { $0.id == preset.rawValue })
        let isSelected = existing != nil
        return VStack(spacing: 0) {
            Button {
                togglePreset(preset)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: preset.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? .primary700 : .neutral500)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.neutral900)
                        Text("Standard \(preset.defaultPrice) kr\(preset.perNight ? "/" + unitLabel : "")")
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral500)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? .primary600 : .neutral300)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Pris-redigering hvis valgt
            if isSelected, let existing {
                Divider().padding(.horizontal, 14)
                HStack(spacing: 8) {
                    Text("Pris")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral600)
                        .frame(width: 50, alignment: .leading)
                    TextField("\(preset.defaultPrice)", value: Binding(
                        get: { existing.price },
                        set: { newPrice in updateExtraPrice(id: preset.rawValue, newPrice: max(0, newPrice)) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 90)
                    Text("kr\(preset.perNight ? "/" + unitLabel : "")")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.primary300 : Color.neutral200, lineWidth: 1)
        )
    }

    // MARK: - Custom extra row

    private func customExtraRow(_ extra: ListingExtra) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(.primary600)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(extra.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.neutral900)
                Text("\(extra.price) kr\(extra.perNight ? "/" + unitLabel : "")")
                    .font(.system(size: 11))
                    .foregroundStyle(.neutral500)
            }
            Spacer()
            Button {
                removeExtra(id: extra.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.neutral400)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    // MARK: - Custom add sheet

    private var customExtraSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Navn
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Navn på tillegget")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.neutral900)
                        TextField("F.eks. Strøm 16A", text: $customName)
                            .textInputAutocapitalization(.sentences)
                            .padding(14)
                            .background(Color.neutral50)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.neutral200, lineWidth: 1)
                            )
                    }

                    // Pris
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pris")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.neutral900)
                        HStack(spacing: 8) {
                            TextField("F.eks. 50", text: $customPrice)
                                .keyboardType(.numberPad)
                                .padding(14)
                                .background(Color.neutral50)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.neutral200, lineWidth: 1)
                                )
                            Text("kr")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.neutral500)
                        }
                    }

                    // Beregning — segmented picker (matcher Pris-modell)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Beregning")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.neutral900)
                        HStack(spacing: 0) {
                            extraModeSegment(
                                label: "Engangspris",
                                sublabel: "Betales én gang",
                                isSelected: !customPerNight
                            ) {
                                customPerNight = false
                            }
                            extraModeSegment(
                                label: "Per \(unitLabel)",
                                sublabel: "× antall \(unitLabel)er",
                                isSelected: customPerNight
                            ) {
                                customPerNight = true
                            }
                        }
                        .background(Color.neutral100)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Eget tillegg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { showAddCustom = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Legg til") {
                        addCustomExtra()
                        showAddCustom = false
                    }
                    .fontWeight(.semibold)
                    .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty
                              || (Int(customPrice) ?? 0) < 1)
                }
            }
        }
    }

    @ViewBuilder
    private func extraModeSegment(label: String, sublabel: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Text(sublabel)
                    .font(.system(size: 11))
                    .opacity(0.85)
            }
            .foregroundStyle(isSelected ? .white : .neutral700)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.primary600 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mutations

    private func togglePreset(_ preset: ExtraType) {
        var extras = form.spotMarkers[index].extras ?? []
        if let i = extras.firstIndex(where: { $0.id == preset.rawValue }) {
            extras.remove(at: i)
        } else {
            extras.append(ListingExtra(
                id: preset.rawValue,
                name: preset.name,
                price: preset.defaultPrice,
                perNight: preset.perNight
            ))
        }
        form.spotMarkers[index].extras = extras.isEmpty ? nil : extras
    }

    private func updateExtraPrice(id: String, newPrice: Int) {
        var extras = form.spotMarkers[index].extras ?? []
        if let i = extras.firstIndex(where: { $0.id == id }) {
            extras[i].price = newPrice
            form.spotMarkers[index].extras = extras
        }
    }

    private func removeExtra(id: String) {
        var extras = form.spotMarkers[index].extras ?? []
        extras.removeAll { $0.id == id }
        form.spotMarkers[index].extras = extras.isEmpty ? nil : extras
    }

    private func addCustomExtra() {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let priceInt = Int(customPrice), priceInt > 0 else { return }
        let newExtra = ListingExtra(
            id: "custom-\(UUID().uuidString.lowercased().prefix(8))",
            name: trimmed,
            price: priceInt,
            perNight: customPerNight
        )
        var extras = form.spotMarkers[index].extras ?? []
        extras.append(newExtra)
        form.spotMarkers[index].extras = extras
    }
}
