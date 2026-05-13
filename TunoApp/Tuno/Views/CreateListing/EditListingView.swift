import SwiftUI

/// Backwards-compat shim. Den gamle tab-baserte EditListingView ble erstattet
/// med `EditListingHub` (TU-61, 2026-05-13). ProfileView pusher fortsatt
/// `EditListingRootView` — denne wrapperen lar det fungere uten å endre
/// kallsiden.
struct EditListingRootView: View {
    let listing: Listing
    var onSaved: ((Listing) -> Void)? = nil

    var body: some View {
        EditListingHub(listing: listing, onSaved: onSaved)
    }
}
