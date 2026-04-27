import SwiftUI

/// Svevende søkebar-pill (Airbnb-stil) som åpner WhereSheet ved tap.
/// Viser primærtekst (sted eller "Hvor vil du dra?") + undertekst med
/// datoer og kjøretøy.
struct SearchPill: View {
    let primary: String
    let secondary: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                VStack(alignment: .leading, spacing: 1) {
                    Text(primary)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    if !secondary.isEmpty {
                        Text(secondary)
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral500)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.neutral200, lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// Sirkulær filter-knapp ved siden av SearchPill. Viser badge med antall
/// aktive filtre.
struct FilterCircleButton: View {
    let activeCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .frame(width: 48, height: 48)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.neutral200, lineWidth: 1))
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 2)

                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 4)
                        .background(Color.primary600)
                        .clipShape(Capsule())
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
