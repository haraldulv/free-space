import SwiftUI

struct SpotCountStep: View {
    @ObservedObject var form: ListingFormModel

    private let minSpots = 1
    private let maxSpots = 50

    var body: some View {
        WizardScreen(
            title: "Hvor mange plasser har du?",
            subtitle: "Hver plass kan reserveres separat, og du kan sette ulik pris og kjøretøytype per plass."
        ) {
            VStack(alignment: .leading, spacing: 24) {
                // Stor stepper
                HStack(spacing: 24) {
                    StepperButton(symbol: "minus", enabled: form.spots > minSpots) {
                        if form.spots > minSpots {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                form.spots -= 1
                            }
                        }
                    }

                    Text("\(form.spots)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary600)
                        .frame(minWidth: 100)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: form.spots)

                    StepperButton(symbol: "plus", enabled: form.spots < maxSpots) {
                        if form.spots < maxSpots {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                form.spots += 1
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.primary50)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}

private struct StepperButton: View {
    let symbol: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(enabled ? .primary700 : .neutral300)
                .frame(width: 56, height: 56)
                .background(enabled ? Color.white : Color.neutral100)
                .clipShape(Circle())
                .overlay(Circle().stroke(enabled ? Color.primary200 : Color.neutral200, lineWidth: 1.5))
                .shadow(color: enabled ? .black.opacity(0.06) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
