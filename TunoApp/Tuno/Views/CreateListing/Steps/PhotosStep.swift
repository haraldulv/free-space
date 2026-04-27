import SwiftUI
import PhotosUI

struct PhotosStep: View {
    @ObservedObject var form: ListingFormModel
    @State private var draggedURL: String?
    /// URL'en for bildet som tagges akkurat nå. Når != nil vises action sheet'en.
    /// Vi bruker confirmationDialog framfor SwiftUI Menu fordi Menu er upålitelig
    /// i kombinasjon med drag/drop og overlay'er på samme view.
    @State private var taggingURL: String?

    private var hasMultipleSpots: Bool { form.spotMarkers.count > 1 }

    var body: some View {
        wizardContent
            .confirmationDialog(
                "Tag bilde til plass",
                isPresented: Binding(
                    get: { taggingURL != nil },
                    set: { if !$0 { taggingURL = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let url = taggingURL {
                    Button("Felles bilde") { tagImage(url: url, toSpotIndex: nil) }
                    ForEach(form.spotMarkers.indices, id: \.self) { i in
                        let label = form.spotMarkers[i].label?.trimmingCharacters(in: .whitespaces).isEmpty == false
                            ? form.spotMarkers[i].label!
                            : "Plass \(i + 1)"
                        Button(label) { tagImage(url: url, toSpotIndex: i) }
                    }
                    Button("Avbryt", role: .cancel) {}
                }
            }
    }

    private var wizardContent: some View {
        WizardScreen(
            title: "Vis frem plassene dine",
            subtitle: "Gode bilder selger plassene dine. Last opp minst 3-5 av plassen, omgivelsene og fasilitetene."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                PhotosPicker(
                    selection: $form.selectedPhotos,
                    maxSelectionCount: 10 - form.imageURLs.count,
                    matching: .images
                ) {
                    let isEmpty = form.imageURLs.isEmpty
                    if isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(.primary600)
                            Text("Velg bilder")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary700)
                            Text("JPG eller PNG · maks 10 bilder")
                                .font(.system(size: 12))
                                .foregroundStyle(.neutral500)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .background(Color.primary50)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.primary300, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        )
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.primary600)
                            Text("Legg til flere bilder")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary700)
                            Spacer()
                            Text("\(form.imageURLs.count)/10")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.neutral500)
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.primary50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary300, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        )
                    }
                }
                .onChange(of: form.selectedPhotos) { _, newItems in
                    PhotoUploader.upload(items: newItems, into: form)
                }

                if !form.imageURLs.isEmpty || !form.uploadingPhotos.isEmpty {
                    if hasMultipleSpots {
                        spotTaggingHint
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                        Text("Dra og slipp for å endre rekkefølge. Første bilde er forsidebildet.")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 12) {
                        ForEach(Array(form.imageURLs.enumerated()), id: \.offset) { index, url in
                            imageCellWithTag(index: index, url: url)
                        }

                        ForEach(form.uploadingPhotos) { photo in
                            ZStack {
                                if let uiImage = UIImage(data: photo.data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 130)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Rectangle().fill(Color.neutral100)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 130)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                Rectangle()
                                    .fill(Color.black.opacity(0.35))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 130)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                ProgressView().tint(.white)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Forklaring som dukker opp når listingen har flere plasser. Sentralt
    /// pedagogisk grep — her får utleier vite at hvert bilde kan knyttes til
    /// én plass slik at gjest ser riktige bilder per plass.
    @ViewBuilder
    private var spotTaggingHint: some View {
        let untaggedCount = form.imageURLs.filter { url in
            !form.spotMarkers.contains(where: { ($0.images ?? []).contains(url) })
        }.count
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 16))
                .foregroundStyle(.primary600)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Tag bildene til riktig plass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text(untaggedCount == 0
                     ? "Alle bildene er tagget. Tap merket på et bilde for å endre."
                     : "Trykk på \"Velg plass\"-merket nederst på hvert bilde. Felles bilder kan stå utagget.")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral600)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary200, lineWidth: 1)
        )
    }

    /// Bilde + tag-pill stablet vertikalt for å gjøre tag-affordancen tydelig.
    /// Forsidebildet (index 0) har ingen `.onDrag` — drag-gesten kolliderte
    /// med Menu-tap på pillen og blokkerte tagging. Brukeren kan fortsatt
    /// gjøre et annet bilde til forside ved å dra det opp dit (drop-target).
    @ViewBuilder
    private func imageCellWithTag(index: Int, url: String) -> some View {
        VStack(spacing: 0) {
            if index == 0 {
                imageCell(index: index, url: url)
                    .onDrop(of: [.text], delegate: ImageDropDelegate(
                        item: url,
                        items: $form.imageURLs,
                        draggedItem: $draggedURL
                    ))
            } else {
                imageCell(index: index, url: url)
                    .onDrag {
                        draggedURL = url
                        return NSItemProvider(object: url as NSString)
                    }
                    .onDrop(of: [.text], delegate: ImageDropDelegate(
                        item: url,
                        items: $form.imageURLs,
                        draggedItem: $draggedURL
                    ))
            }
            if hasMultipleSpots {
                spotTagPill(url: url)
            }
        }
    }

    @ViewBuilder
    private func imageCell(index: Int, url: String) -> some View {
        let isCover = index == 0
        let isDragging = draggedURL == url
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle().fill(Color.neutral100)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isCover ? Color.primary600 : Color.clear, lineWidth: 2)
        )
        .opacity(isDragging ? 0.4 : 1)
        .overlay(alignment: .topLeading) {
            if isCover {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 9))
                    Text("Forside").font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.primary600)
                .clipShape(Capsule())
                .padding(6)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                let removed = form.imageURLs.remove(at: index)
                for i in form.spotMarkers.indices {
                    form.spotMarkers[i].images?.removeAll { $0 == removed }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            .padding(6)
        }
    }

    /// Tag-pill rett under bildet, tydelig farget og oversiktlig.
    /// Grønn fyll når plass er valgt, dashed ramme når utagget.
    /// Bruker enkelt Button-tap som setter `taggingURL`. Action sheet'en
    /// håndteres på toppnivå via `.confirmationDialog`.
    @ViewBuilder
    private func spotTagPill(url: String) -> some View {
        let currentIdx = form.spotMarkers.firstIndex { ($0.images ?? []).contains(url) }
        let tagged = currentIdx != nil
        Button {
            taggingURL = url
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tagged ? "mappin.circle.fill" : "mappin")
                    .font(.system(size: 11, weight: .semibold))
                if let idx = currentIdx {
                    let label = form.spotMarkers[idx].label?.trimmingCharacters(in: .whitespaces).isEmpty == false
                        ? form.spotMarkers[idx].label!
                        : "Plass \(idx + 1)"
                    Text(label).lineLimit(1)
                } else {
                    Text("Velg plass")
                }
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tagged ? .white : .primary700)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(tagged ? Color.primary600 : Color.primary50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tagged ? Color.clear : Color.primary300, style: StrokeStyle(lineWidth: 1, dash: tagged ? [] : [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private func tagImage(url: String, toSpotIndex: Int?) {
        var updated = form.spotMarkers
        for i in updated.indices {
            var imgs = updated[i].images ?? []
            imgs.removeAll { $0 == url }
            updated[i].images = imgs.isEmpty ? nil : imgs
        }
        if let idx = toSpotIndex, updated.indices.contains(idx) {
            var imgs = updated[idx].images ?? []
            imgs.append(url)
            updated[idx].images = imgs
        }
        form.spotMarkers = updated
    }
}

/// Felles uploader — brukes av PhotosStep + EditListingView for å unngå
/// å duplisere Supabase-storage-kall.
enum PhotoUploader {
    @MainActor
    static func upload(items: [PhotosPickerItem], into form: ListingFormModel) {
        guard !items.isEmpty else { return }
        form.selectedPhotos = []

        Task { @MainActor in
            guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

            var pending: [(UploadingPhoto, Data)] = []
            for item in items {
                guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
                let compressed = ImageCompression.compressForUpload(raw) ?? raw
                let photo = UploadingPhoto(data: compressed)
                pending.append((photo, compressed))
                form.uploadingPhotos.append(photo)
            }

            await withTaskGroup(of: (UUID, String?).self) { group in
                for (photo, data) in pending {
                    group.addTask {
                        let fileName = "\(userId)/\(UUID().uuidString.lowercased()).jpg"
                        do {
                            try await supabase.storage
                                .from("listing-images")
                                .upload(fileName, data: data, options: .init(contentType: "image/jpeg"))
                            let publicURL = try supabase.storage
                                .from("listing-images")
                                .getPublicURL(path: fileName)
                            return (photo.id, publicURL.absoluteString)
                        } catch {
                            print("Image upload failed: \(error)")
                            return (photo.id, nil)
                        }
                    }
                }

                for await (photoId, url) in group {
                    form.uploadingPhotos.removeAll { $0.id == photoId }
                    if let url = url {
                        form.imageURLs.append(url)
                    }
                }
            }
        }
    }
}
