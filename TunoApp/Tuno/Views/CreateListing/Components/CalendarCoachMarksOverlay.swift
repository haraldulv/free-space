import SwiftUI

/// Heldekkende coach-marks-guide som introduserer pris-variasjon-kalenderen.
/// Viser shade med cutout-spotlight rundt utvalgte targets + tooltip-kort.
/// Persisteres via @AppStorage("priceVariationCoachMarksDismissed").
///
/// Plassering: brukes som .overlay på WizardPricingCalendarView. Targets
/// rapporterer sin frame via .coachMarkAnchor(id:) PreferenceKey-pattern.
struct CalendarCoachMarksOverlay: View {
    @Binding var isPresented: Bool
    let anchors: [String: CGRect]
    let containerSize: CGSize

    @AppStorage("priceVariationCoachMarksDismissed") private var dismissed = false
    @State private var stepIndex = 0
    @State private var dontShowAgain = false
    @State private var pulse = false

    private let steps: [CoachMarkStep] = [
        CoachMarkStep(
            anchorId: "band-bar",
            icon: "calendar.badge.clock",
            title: "Båndene viser åpningstidene dine",
            body: "Tap på en bar for å endre prisen for den uken, alle uker, eller spesifikke uker."
        ),
        CoachMarkStep(
            anchorId: "day-cell",
            icon: "hand.tap.fill",
            title: "Tap dager for å markere",
            body: "Velg én eller flere dager for å blokkere dem eller sette en spesiell pris per dag."
        ),
        CoachMarkStep(
            anchorId: "clear-button",
            icon: "arrow.uturn.backward.circle",
            title: "Nullstill med ett tap",
            body: "Bruk denne knappen til å fjerne alle valgte dager med en gang."
        ),
    ]

    private var currentStep: CoachMarkStep { steps[stepIndex] }
    private var targetRect: CGRect {
        anchors[currentStep.anchorId] ?? defaultRect
    }
    private var defaultRect: CGRect {
        // Senterer en placeholder midt på skjermen hvis target ikke finnes ennå.
        CGRect(
            x: containerSize.width / 2 - 80,
            y: containerSize.height / 2 - 30,
            width: 160,
            height: 60
        )
    }

    var body: some View {
        ZStack {
            shadeWithCutout
                .ignoresSafeArea()
                .onTapGesture { advanceStep() }

            // Pulse-ring rundt spotlight
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary500.opacity(0.7), lineWidth: 3)
                .frame(width: targetRect.width + 12, height: targetRect.height + 12)
                .position(x: targetRect.midX, y: targetRect.midY)
                .scaleEffect(pulse ? 1.05 : 1.0)
                .opacity(pulse ? 0.4 : 0.9)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)

            tooltipCard
                .position(tooltipPosition)
                .transition(.scale.combined(with: .opacity))

            // Top-bar med teller + Skip
            VStack {
                HStack {
                    stepCounter
                    Spacer()
                    skipButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                Spacer()
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: stepIndex)
        .onAppear {
            pulse = true
        }
    }

    // MARK: - Components

    private var shadeWithCutout: some View {
        Path { path in
            path.addRect(CGRect(x: -100, y: -100, width: containerSize.width + 200, height: containerSize.height + 200))
            path.addRoundedRect(
                in: targetRect.insetBy(dx: -6, dy: -6),
                cornerSize: CGSize(width: 12, height: 12)
            )
        }
        .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))
    }

    private var stepCounter: some View {
        Text("Steg \(stepIndex + 1) av \(steps.count)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.5))
            .clipShape(Capsule())
    }

    private var skipButton: some View {
        Button {
            isPresented = false
        } label: {
            Text("Hopp over")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var tooltipCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.primary50)
                        .frame(width: 36, height: 36)
                    Image(systemName: currentStep.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary600)
                }
                Text(currentStep.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.neutral900)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            Text(currentStep.body)
                .font(.system(size: 14))
                .foregroundStyle(.neutral600)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // På siste steg: "Ikke vis igjen"-toggle
            if stepIndex == steps.count - 1 {
                Toggle(isOn: $dontShowAgain) {
                    Text("Ikke vis denne guiden igjen")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral700)
                }
                .toggleStyle(SwitchToggleStyle(tint: .primary600))
                .padding(.top, 4)
            }

            HStack(spacing: 8) {
                if stepIndex > 0 {
                    Button {
                        stepIndex -= 1
                    } label: {
                        Text("Tilbake")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.neutral700)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.neutral100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    advanceStep()
                } label: {
                    Text(stepIndex == steps.count - 1 ? "Ferdig" : "Neste")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: tooltipWidth)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary600.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
    }

    // MARK: - Layout helpers

    private var tooltipWidth: CGFloat {
        min(containerSize.width - 32, 340)
    }

    private var tooltipPosition: CGPoint {
        // Plasser tooltip enten over eller under target — det som har mest plass.
        let estimatedTooltipHeight: CGFloat = stepIndex == steps.count - 1 ? 230 : 180
        let spaceAbove = targetRect.minY
        let spaceBelow = containerSize.height - targetRect.maxY
        let placeBelow = spaceBelow >= spaceAbove
        let yMargin: CGFloat = 32

        let centerX = containerSize.width / 2
        if placeBelow {
            let y = min(
                targetRect.maxY + estimatedTooltipHeight / 2 + 16,
                containerSize.height - estimatedTooltipHeight / 2 - yMargin
            )
            return CGPoint(x: centerX, y: y)
        } else {
            let y = max(
                targetRect.minY - estimatedTooltipHeight / 2 - 16,
                estimatedTooltipHeight / 2 + yMargin + 40
            )
            return CGPoint(x: centerX, y: y)
        }
    }

    // MARK: - Navigation

    private func advanceStep() {
        if stepIndex < steps.count - 1 {
            stepIndex += 1
        } else {
            // Siste steg → ferdig
            if dontShowAgain {
                dismissed = true
            }
            isPresented = false
        }
    }
}

struct CoachMarkStep {
    let anchorId: String
    let icon: String
    let title: String
    let body: String
}

// MARK: - Preference key + view-modifier for å rapportere target-frames

struct CoachMarkAnchorsKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Rapporter denne view sin frame i parent-koordinatsystem som coach-mark
    /// target. Brukes av CalendarCoachMarksOverlay til å plassere spotlight.
    func coachMarkAnchor(id: String, in coordinateSpace: String = "wizardCalendar") -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CoachMarkAnchorsKey.self,
                    value: [id: proxy.frame(in: .named(coordinateSpace))]
                )
            }
        )
    }
}

/// Conditional anchor — applies .coachMarkAnchor only when tag != nil.
/// Brukes av WizardPricingCalendarView for å tagge KUN det første treffet.
struct OptionalCoachMarkAnchor: ViewModifier {
    let tag: String?
    func body(content: Content) -> some View {
        if let tag {
            content.coachMarkAnchor(id: tag)
        } else {
            content
        }
    }
}
