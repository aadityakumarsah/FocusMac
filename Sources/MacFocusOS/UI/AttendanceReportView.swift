import SwiftUI
import MacFocusOSCore

struct AttendanceReportView: View {
    @ObservedObject var manager: AppStateManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var palette: AppPalette { AppPalette.current(scheme) }

    private var today: [AttendanceRecord] {
        manager.attendanceLog.filter { Calendar.current.isDateInToday($0.at) }
    }

    private var distracted: [AttendanceRecord] {
        today.filter { !$0.person || $0.lookingAway || $0.phoneUse }
    }

    private var todayMouseIdle: [MouseIdleEvent] {
        manager.mouseIdleEvents.filter { Calendar.current.isDateInToday($0.start) }
    }

    private var quietPeriods: [(start: Date, end: Date, minutes: Double)] {
        var periods: [(Date, Date, Double)] = []
        var current: AttendanceRecord?
        for record in today {
            if record.person && !record.lookingAway && !record.phoneUse {
                if current == nil { current = record }
            } else {
                if let c = current {
                    let minutes = record.at.timeIntervalSince(c.at) / 60
                    if minutes >= 5 {
                        periods.append((c.at, record.at, minutes))
                    }
                }
                current = nil
            }
        }
        if let c = current {
            let minutes = Date().timeIntervalSince(c.at) / 60
            if minutes >= 5 {
                periods.append((c.at, Date(), minutes))
            }
        }
        return periods
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Attendance Report")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(palette.text)
                    Text("Camera checks, focus vs. distraction, quiet periods, and mouse idleness — all today.")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
            }
            HStack(spacing: 16) {
                StatCell(label: "CHECKS", value: "\(today.count)", tint: palette.text, palette: palette)
                StatCell(label: "DISTRACTED", value: "\(distracted.count)", tint: palette.misaligned, palette: palette)
                StatCell(label: "FOCUSED", value: "\(today.count - distracted.count)", tint: palette.aligned, palette: palette)
                StatCell(label: "MOUSE IDLE", value: "\(todayMouseIdle.count)", tint: .yellow, palette: palette)
                StatCell(label: "IDLE MINUTES", value: String(format: "%.0f", todayMouseIdle.reduce(0) { $0 + $1.duration } / 60), tint: .yellow, palette: palette)
            }
            checksTimeline
            quietCard
            mouseCard
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(minWidth: 900, minHeight: 640)
        .background(palette.background)
    }

    private func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(palette.background.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.border, lineWidth: 1))
    }

    private var checksTimeline: some View {
        let hours = 0..<24
        return VStack(alignment: .leading, spacing: 10) {
            Text("EVERY CAMERA CHECK — GREEN FOCUSED / YELLOW PHONE / ORANGE AWAY / RED MISSING")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(palette.secondary)
            if today.isEmpty {
                Text("No checks recorded yet today. Enable Attendance in Settings to start.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(hours, id: \.self) { hour in
                            let checks = today.filter { Calendar.current.component(.hour, from: $0.at) == hour }
                            let bad = checks.filter { !$0.person || $0.lookingAway || $0.phoneUse }.count
                            VStack(spacing: 4) {
                                if !checks.isEmpty {
                                    Text("\(bad)/\(checks.count)")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundStyle(bad > 0 ? palette.misaligned : palette.secondary)
                                }
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(bad == 0 ? (checks.isEmpty ? palette.border.opacity(0.3) : palette.aligned) : (bad == checks.count ? palette.misaligned : palette.warn))
                                    .frame(width: 14, height: max(5, CGFloat(checks.count) * 3))
                                Text(hour % 12 == 0 ? "12" : "\(hour % 12)")
                                    .font(.system(size: 8))
                                    .foregroundStyle(palette.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground())
    }

    private var quietCard: some View {
        let periods = quietPeriods
        return VStack(alignment: .leading, spacing: 10) {
            Text("QUIET FOCUS PERIODS (5+ MIN WITHOUT DISTRACTION)")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(palette.secondary)
            if periods.isEmpty {
                Text("No quiet periods yet — stay focused for 5+ consecutive minutes and it appears here.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
            } else {
                ForEach(Array(periods.enumerated()), id: \.offset) { _, p in
                    HStack(spacing: 10) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.aligned)
                        Text("\(p.start.formatted(date: .omitted, time: .shortened)) – \(p.end.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.text)
                        Spacer()
                        Text(String(format: "%.0f min", p.minutes))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.aligned)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground())
    }

    private var mouseCard: some View {
        let events = todayMouseIdle
        let maxDur = max(1, events.map(\.duration).max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("MOUSE IDLE — NO INPUT FOR 3+ MIN = NOT WORKING")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(palette.secondary)
            if events.isEmpty {
                Text("No idle periods. Mouse/keyboard in use — nice.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
            } else {
                ForEach(events) { event in
                    HStack(spacing: 10) {
                        Image(systemName: "mouse.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow)
                        Text("\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.text)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.yellow.opacity(0.85))
                                .frame(width: max(8, geo.size.width * event.duration / maxDur))
                        }
                        .frame(height: 10)
                        Text(Format.duration(event.duration))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground())
    }
}