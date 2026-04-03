import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color(red: 70/255, green: 193/255, blue: 133/255)
                .ignoresSafeArea()

            Image("SplashLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 220)
        }
    }
}
