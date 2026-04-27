import SwiftUI
import Lottie

/// SwiftUI-wrapper rundt LottieAnimationView. Hvis JSON-fil mangler i bundle
/// (f.eks. ennå ikke lastet ned fra lottiefiles.com), faller vi tilbake til
/// en SF Symbol med matchende SwiftUI-puls/skala-animasjon — appen krasjer aldri.
struct LottieView: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .loop
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var speed: CGFloat = 1.0

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear

        let animationView = LottieAnimationView()
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.animationSpeed = speed
        animationView.translatesAutoresizingMaskIntoConstraints = false

        if let animation = LottieAnimation.named(name) {
            animationView.animation = animation
            animationView.play()
        }

        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Bruk denne i steder der vi vil ha en Lottie-animasjon men har en
/// SwiftUI-fallback klar i tilfelle JSON-filen ikke er bunket enda.
struct LottieOrFallback<Fallback: View>: View {
    let name: String
    var loopMode: LottieLoopMode = .loop
    var speed: CGFloat = 1.0
    @ViewBuilder var fallback: () -> Fallback

    var body: some View {
        if LottieAnimation.named(name) != nil {
            LottieView(name: name, loopMode: loopMode, speed: speed)
        } else {
            fallback()
        }
    }
}
