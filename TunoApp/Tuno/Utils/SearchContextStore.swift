import Foundation
import SwiftUI

/// Holder valgte datoer og parkering-tidspunkter fra kartsøket så BookingView
/// kan pre-fylle dem når brukeren tapper en annonse fra søk. Brukeren slipper
/// å skrive inn samme info to ganger.
///
/// Lagres bare i minne — ved app-restart eller manuell clear() er state borte.
@MainActor
final class SearchContextStore: ObservableObject {
    static let shared = SearchContextStore()

    @Published var checkIn: Date?
    @Published var checkOut: Date?
    /// Totalminutter siden midnatt (0..1440, 30-min step). NULL = uspesifisert.
    @Published var startMinutes: Int?
    @Published var endMinutes: Int?

    private init() {}

    func clear() {
        checkIn = nil
        checkOut = nil
        startMinutes = nil
        endMinutes = nil
    }
}
