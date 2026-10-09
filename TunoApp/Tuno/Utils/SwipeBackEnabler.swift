import SwiftUI
import UIKit

/// Gjenaktiverer UINavigationControllers interaktive tilbake-sveip for
/// stacker der sidene skjuler system-navbaren (kartflaten og parkering-
/// annonsesiden bruker egne topbarer). UIKit kobler ut kant-sveipen når
/// navigationBar er skjult; vi tar over som gesture-delegate og tillater
/// den så lenge det faktisk finnes en side å gå tilbake til.
///
/// Legges som usynlig .background på rot-innholdet i NavigationStacken —
/// controlleren lever da like lenge som stacken, så delegaten aldri
/// dingler (dinglende delegate + sveip på rot er den klassiske
/// frys-buggen med dette trikset).
struct SwipeBackEnabler: UIViewControllerRepresentable {
    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }

    func makeUIViewController(context: Context) -> UIViewController { Controller() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
