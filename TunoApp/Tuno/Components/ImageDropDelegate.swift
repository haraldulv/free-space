import SwiftUI

/// Drop-delegate for å re-arrangere bilder via drag & drop. Brukes både i
/// PhotosStep (wizard) og EditListingView.
struct ImageDropDelegate: DropDelegate {
    let item: String
    @Binding var items: [String]
    @Binding var draggedItem: String?

    func dropEntered(info: DropInfo) {
        guard let current = draggedItem,
              current != item,
              let fromIndex = items.firstIndex(of: current),
              let toIndex = items.firstIndex(of: item)
        else { return }
        if items[toIndex] != current {
            withAnimation(.easeInOut(duration: 0.2)) {
                items.move(
                    fromOffsets: IndexSet(integer: fromIndex),
                    toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
                )
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}
