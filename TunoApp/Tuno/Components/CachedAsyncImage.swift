import SwiftUI
import UIKit

/// Henter og cacher bilder via `URLCache.shared` (disk + minne). Bildene
/// overlever app-launch og re-scroll, i motsetning til SwiftUI sin `AsyncImage`
/// som er minne-only og re-henter ved hver ny instans.
///
/// URLCache.shared konfigureres i `TunoApp.init()` til 50 MB minne + 500 MB disk.
///
/// Bruk som drop-in erstatning for AsyncImage i hot spots (listing-kort,
/// avatar-bilder, conversation-bilder):
///
/// ```swift
/// CachedAsyncImage(url: URL(string: listing.images.first ?? "")) { image in
///     image.resizable().aspectRatio(contentMode: .fill)
/// } placeholder: {
///     Rectangle().fill(Color.neutral100)
/// }
/// ```
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var failed = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        uiImage = nil
        failed = false
        guard let url else { return }

        // Sjekk cache først (treffer både minne + disk)
        let request = URLRequest(url: url)
        if let cached = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cached.data)
        {
            await MainActor.run { self.uiImage = image }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let image = UIImage(data: data) else {
                await MainActor.run { self.failed = true }
                return
            }
            // Lagre eksplisitt — URLSession sin auto-cache er konservativ for ukjente
            // content-types, så vi sikrer oss ved å lagre her.
            URLCache.shared.storeCachedResponse(
                CachedURLResponse(response: response, data: data),
                for: request,
            )
            await MainActor.run { self.uiImage = image }
        } catch {
            await MainActor.run { self.failed = true }
        }
    }
}
