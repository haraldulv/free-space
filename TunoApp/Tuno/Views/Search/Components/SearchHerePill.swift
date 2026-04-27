import SwiftUI

/// Svevende "Søk i dette området"-pille som vises sentrert øverst når
/// brukeren har pannet kartet betydelig siden siste søk. Auto-søket
/// fortsetter (debounced), pillen lar bruker re-trigge umiddelbart.
struct SearchHerePill: View {
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(isLoading ? "Søker..." : "Søk i dette området")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.neutral900)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

/// Sirkulær FAB-knapp for "vis liste / vis kart"-toggle nederst på
/// hovedskjermen. Skifter ikon og label basert på nåværende modus.
struct ListMapToggleFAB: View {
    let showingMap: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: showingMap ? "list.bullet" : "map.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(showingMap ? "Vis liste" : "Vis kart")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.neutral900)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}
