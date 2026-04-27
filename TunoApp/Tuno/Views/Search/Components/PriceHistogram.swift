import SwiftUI

/// Pris-histogram med dual-handle range slider over (Airbnb-stil).
/// Beregner buckets klient-side fra priser-array. Designet for å passe
/// inn i FiltersSheet pris-seksjonen.
struct PriceHistogram: View {
    let prices: [Int]
    let bounds: ClosedRange<Int>
    @Binding var lowerBound: Int
    @Binding var upperBound: Int

    private let bucketCount = 32
    private let barColor = Color.primary500
    private let barInactiveColor = Color.neutral200

    var body: some View {
        VStack(spacing: 12) {
            histogram
            DualHandleSlider(
                bounds: bounds,
                lower: $lowerBound,
                upper: $upperBound
            )
            .padding(.horizontal, 12)
        }
    }

    private var histogram: some View {
        let buckets = computeBuckets()
        let maxCount = max(buckets.max() ?? 1, 1)
        return GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<buckets.count, id: \.self) { i in
                    let bucketStart = bounds.lowerBound + i * bucketWidth
                    let bucketEnd = bucketStart + bucketWidth
                    let inRange = bucketEnd > lowerBound && bucketStart < upperBound
                    let height = CGFloat(buckets[i]) / CGFloat(maxCount) * geo.size.height
                    Capsule()
                        .fill(inRange ? barColor : barInactiveColor)
                        .frame(height: max(height, 2))
                }
            }
        }
        .frame(height: 80)
        .padding(.horizontal, 12)
    }

    private var bucketWidth: Int {
        max((bounds.upperBound - bounds.lowerBound) / bucketCount, 1)
    }

    private func computeBuckets() -> [Int] {
        var buckets = Array(repeating: 0, count: bucketCount)
        for price in prices {
            guard price >= bounds.lowerBound, price <= bounds.upperBound else { continue }
            let idx = min((price - bounds.lowerBound) / bucketWidth, bucketCount - 1)
            buckets[idx] += 1
        }
        return buckets
    }
}

/// To-håndtak slider (min/max) for pris-range. Egen implementasjon siden
/// SwiftUI sin Slider ikke støtter range natively.
private struct DualHandleSlider: View {
    let bounds: ClosedRange<Int>
    @Binding var lower: Int
    @Binding var upper: Int

    var body: some View {
        GeometryReader { geo in
            let trackHeight: CGFloat = 4
            let handleSize: CGFloat = 24
            let trackWidth = geo.size.width
            let totalRange = CGFloat(bounds.upperBound - bounds.lowerBound)
            let lowerX = trackWidth * CGFloat(lower - bounds.lowerBound) / totalRange
            let upperX = trackWidth * CGFloat(upper - bounds.lowerBound) / totalRange

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.neutral200)
                    .frame(height: trackHeight)
                Capsule()
                    .fill(Color.neutral900)
                    .frame(width: max(upperX - lowerX, 0), height: trackHeight)
                    .offset(x: lowerX)

                handle
                    .position(x: lowerX, y: geo.size.height / 2)
                    .gesture(dragGesture(isLower: true, trackWidth: trackWidth, totalRange: totalRange))
                handle
                    .position(x: upperX, y: geo.size.height / 2)
                    .gesture(dragGesture(isLower: false, trackWidth: trackWidth, totalRange: totalRange))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: 28)
    }

    private var handle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 26, height: 26)
            .overlay(Circle().stroke(Color.neutral200, lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }

    private func dragGesture(isLower: Bool, trackWidth: CGFloat, totalRange: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let x = max(0, min(value.location.x, trackWidth))
                let raw = bounds.lowerBound + Int(round(CGFloat(totalRange) * x / trackWidth))
                let snapped = (raw / 50) * 50
                if isLower {
                    lower = max(bounds.lowerBound, min(snapped, upper - 50))
                } else {
                    upper = min(bounds.upperBound, max(snapped, lower + 50))
                }
            }
    }
}
