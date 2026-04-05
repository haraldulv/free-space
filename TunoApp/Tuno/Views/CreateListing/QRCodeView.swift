import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeModal: View {
    let listing: Listing
    @Environment(\.dismiss) private var dismiss
    @State private var savingSpot: Int?
    @State private var savedMessage: String?

    private let siteURL = AppConfig.siteURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Info
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.primary600)
                        Text("Skriv ut og heng opp QR-kodene ved hver plass. Gjester scanner koden for å komme direkte til annonsen.")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral600)
                    }
                    .padding()
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // QR codes per spot
                    let spotCount = listing.spots ?? 1
                    ForEach(1...spotCount, id: \.self) { spot in
                        let url = "\(siteURL)/listings/\(listing.id)?spot=\(spot)"

                        VStack(spacing: 12) {
                            HStack {
                                Text("Plass \(spot)")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                            }

                            // QR code image
                            if let qrImage = generateQRCode(from: url) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .padding(16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200))
                            }

                            Text(url)
                                .font(.system(size: 11))
                                .foregroundStyle(.neutral400)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Button {
                                saveQRCode(spot: spot, url: url)
                            } label: {
                                HStack(spacing: 6) {
                                    if savingSpot == spot {
                                        ProgressView().tint(.primary600)
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                        Text("Last ned PNG")
                                    }
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary600)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.primary50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200))
                    }

                    // Download all button
                    if spotCount > 1 {
                        Button {
                            saveAllQRCodes(spotCount: spotCount)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.to.line")
                                Text("Last ned alle (\(spotCount))")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary600)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if let msg = savedMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(msg)
                                .font(.system(size: 14))
                                .foregroundStyle(.neutral600)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("QR-koder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Lukk") { dismiss() }
                }
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }
        let scale = 400.0 / ciImage.extent.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func saveQRCode(spot: Int, url: String) {
        guard let image = generateQRCode(from: url) else { return }
        savingSpot = spot
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            savingSpot = nil
            savedMessage = "Plass \(spot) lagret i Bilder"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                savedMessage = nil
            }
        }
    }

    private func saveAllQRCodes(spotCount: Int) {
        for spot in 1...spotCount {
            let url = "\(siteURL)/listings/\(listing.id)?spot=\(spot)"
            if let image = generateQRCode(from: url) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }
        savedMessage = "Alle \(spotCount) QR-koder lagret i Bilder"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            savedMessage = nil
        }
    }
}
