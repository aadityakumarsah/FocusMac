import SwiftUI
import MacFocusOSCore

struct AttendanceLivePanelView: View {
    @ObservedObject var manager: AppStateManager
    var onClose: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var palette: AppPalette { AppPalette.current(scheme) }

    private struct VerdictStyle {
        let tint: Color
        let icon: String
        let title: String
        let subtitle: String
    }

    private var verdictStyle: VerdictStyle {
        guard let v = manager.liveVerdict else {
            return VerdictStyle(tint: palette.warn, icon: "video", title: "Starting camera…", subtitle: "Warming up the live feed")
        }
        if !v.person {
            return VerdictStyle(tint: palette.misaligned, icon: "person.crop.circle.badge.xmark", title: "You left the desk", subtitle: "No person in frame")
        }
        if v.lookingAway {
            return VerdictStyle(tint: .orange, icon: "eye.slash", title: "Looking away", subtitle: "Eyes not on the screen")
        }
        if v.phoneUse {
            return VerdictStyle(tint: .yellow, icon: "iphone.gen3", title: "Phone detected!", subtitle: "Put the phone down and focus")
        }
        var sim = ""
        if let s = v.similarity {
            sim = String(format: " · face match %.0f%%", s * 100)
        }
        return VerdictStyle(tint: palette.aligned, icon: "checkmark.seal.fill", title: "Attentive", subtitle: "\(v.pose)\(sim)")
    }

    private var todayStats: (checks: Int, distracted: Int, focused: Int) {
        let today = manager.attendanceLog.filter { Calendar.current.isDateInToday($0.at) }
        let distracted = today.filter { !$0.person || $0.lookingAway || $0.phoneUse }.count
        return (today.count, distracted, today.count - distracted)
    }

    var body: some View {
        let stats = todayStats
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(palette.misaligned)
                    .frame(width: 9, height: 9)
                    .shadow(color: palette.misaligned, radius: 5)
                Text("ATTENDANCE LIVE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(palette.text)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondary)
                }
                .buttonStyle(.plain)
            }
            if let image = manager.liveVideoImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320, maxHeight: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(verdictStyle.tint.opacity(0.8), lineWidth: 2.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.background.opacity(0.5))
                    .frame(width: 320, height: 210)
                    .overlay(ProgressView().controlSize(.small))
            }
            HStack(spacing: 8) {
                Image(systemName: verdictStyle.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(verdictStyle.tint)
                Text(verdictStyle.title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(verdictStyle.tint)
                Spacer()
                if manager.cameraOverlay.checking {
                    ProgressView().controlSize(.mini)
                }
            }
            Text(verdictStyle.subtitle)
                .font(.system(size: 10.5))
                .foregroundStyle(palette.text)
            Divider().overlay(palette.border)
            HStack(spacing: 14) {
                stat("CHECKS", "\(stats.checks)", palette.text)
                stat("DISTRACTED", "\(stats.distracted)", stats.distracted > 0 ? palette.misaligned : palette.text)
                stat("FOCUSED", "\(stats.focused)", palette.aligned)
                stat("MOUSE IDLE", manager.mouseIdleCount > 0 ? "\(manager.mouseIdleCount)" : "0", manager.mouseIdleCount > 0 ? .yellow : palette.text)
            }
            Text("Mouse idle today: \(String(format: "%.0f", manager.mouseIdleMinutes)) min · no mouse for 3+ min = logged")
                .font(.system(size: 9.5))
                .foregroundStyle(palette.secondary)
        }
        .padding(14)
        .frame(width: 348)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.background.opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(verdictStyle.tint.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
    }

    private func stat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(palette.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}