import SwiftUI

struct FreeTimeToastView: View {
    let title: String
    let message: String
    @Environment(\.colorScheme) private var scheme

    private var palette: AppPalette { AppPalette.current(scheme) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: title.lowercased().contains("over") ? "clock.arrow.circlepath" : "sun.max.fill")
                .font(.system(size: 22))
                .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.text)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.background.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }
}