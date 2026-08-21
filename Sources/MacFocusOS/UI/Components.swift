import SwiftUI
import MacFocusOSCore

struct ActivityDot: View {
    let phase: DistractionPhase
    let paused: Bool
    @State private var pulsing = false

    init(phase: DistractionPhase, paused: Bool = false) {
        self.phase = phase
        self.paused = paused
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .scaleEffect(pulsing ? 1.25 : 1)
            .opacity(pulsing ? 0.6 : 1)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }

    private var color: Color {
        if paused { return Color.gray.opacity(0.7) }
        switch phase {
        case .focused: return Color(hex: 0x4FC08A)
        case .warning: return Color(hex: 0xE3B341)
        case .blocked: return Color(hex: 0xE56B6B)
        }
    }
}

struct FocusRingView: View {
    let value: Int
    let tint: Color
    var size: CGFloat = 46

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(scheme == .dark ? 0.25 : 0.08), lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(CGFloat(max(value, 0)) / 100, 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: value)
            Text("\(value)")
                .font(.system(size: size * 0.27, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

struct FocusActionStyle: ButtonStyle {
    let filled: Bool
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(filled ? Color.white : tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(filled ? tint : tint.opacity(0.14)))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct StatCell: View {
    let label: String
    let value: String
    let tint: Color
    let palette: AppPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(palette.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.background.opacity(0.45)))
    }
}

struct ActivityRowView: View {
    let activity: Activity
    let palette: AppPalette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(activity.appName)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.text)
                if let title = activity.windowTitle, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 10))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(Format.duration(activity.duration))
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.secondary)
        }
        .padding(.vertical, 3)
    }

    private var icon: String {
        switch activity.alignment {
        case .aligned: return "checkmark.circle.fill"
        case .misaligned: return "exclamationmark.circle.fill"
        default: return "minus.circle.fill"
        }
    }

    private var tint: Color {
        switch activity.alignment {
        case .aligned: return palette.aligned
        case .misaligned: return palette.misaligned
        default: return palette.secondary
        }
    }
}

struct ChipView: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}
