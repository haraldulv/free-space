import SwiftUI

struct PublishStep: View {
    @ObservedObject var form: ListingFormModel
    @State private var carouselIndex: Int = 0

    var body: some View {
        WizardScreen(
            title: "Klar til å publisere?",
            subtitle: "Sjekk at alt ser bra ut. Du kan endre detaljer når som helst etter publisering."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if !form.imageURLs.isEmpty {
                    imageCarousel
                }

                titleCard

                summaryGrid

                if form.spotMarkers.count > 0 {
                    spotsSection
                }

                if !form.selectedAmenities.isEmpty {
                    amenitiesSection
                }

                tipCard
            }
        }
    }

    /// Bla-bare bildekarusell — bruker TabView page-style så bruker kan
    /// sveipe gjennom alle bildene før publisering.
    private var imageCarousel: some View {
        VStack(spacing: 8) {
            TabView(selection: $carouselIndex) {
                ForEach(Array(form.imageURLs.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(Color.neutral100)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .tag(index)
                }
            }
            .frame(height: 220)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if form.imageURLs.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<form.imageURLs.count, id: \.self) { i in
                        Circle()
                            .fill(i == carouselIndex ? Color.primary600 : Color.neutral200)
                            .frame(width: i == carouselIndex ? 8 : 6, height: i == carouselIndex ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: carouselIndex)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.neutral900)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary600)
                Text(form.address.isEmpty ? "Adresse mangler" : form.address)
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
                    .lineLimit(2)
            }
            if !form.description.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(form.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral600)
                    .lineLimit(4)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.neutral200, lineWidth: 1))
    }

    /// Speiler `buildInput`-fallbacken så review viser samme tittel som lagres.
    private var displayTitle: String {
        let trimmed = form.title.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        let categoryName = form.category?.displayName ?? "Plass"
        let location = !form.address.isEmpty ? form.address
            : !form.city.isEmpty ? form.city
            : !form.region.isEmpty ? form.region
            : "Norge"
        return "\(categoryName) i \(location)"
    }

    private var summaryGrid: some View {
        VStack(spacing: 0) {
            summaryRow(icon: "tent.fill", label: "Type", value: form.category?.displayName ?? "—")
            Divider().padding(.leading, 56)
            summaryRow(icon: "mappin.and.ellipse", label: "Plasser",
                       value: form.spotMarkers.count == 1 ? "1 plass" : "\(form.spotMarkers.count) plasser")
            Divider().padding(.leading, 56)
            summaryRow(icon: "tag.fill", label: "Pris", value: priceSummary)
            Divider().padding(.leading, 56)
            summaryRow(
                icon: form.instantBooking ? "bolt.fill" : "hand.raised.fill",
                label: "Booking",
                value: form.instantBooking ? "Direktebooking" : "Godkjenn først"
            )
            Divider().padding(.leading, 56)
            summaryRow(icon: "photo.stack", label: "Bilder",
                       value: form.imageURLs.isEmpty ? "Ingen" : "\(form.imageURLs.count)")
            Divider().padding(.leading, 56)
            summaryRow(icon: "calendar", label: "Blokkerte datoer",
                       value: form.blockedDates.isEmpty ? "Ingen" : "\(form.blockedDates.count)")
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.neutral200, lineWidth: 1))
    }

    private var priceSummary: String {
        let prices = form.spotMarkers.compactMap { $0.price }.filter { $0 > 0 }
        guard let lo = prices.min(), let hi = prices.max() else { return "—" }
        let units = Set(form.spotMarkers.compactMap { $0.priceUnit?.displayName ?? form.priceUnit.displayName })
        let unitText = units.count == 1 ? (units.first ?? form.priceUnit.displayName) : "plass"
        return lo == hi ? "\(lo) kr/\(unitText)" : "\(lo)–\(hi) kr/\(unitText)"
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.primary50).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary700)
            }
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.neutral600)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral900)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// Per-plass oppsummering — én rad per plass med kjøretøytyper og pris.
    /// Hjelper utleier å verifisere at hver plass er konfigurert riktig.
    private var spotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Plasser")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { index, spot in
                    spotRow(index: index, spot: spot)
                    if index < form.spotMarkers.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.neutral200, lineWidth: 1))
        }
    }

    private func spotRow(index: Int, spot: SpotMarker) -> some View {
        let label = spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? spot.label!
            : "Plass \(index + 1)"
        let unit = form.effectivePriceUnit(for: spot).displayName
        let priceText: String = {
            if let p = spot.price, p > 0 { return "\(p) kr/\(unit)" }
            return "Pris mangler"
        }()
        let vehicleText: String = {
            let types = spot.effectiveVehicleTypes
            if types.isEmpty { return "Ingen biltype" }
            return types.map { $0.displayName }.joined(separator: " • ")
        }()
        let extras = spot.extras ?? []
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Color.primary50).frame(width: 32, height: 32)
                Text("\(index + 1)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary700)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text(vehicleText)
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
                    .lineLimit(2)
                if !extras.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(extras) { extra in
                            extraChip(extra)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer()
            Text(priceText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary700)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// Kompakt chip per tillegg på en plass — viser navn og pris.
    private func extraChip(_ extra: ListingExtra) -> some View {
        let suffix = extra.perNight ? "/natt" : ""
        return HStack(spacing: 4) {
            Text(extra.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.neutral700)
            Text("\(extra.price) kr\(suffix)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary700)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary50)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.primary200, lineWidth: 1))
    }

    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fasiliteter")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
                .padding(.leading, 4)

            FlowLayout(spacing: 8) {
                ForEach(Array(form.selectedAmenities), id: \.self) { rawValue in
                    if let amenity = AmenityType(rawValue: rawValue) {
                        amenityChip(amenity)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.neutral200, lineWidth: 1))
        }
    }

    private func amenityChip(_ amenity: AmenityType) -> some View {
        HStack(spacing: 6) {
            Image(systemName: amenity.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary700)
            Text(amenity.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.neutral900)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary50)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.primary200, lineWidth: 1))
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(.primary600)
            VStack(alignment: .leading, spacing: 4) {
                Text("Klar til å bli utleier")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("Etter publisering vises annonsen din i søk umiddelbart. Du kan deaktivere den når som helst fra \"Mine annonser\".")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral600)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary200, lineWidth: 1))
    }
}

/// Suksess-animasjon som vises etter at annonsen er publisert.
struct ListingPublishedCelebration: View {
    var onDismiss: () -> Void
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.primary600)
                        .frame(width: 120, height: 120)
                    Image(systemName: "checkmark")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 8) {
                    Text("Annonsen er publisert!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.neutral900)
                    Text("Gjester kan nå finne og bestille hos deg.")
                        .font(.system(size: 15))
                        .foregroundStyle(.neutral600)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                Button(action: onDismiss) {
                    Text("Til Mine annonser")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 8)
            }
            .padding(28)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 36)
            .scaleEffect(scale)
            .opacity(opacity)

            // Konfetti renner over hele skjermen (kortet inkludert).
            // allowsHitTesting(false) så taps fortsatt går igjennom til kortet.
            LottieOrFallback(name: "confetti") { EmptyView() }
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
