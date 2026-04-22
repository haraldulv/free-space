import SwiftUI

/// Fullskjerm-sheet for å plassere plass-markører på kartet.
/// Endringer lagres kun ved "Lagre" — "Avbryt" forkaster alt.
/// Har cap på antall plasser + første-gangs-tooltip.
struct SpotPlacementSheet: View {
    @Binding var spotMarkers: [SpotMarker]
    let mainLat: Double
    let mainLng: Double
    let maxSpots: Int

    @Environment(\.dismiss) var dismiss

    @State private var workingMarkers: [SpotMarker]
    @State private var showTooltip: Bool
    @State private var dontAskAgain = false
    @State private var showSaveConfirm = false
    @State private var mapUpdateTrigger = UUID()

    private static let tooltipKey = "tuno.spotPlacementTooltipSeen"

    init(spotMarkers: Binding<[SpotMarker]>, mainLat: Double, mainLng: Double, maxSpots: Int) {
        self._spotMarkers = spotMarkers
        self.mainLat = mainLat
        self.mainLng = mainLng
        self.maxSpots = maxSpots
        self._workingMarkers = State(initialValue: spotMarkers.wrappedValue)
        // Tooltip vises hver gang med mindre bruker har huket av "ikke spør meg igjen"
        self._showTooltip = State(initialValue: !UserDefaults.standard.bool(forKey: Self.tooltipKey))
    }

    private var atMax: Bool {
        maxSpots > 0 && workingMarkers.count >= maxSpots
    }

    private var dirty: Bool {
        spotMarkers != workingMarkers
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Kart tar hele skjermen
            LocationPickerMapView(
                lat: .constant(mainLat),
                lng: .constant(mainLng),
                spotMarkers: $workingMarkers,
                isSpotMode: true,
                maxSpots: maxSpots,
                updateTrigger: mapUpdateTrigger,
                onMaxReached: nil,
                mainMarkerDraggable: false
            )
            .ignoresSafeArea(edges: [.bottom, .horizontal])

            // Top bar — Avbryt, progress, Lagre
            VStack(spacing: 0) {
                HStack {
                    Button(action: cancelTapped) {
                        Text("Avbryt")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.neutral900)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.08), radius: 4)
                    }

                    Spacer()

                    if maxSpots > 0 {
                        Text("\(workingMarkers.count) / \(maxSpots)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.neutral900)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.08), radius: 4)
                            .monospacedDigit()
                    }

                    Spacer()

                    Button(action: saveTapped) {
                        Text("Lagre")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.primary600)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()
            }

            // Bottom controls — Reset + hint
            VStack {
                Spacer()

                HStack(spacing: 10) {
                    if !workingMarkers.isEmpty {
                        Button {
                            withAnimation {
                                _ = workingMarkers.popLast()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Angre")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.neutral900)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.08), radius: 4)
                        }
                    }

                    Spacer()

                    hintPill
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            // Første-gangs-tooltip
            if showTooltip {
                tooltipOverlay
            }

            // Lagre-bekreftelse ved avbryt med endringer
            if showSaveConfirm {
                saveConfirmOverlay
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    @ViewBuilder
    private var hintPill: some View {
        if atMax {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Alle \(maxSpots) plassert")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.neutral900)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 4)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill").foregroundStyle(.primary600)
                Text("Tap for å plassere")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.neutral900)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 4)
        }
    }

    @ViewBuilder
    private var tooltipOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.primary600)
                    Text("Plasser plassene dine")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }

                tooltipStep(number: "1", text: "Tap på kartet for å plassere en plass")
                tooltipStep(number: "2", text: "Trykk og hold på en plass for å flytte den")
                tooltipStep(number: "3", text: "Tap 'Angre' for å fjerne siste plass")
                tooltipStep(number: "4", text: "Tap 'Lagre' når du er ferdig")

                Button {
                    dontAskAgain.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: dontAskAgain ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundStyle(dontAskAgain ? Color.primary600 : Color.neutral400)
                        Text("Ikke spør meg igjen")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral700)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                Button {
                    if dontAskAgain {
                        UserDefaults.standard.set(true, forKey: Self.tooltipKey)
                    }
                    withAnimation { showTooltip = false }
                } label: {
                    Text("Skjønner!")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }

    private func tooltipStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.primary600)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.neutral700)
            Spacer()
        }
    }

    @ViewBuilder
    private var saveConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Forkast endringer?")
                    .font(.system(size: 17, weight: .semibold))
                Text("Endringene i plasser-markeringene vil gå tapt.")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral600)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button {
                        showSaveConfirm = false
                    } label: {
                        Text("Fortsett redigering")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.neutral900)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.neutral100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Button {
                        showSaveConfirm = false
                        dismiss()
                    } label: {
                        Text("Forkast")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 40)
        }
    }

    private func cancelTapped() {
        if dirty {
            showSaveConfirm = true
        } else {
            dismiss()
        }
    }

    private func saveTapped() {
        spotMarkers = workingMarkers
        dismiss()
    }
}
