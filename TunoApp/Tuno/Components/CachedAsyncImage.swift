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
        failed = false
        guard let url else {
            await MainActor.run { self.uiImage = nil }
            return
        }

        // Synkron cache-hit: bytt uiImage direkte uten å nullstille først.
        // Tidligere satte vi uiImage = nil i starten — det fyrte placeholder ett
        // frame før cache-treff og forårsaket synlig flicker når man kom tilbake
        // til Home/Messages.
        let request = URLRequest(url: url)
        if let cached = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cached.data)
        {
            await MainActor.run { self.uiImage = image }
            return
        }

        // Cache-miss: vis placeholder mens nettverkshenting kjører.
        await MainActor.run { self.uiImage = nil }

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

/// Hjelpenamespace for prefetching av bilder inn i `URLCache.shared`. Kall fra
/// `.task` på Home/Messages før kortene rendres så cellene treffer cache med
/// en gang og ikke flickrer.
enum ImagePrefetcher {
    static func prefetch(urls: [URL]) {
        for url in urls {
            let request = URLRequest(url: url)
            if URLCache.shared.cachedResponse(for: request) != nil { continue }
            Task.detached(priority: .utility) {
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    URLCache.shared.storeCachedResponse(
                        CachedURLResponse(response: response, data: data),
                        for: request,
                    )
                } catch {
                    // Stille — neste visning vil prøve igjen via CachedAsyncImage.
                }
            }
        }
    }
}
