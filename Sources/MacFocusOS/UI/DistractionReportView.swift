import SwiftUI
import MacFocusOSCore

struct DistractionReportView: View {
    @ObservedObject var manager: AppStateManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var palette: AppPalette { AppPalette.current(scheme) }

    var body: some View {
        let summary = manager.distractionSummary
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Distractions")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(palette.text)
                    Text("Every time you opened something off-plan, counted and timed.")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
            }
            HStack(spacing: 16) {
                StatCell(label: "TIMES OPENED", value: "\(summary.count)", tint: palette.warn, palette: palette)
                StatCell(label: "TOTAL MINUTES", value: String(format: "%.0f m", summary.totalMinutes), tint: palette.misaligned, palette: palette)
                StatCell(
                    label: "LONGEST",
                    value: Format.duration(summary.events.map(\.duration).max() ?? 0),
                    tint: palette.text,
                    palette: palette
                )
                StatCell(
                    label: "LAST OPEN",
                    value: summary.events.last.map { $0.startedAt.formatted(date: .omitted, time: .shortened) } ?? "—",
                    tint: palette.text,
                    palette: palette
                )
            }
            hourGraph(summary)
            siteBreakdown(summary)
            eventList(summary)
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(minWidth: 900, minHeight: 640)
        .background(palette.background)
    }

    private func hourGraph(_ summary: FocusSessionManager.DistractionSummary) -> some View {
        let maxMinutes = max(1, summary.byHour.map(\.minutes).max() ?? 0)
        return VStack(alignment: .leading, spacing: 10) {
            Text("WHEN YOU DRIFTED — BY HOUR")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(palette.secondary)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<24, id: \.self) { hour in
                    let bucket = summary.byHour.first { $0.hour == hour }
                    let minutes = bucket?.minutes ?? 0
                    VStack(spacing: 4) {
                        if let bucket, minutes >= 0.5 {
                            Text("\(bucket.count)")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(palette.warn)
                        }
                        RoundedRectangle(cornerRadius: 3)
                            .fill(minutes > 0 ? palette.warn : palette.border.opacity(0.4))
                            .frame(height: minutes > 0 ? max(6, 90 * minutes / maxMinutes) : 3)
                        Text(hour % 12 == 0 ? "12" : "\(hour % 12)")
                            .font(.system(size: 8))
                            .foregroundStyle(palette.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 130, alignment: .bottom)
        }
        .padding(16)
        .background(cardBackground())
    }

    private func siteBreakdown(_ summary: FocusSessionManager.DistractionSummary) -> some View {
        let maxMinutes = max(1, summary.bySite.map(\.minutes).max() ?? 0)
        return VStack(alignment: .leading, spacing: 10) {
            Text("WHAT YOU OPENED")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(palette.secondary)
            if summary.bySite.isEmpty {
                Text("Nothing opened today. Clean streak.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
            } else {
                ForEach(summary.bySite, id: \.label) { site in
                    HStack(spacing: 10) {
                        Text(site.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.text)
                            .frame(width: 140, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(palette.warn.opacity(0.85))
                                .frame(width: max(8, geo.size.width * site.minutes / maxMinutes))
                        }
                        .frame(height: 12)
                        Text("\(site.count)x")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.warn)
                            .frame(width: 34, alignment: .trailing)
                        Text(String(format: "%.0f m", site.minutes))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground())
    }

    private func eventList(_ summary: FocusSessionManager.DistractionSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EVERY OPEN — TIMELINE")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(palette.secondary)
            if summary.events.isEmpty {
                Text("No distractions recorded.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(summary.events) { event in
                            HStack(spacing: 10) {
                                Text(event.startedAt.formatted(date: .omitted, time: .standard))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(palette.secondary)
                                    .frame(width: 90, alignment: .leading)
                                Text("→")
                                    .font(.system(size: 9))
                                    .foregroundStyle(palette.secondary)
                                Text(event.endedAt?.formatted(date: .omitted, time: .standard) ?? "now")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(palette.secondary)
                                    .frame(width: 90, alignment: .leading)
                                Text(event.site ?? event.appName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(palette.warn)
                                Text(event.title ?? "")
                                    .font(.system(size: 10))
                                    .foregroundStyle(palette.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text(Format.duration(event.duration))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(palette.text)
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(16)
        .background(cardBackground())
    }

    private func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(palette.background.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.border, lineWidth: 1))
    }
}