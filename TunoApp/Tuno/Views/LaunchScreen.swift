import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color.primary600
                .ignoresSafeArea()

            Text("tuno")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
