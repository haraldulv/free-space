import SwiftUI

/// Profil-oppsummering-kort øverst i Profil-tab. Viser avatar, navn, by, og
/// tre statistikker (Turer / Anmeldelser / År på Tuno).
struct ProfileSummaryCard: View {
    let name: String
    let avatarUrl: String?
    let location: String?
    let trips: Int
    let reviews: Int
    let joinedYear: Int?
    let isVerified: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let avatarUrl, let url = URL(string: avatarUrl) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(Color.primary100).overlay(
                                    Text(String(name.prefix(1)).uppercased())
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(.primary600)
                                )
                            }
                        } else {
                            Circle().fill(Color.primary100).overlay(
                                Text(String(name.prefix(1)).uppercased())
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.primary600)
                            )
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())

                    if isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, Color.primary600)
                            .background(Circle().fill(Color.white).frame(width: 24, height: 24))
                    }
                }

                VStack(spacing: 2) {
                    Text(name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)
                    if let location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                statRow(value: "\(trips)", label: "Turer")
                Divider().padding(.vertical, 2)
                statRow(value: "\(reviews)", label: reviews == 1 ? "Anmeldelse" : "Anmeldelser")
                Divider().padding(.vertical, 2)
                statRow(value: yearsOnTuno, label: "på Tuno")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20).stroke(Color.neutral200, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statRow(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.neutral900)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.neutral600)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private var yearsOnTuno: String {
        guard let joinedYear else { return "—" }
        let current = Calendar.current.component(.year, from: Date())
        let years = max(0, current - joinedYear)
        if years == 0 { return "I år" }
        return "\(years) år"
    }
}
