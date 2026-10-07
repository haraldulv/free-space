import SwiftUI

/// Enkel redigering for parkering-annonser (Asker-pivoten). Målrettet UPDATE
/// som alltid skriver pris-invariantene sammen (price + pakker + display_price
/// + rental_period_types) — bruker ALDRI buildUpdateInput, som ville skrevet
/// price=0 for annonser uten per-plass-pris.
struct EditParkingView: View {
    let listing: Listing
    var onSaved: ((Listing) -> Void)? = nil
    var onDeleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var descriptionText: String
    @State private var dailyText: String
    @State private var monthlyText: String
    @State private var isActive: Bool
    @State private var isSaving = false
    @State private var error: String?
    @State private var showDeleteConfirm = false
    @State private var showSavedToast = false

    init(listing: Listing, onSaved: ((Listing) -> Void)? = nil, onDeleted: (() -> Void)? = nil) {
        self.listing = listing
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _title = State(initialValue: listing.title)
        _descriptionText = State(initialValue: listing.description ?? "")
        let packages = (listing.spotMarkers ?? []).flatMap { $0.pricePackages ?? [] }
        let day = packages.first(where: { $0.periodType == .day && $0.periodValue == 1 })?.priceNok
            ?? listing.price ?? 0
        let month = packages.first(where: { $0.periodType == .month && $0.periodValue == 1 })?.priceNok
        _dailyText = State(initialValue: day > 0 ? "\(day)" : "")
        _monthlyText = State(initialValue: month.map { "\($0)" } ?? "")
        _isActive = State(initialValue: listing.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let error {
                        Text(error)
                            .font(.tuno(.body))
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control))
                    }

                    field(label: "Tittel") {
                        TextField("Tittel", text: $title)
                            .font(.tuno(.body))
                    }

                    field(label: "Beskrivelse") {
                        TextField("Beskrivelse", text: $descriptionText, axis: .vertical)
                            .font(.tuno(.body))
                            .lineLimit(3...8)
                    }

                    field(label: "Dagsleie (kr per dag)") {
                        TextField("0", text: $dailyText)
                            .keyboardType(.numberPad)
                            .font(.tuno(.body))
                            .onChange(of: dailyText) { _, v in
                                let digits = v.filter(\.isNumber)
                                if digits != v { dailyText = digits }
                            }
                    }

                    field(label: "Fast månedsplass (kr per måned)") {
                        TextField("0", text: $monthlyText)
                            .keyboardType(.numberPad)
                            .font(.tuno(.body))
                            .onChange(of: monthlyText) { _, v in
                                let digits = v.filter(\.isNumber)
                                if digits != v { monthlyText = digits }
                            }
                    }

                    // Pause
                    Toggle(isOn: $isActive) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Annonsen er aktiv")
                                .font(.tuno(.body))
                                .foregroundStyle(.neutral900)
                            Text("Slå av for å pause nye bestillinger.")
                                .font(.tuno(.caption))
                                .foregroundStyle(.neutral500)
                        }
                    }
                    .tint(.primary600)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: TunoRadius.control)
                            .stroke(Color.neutral200, lineWidth: 1)
                    )

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Slett annonsen")
                            .font(.tuno(.body))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: TunoRadius.control)
                                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Color.neutral50)
            .navigationTitle("Rediger annonse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { dismiss() }
                        .foregroundStyle(.neutral700)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Lagre")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(canSave ? Color.primary600 : .neutral400)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .confirmationDialog("Slette annonsen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Slett permanent", role: .destructive) {
                    Task { await deleteListing() }
                }
                Button("Avbryt", role: .cancel) { }
            } message: {
                Text("Dette kan ikke angres. Eksisterende bestillinger påvirkes ikke.")
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text("Lagret")
                        .font(.tuno(.body))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.ink)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && Int(dailyText) ?? 0 > 0
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.tuno(.label))
                .foregroundStyle(.neutral600)
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: TunoRadius.control)
                        .stroke(Color.neutral200, lineWidth: 1)
                )
        }
    }

    // MARK: - Save

    /// Kun feltene denne skjermen eier. Pris-invariantene skrives alltid
    /// sammen i samme payload.
    private struct ParkingUpdatePayload: Encodable {
        let title: String
        let description: String
        let price: Int
        let isActive: Bool
        let spotMarkers: [SpotMarker]
        let rentalPeriodTypes: [String]
        let displayPrice: Int
        let displayPriceSuffix: String

        enum CodingKeys: String, CodingKey {
            case title, description, price
            case isActive = "is_active"
            case spotMarkers = "spot_markers"
            case rentalPeriodTypes = "rental_period_types"
            case displayPrice = "display_price"
            case displayPriceSuffix = "display_price_suffix"
        }
    }

    private func save() async {
        guard let day = Int(dailyText), day > 0 else { return }
        let month = Int(monthlyText).flatMap { $0 > 0 ? $0 : nil }
        isSaving = true
        error = nil

        var packages: [PricePackage] = [PricePackage(periodType: .day, periodValue: 1, priceNok: day)]
        if let month {
            packages.append(PricePackage(periodType: .month, periodValue: 1, priceNok: month))
        }

        // Behold eksisterende markører (id/posisjon/label/bilder/blokkeringer),
        // men skriv pris-modellen på nytt: price=nil + ferske pakker.
        var markers = listing.spotMarkers ?? []
        for i in markers.indices {
            markers[i].price = nil
            markers[i].pricePerNight = nil
            markers[i].pricePackages = packages
        }

        var periods = ["DAY"]
        if month != nil { periods.append("MONTH") }

        let payload = ParkingUpdatePayload(
            title: title.trimmingCharacters(in: .whitespaces),
            description: descriptionText.trimmingCharacters(in: .whitespaces),
            price: day,
            isActive: isActive,
            spotMarkers: markers,
            rentalPeriodTypes: periods.sorted(),
            displayPrice: day,
            displayPriceSuffix: ""
        )

        do {
            let updated: [Listing] = try await supabase
                .from("listings")
                .update(payload)
                .eq("id", value: listing.id)
                .select()
                .execute()
                .value

            isSaving = false
            if let fresh = updated.first {
                onSaved?(fresh)
            }
            withAnimation { showSavedToast = true }
            try? await Task.sleep(nanoseconds: 800_000_000)
            dismiss()
        } catch {
            self.error = "Kunne ikke lagre: \(error.localizedDescription)"
            isSaving = false
        }
    }

    private func deleteListing() async {
        isSaving = true
        do {
            try await supabase
                .from("listings")
                .delete()
                .eq("id", value: listing.id)
                .execute()
            isSaving = false
            onDeleted?()
            dismiss()
        } catch {
            self.error = "Kunne ikke slette: \(error.localizedDescription)"
            isSaving = false
        }
    }
}
