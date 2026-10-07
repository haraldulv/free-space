import SwiftUI

/// Backwards-compat shim. Den gamle tab-baserte EditListingView ble erstattet
/// med `EditListingHub` (TU-61, 2026-05-13). ProfileView pusher fortsatt
/// `EditListingRootView` — denne wrapperen lar det fungere uten å endre
/// kallsiden.
struct EditListingRootView: View {
    let listing: Listing
    var onSaved: ((Listing) -> Void)? = nil
    var onDeleted: (() -> Void)? = nil

    var body: some View {
        // Parkering rutes til den nye, enkle editoren (Asker-pivoten).
        // EditListingHub forbeholdes camping: dens buildUpdateInput ville
        // skrevet price=0 for parkering-annonser uten per-plass-pris.
        if listing.category == .parking {
            EditParkingView(listing: listing, onSaved: onSaved, onDeleted: onDeleted)
        } else {
            EditListingHub(listing: listing, onSaved: onSaved, onDeleted: onDeleted)
        }
    }
}
