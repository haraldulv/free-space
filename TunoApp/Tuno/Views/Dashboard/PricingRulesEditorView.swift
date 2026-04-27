import SwiftUI

/// Editor for pris-regler på én annonse. Speiler web PricingRulesPanel.
/// Helg-pris (én regel, day_mask fredag+lørdag+søndag) + sesong-perioder.
struct PricingRulesEditorView: View {
    let listingId: String
    let basePrice: Int
    /// Pris-enhet for visning av "kr/natt" / "kr/døgn" / "kr/time".
    /// Pricing-rules selv er natt-baserte i dag — denne styrer kun label-tekst.
    var priceUnit: PriceUnit = .natt

    private var unitLabel: String { priceUnit.displayName }

    @Environment(\.dismiss) var dismiss
    @State private var rules: [PricingService.Rule] = []
    @State private var loading = true
    @State private var saving = false
    @State private var error: String?

    // Helg-state
    @State private var weekendEnabled = false
    @State private var weekendPriceText = ""
    @State private var weekendDirty = false

    // Ny sesong-state
    @State private var newSeasonStart = Date()
    @State private var newSeasonEnd = Date()
    @State private var newSeasonPriceText = ""

    private var weekendRule: PricingService.Rule? {
        rules.first(where: { $0.kind == "weekend" })
    }

    private var seasonRules: [PricingService.Rule] {
        rules
            .filter { $0.kind == "season" }
            .sorted { ($0.start_date ?? "") < ($1.start_date ?? "") }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Annonsens standardpris er \(basePrice) kr/\(unitLabel). Legg til helg-pris eller sesong-regler som overstyrer.")
                                .font(.system(size: 13))
                                .foregroundStyle(.neutral600)

                            weekendSection
                            seasonSection

                            if let error {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Prisregler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Ferdig") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Helg-seksjon

    private var weekendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Helg-pris")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Fredag, lørdag og søndag får egen pris. Presedens: sesong > helg > standard.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { weekendEnabled },
                    set: { newVal in
                        weekendEnabled = newVal
                        weekendDirty = true
                    }
                ))
                .labelsHidden()
                .tint(.primary600)
            }

            if weekendEnabled {
                HStack(spacing: 8) {
                    TextField("F.eks. \(Int(Double(basePrice) * 1.25))", text: $weekendPriceText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 140)
                        .onChange(of: weekendPriceText) { _, _ in weekendDirty = true }
                    Text("kr/\(unitLabel)")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                    Spacer()
                }
            }

            if weekendDirty {
                Button {
                    Task { await saveWeekend() }
                } label: {
                    HStack(spacing: 6) {
                        if saving { ProgressView().scaleEffect(0.7).tint(.white) }
                        Text("Lagre helg-pris")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.primary600)
                    .clipShape(Capsule())
                }
                .disabled(saving)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    // MARK: - Sesong-seksjon

    private var seasonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Sesong-pris")
                    .font(.system(size: 16, weight: .semibold))
                Text("Sett pris for en periode (f.eks. sommeruker). Overstyrer helg og standard.")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }

            ForEach(seasonRules) { rule in
                seasonRuleRow(rule)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Legg til sesong")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.neutral700)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Fra").font(.system(size: 11)).foregroundStyle(.neutral500)
                        DatePicker("", selection: $newSeasonStart, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Til").font(.system(size: 11)).foregroundStyle(.neutral500)
                        DatePicker("", selection: $newSeasonEnd, in: newSeasonStart..., displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }

                HStack(spacing: 8) {
                    TextField("Pris", text: $newSeasonPriceText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 100)
                    Text("kr/\(unitLabel)").font(.system(size: 13)).foregroundStyle(.neutral500)
                    Spacer()
                    Button {
                        Task { await addSeason() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Legg til")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(canAddSeason ? Color.primary600 : Color.neutral300)
                        .clipShape(Capsule())
                    }
                    .disabled(!canAddSeason || saving)
                }
            }
            .padding(12)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    private var canAddSeason: Bool {
        guard let price = Int(newSeasonPriceText), price > 0 else { return false }
        return newSeasonStart <= newSeasonEnd
    }

    private func seasonRuleRow(_ rule: PricingService.Rule) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.primary600)
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 2) {
                if let s = rule.start_date, let e = rule.end_date {
                    Text("\(s) – \(e)")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral900)
                }
                Text("\(rule.price) kr/\(unitLabel)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.neutral600)
            }
            Spacer()
            Button {
                Task { await removeRule(rule) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .disabled(saving)
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200, lineWidth: 1))
    }

    // MARK: - Actions

    private func load() async {
        loading = true
        rules = await PricingService.fetchRules(listingId: listingId)
        if let w = weekendRule {
            weekendEnabled = true
            weekendPriceText = String(w.price)
        } else {
            weekendEnabled = false
            weekendPriceText = String(Int(Double(basePrice) * 1.25))
        }
        weekendDirty = false
        loading = false
    }

    private func saveWeekend() async {
        error = nil
        saving = true
        defer { saving = false }
        let price: Int? = weekendEnabled ? Int(weekendPriceText) : nil
        if weekendEnabled && (price ?? 0) <= 0 {
            error = "Ugyldig pris."
            return
        }
        do {
            try await PricingService.setWeekendPrice(listingId: listingId, price: price)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func addSeason() async {
        error = nil
        guard canAddSeason, let price = Int(newSeasonPriceText) else {
            error = "Sjekk pris og datoer."
            return
        }
        saving = true
        defer { saving = false }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Europe/Oslo")
        let start = fmt.string(from: newSeasonStart)
        let end = fmt.string(from: newSeasonEnd)
        do {
            try await PricingService.addSeasonRule(
                listingId: listingId,
                startDate: start,
                endDate: end,
                price: price,
            )
            newSeasonPriceText = ""
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func removeRule(_ rule: PricingService.Rule) async {
        error = nil
        saving = true
        defer { saving = false }
        do {
            try await PricingService.removeRule(ruleId: rule.id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
