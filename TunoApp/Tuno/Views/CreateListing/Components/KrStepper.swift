import SwiftUI

/// Numerisk +/- input som matcher BigPriceInput-stilen i wizarden.
/// Tap på tallet for å skrive inn manuelt; tap +/- for å justere i `step`-trinn.
///
/// Brukes for Lengre opphold-priser (step=50 kr) og min/maks dager (step=1).
struct KrStepper: View {
    @Binding var value: Int?
    /// Trinn-størrelse for +/- knappene.
    var step: Int = 1
    /// Minste tillatte verdi. nil = ingen.
    var minValue: Int? = nil
    /// Største tillatte verdi. nil = ingen.
    var maxValue: Int? = nil
    /// Tekst etter tallet ("kr", "dag", "dager"...).
    var unitLabel: String = "kr"
    /// Hva som vises når value er nil eller 0 og feltet ikke har fokus.
    var placeholder: String = "0"
    /// Kalles når TextField-fokus endres. Parent kan bruke dette til å trigge
    /// scroll så feltet ikke gjemmes bak tastaturet.
    var onFocusChange: ((Bool) -> Void)? = nil

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            stepperButton(symbol: "minus", action: decrement, disabled: !canDecrement)
            valueField
            stepperButton(symbol: "plus", action: increment, disabled: !canIncrement)
        }
    }

    // MARK: - Subviews

    private var valueField: some View {
        HStack(spacing: 4) {
            textInput
            if !unitLabel.isEmpty {
                Text(unitLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isFocused ? Color.primary600 : Color.neutral200, lineWidth: isFocused ? 2 : 1))
    }

    private var textInput: some View {
        let field = TextField(placeholder, text: $text)
            .focused($isFocused)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color.neutral900)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(minWidth: 50)
        return field
            .onChange(of: text) { _, newValue in
                let digits = newValue.filter { $0.isNumber }
                if digits.isEmpty {
                    value = nil
                    return
                }
                if let n = Int(digits) {
                    value = clamp(n)
                }
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    text = ""
                } else {
                    text = displayText
                }
                onFocusChange?(focused)
            }
            .onAppear { text = displayText }
            .onChange(of: value) { _, _ in
                if !isFocused { text = displayText }
            }
    }

    @ViewBuilder
    private func stepperButton(symbol: String, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(disabled ? Color.neutral300 : Color.primary700)
                .frame(width: 36, height: 36)
                .background(disabled ? Color.neutral50 : Color.primary50)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Logic

    private var displayText: String {
        guard let v = value, v > 0 else { return "" }
        return "\(v)"
    }

    private func clamp(_ n: Int) -> Int? {
        var clamped = n
        if let m = minValue { clamped = max(m, clamped) }
        if let m = maxValue { clamped = min(m, clamped) }
        return clamped
    }

    private var canDecrement: Bool {
        let current = value ?? 0
        if let m = minValue, current <= m { return false }
        return current > 0
    }

    private var canIncrement: Bool {
        let current = value ?? 0
        if let m = maxValue, current >= m { return false }
        return true
    }

    private func decrement() {
        let current = value ?? minValue ?? 0
        let next = current - step
        if let m = minValue, next < m {
            value = m
        } else if next < 0 {
            value = 0
        } else {
            value = next
        }
    }

    private func increment() {
        let current = value ?? minValue ?? 0
        let next = current + step
        if let m = maxValue, next > m {
            value = m
        } else {
            value = next
        }
    }
}
