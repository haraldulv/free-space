import SwiftUI
import GoogleMaps

struct MarkSpotsStep: View {
    @ObservedObject var form: ListingFormModel
    @State private var mapTrigger = UUID()
    @State private var mapType: GMSMapViewType = .hybrid

    private var hasAllSpots: Bool {
        form.spotMarkers.count >= form.spots
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Marker plassene på kartet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.neutral900)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 14)

            ZStack(alignment: .topTrailing) {
                LocationPickerMapView(
                    lat: .constant(form.lat),
                    lng: .constant(form.lng),
                    spotMarkers: $form.spotMarkers,
                    isSpotMode: true,
                    maxSpots: form.spots,
                    updateTrigger: mapTrigger,
                    onMaxReached: nil,
                    mainMarkerDraggable: false,
                    mapType: mapType
                )

                // Floating-kontroller øverst til høyre, Apple Maps-stil.
                VStack(spacing: 8) {
                    floatingButton(systemName: mapType == .hybrid ? "map.fill" : "globe.europe.africa.fill") {
                        mapType = (mapType == .hybrid) ? .normal : .hybrid
                    }

                    if !form.spotMarkers.isEmpty {
                        floatingButton(systemName: "arrow.uturn.backward") {
                            withAnimation { form.spotMarkers.removeAll() }
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.trailing, 12)

                // Stort tooltip-kort på toppen av kartet med tydelig
                // ikon + handling + status. Høyre-padding 64 reserverer plass
                // til floating kart-kontrollene (40pt + 12pt margin + 12pt buffer).
                VStack {
                    instructionCard
                        .padding(.leading, 12)
                        .padding(.trailing, 64)
                        .padding(.top, 12)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var instructionCard: some View {
        if !hasAllSpots {
            instructionRow(
                icon: "hand.tap.fill",
                title: form.spotMarkers.isEmpty
                    ? "Tap på kartet for å markere plass 1"
                    : "Tap på kartet for å markere plass \(form.spotMarkers.count + 1)",
                subtitle: "\(form.spotMarkers.count) av \(form.spots) markert"
            )
        } else {
            instructionRow(
                icon: "hand.point.up.left.fill",
                title: "Alle plasser er markert",
                subtitle: "Trykk og hold på en pin for å flytte den"
            )
        }
    }

    private func instructionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary600)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }

    private func floatingButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.neutral800)
                .frame(width: 40, height: 40)
                .background(.regularMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }
}
