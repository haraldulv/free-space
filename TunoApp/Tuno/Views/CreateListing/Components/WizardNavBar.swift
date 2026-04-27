import SwiftUI
import UIKit

/// Sticky bottom-bar med Tilbake/Neste-knapper. Brukes via `.safeAreaInset(edge: .bottom)`.
/// Knappene har generøs touch-area (h=52) og kan deaktiveres dynamisk.
struct WizardNavBar: View {
    let canGoBack: Bool
    let nextLabel: String
    var nextIcon: String? = "chevron.right"
    var nextEnabled: Bool = true
    var nextLoading: Bool = false
    var skipLabel: String? = nil
    var onBack: () -> Void
    var onNext: () -> Void
    var onSkip: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if canGoBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.neutral700)
                            .frame(width: 52, height: 52)
                            .background(Color.neutral100)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Button(action: onNext) {
                    HStack(spacing: 6) {
                        if nextLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(nextLabel)
                                .font(.system(size: 17, weight: .semibold))
                            if let nextIcon = nextIcon {
                                Image(systemName: nextIcon)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(nextEnabled ? Color.primary600 : Color.primary300)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!nextEnabled || nextLoading)
            }

            if let skipLabel = skipLabel, let onSkip = onSkip {
                Button(action: onSkip) {
                    Text(skipLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral500)
                        .padding(.vertical, 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            Color(UIColor.systemBackground)
                .shadow(color: .black.opacity(0.04), radius: 6, y: -2)
                .ignoresSafeArea()
        )
    }
}
