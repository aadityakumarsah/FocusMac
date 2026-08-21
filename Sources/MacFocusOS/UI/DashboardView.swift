import SwiftUI
import MacFocusOSCore

struct DashboardView: View {
    @ObservedObject var manager: AppStateManager
    @Environment(\.colorScheme) private var scheme
    @State private var showScheduleEditor = false
    @State private var editingScheduleBlock: ScheduleBlock?
    @State private var scheduleTitle = ""
    @State private var scheduleStart = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var scheduleEnd = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var scheduleDays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var scheduleIsStudy = true
    @State private var quickAddText = ""
    @State private var quickAddError = false
    @State private var showDistractionReport = false
    @State private var showAttendanceReport = false

    private var palette: AppPalette { AppPalette.current(scheme) }
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    @State private var now = Date()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if manager.schedule.isEmpty {
                    scheduleFirstBanner
                }
                nowCard
                scheduleCard
                sessionCard
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    focusCard
                    guardrailsCard
                    attendanceCard
                }
                lifelineCard
                timelineCard
                distractionReportCard
                footer
            }
            .padding(24)
        }
        .onReceive(clock) { date in
            now = date
        }
        .frame(minWidth: 640, minHeight: 560)
        .background(palette.background)
        .sheet(isPresented: $showDistractionReport) {
            DistractionReportView(manager: manager)
        }
        .sheet(isPresented: $showAttendanceReport) {
            AttendanceReportView(manager: manager)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FocusMac")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.text)
                Text("An AI that guards your attention around your goals and schedule.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.secondary)
            }
            Spacer()
            sessionControl
        }
    }

    private var sessionControl: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(palette.aligned)
                .frame(width: 7, height: 7)
            Text("FOCUS MODE — ALWAYS ON")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(palette.aligned)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(palette.aligned.opacity(0.1)))
        .overlay(Capsule().stroke(palette.aligned.opacity(0.3), lineWidth: 1))
        .help("Focus mode runs whenever the app runs — your schedule decides when it enforces.")
    }

    private var scheduleFirstBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add your schedule to activate focus mode")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text("The app analyses your whole weekly schedule and automatically enforces focus during work/study blocks — and stays out of the way during free time, breaks and meals.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.accent.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.accent.opacity(0.3), lineWidth: 1))
    }

    private var nowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NOW")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.8)
                        .foregroundStyle(palette.secondary)
                    Text(manager.currentActivity?.windowTitle ?? manager.currentActivity?.appName ?? "Idle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                }
                Spacer()
                if let next = nextScheduledBlock {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 10))
                            .foregroundStyle(palette.warn)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("NEXT")
                                .font(.system(size: 8, weight: .bold))
                                .kerning(0.6)
                                .foregroundStyle(palette.secondary)
                            Text("\(next.title) · \(next.startLabel)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(palette.text)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(palette.warn.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.warn.opacity(0.3), lineWidth: 1))
                }
                HStack(spacing: 8) {
                    StatCell(label: "SESSION", value: Format.duration(manager.sessionDuration), tint: palette.text, palette: palette)
                    StatCell(label: "TODAY XP", value: Format.xp(manager.xpToday), tint: palette.warn, palette: palette)
                    StatCell(label: "SCORE", value: "\(manager.score)", tint: palette.aligned, palette: palette)
                    if let block = manager.currentScheduleBlock {
                        StatCell(
                            label: "\(block.title) ENDS",
                            value: blockRemaining(block),
                            tint: palette.warn,
                            palette: palette
                        )
                    }
                }
            }
            if !manager.screenPermissionGranted {
                permissionBanner
            }
            liveStatusStrip
        }
        .padding(16)
        .background(cardBackground())
    }

    private func blockRemaining(_ block: ScheduleBlock) -> String {
        Format.duration(block.remainingDuration())
    }

    private var permissionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.badge.record")
                .font(.system(size: 11))
                .foregroundStyle(palette.misaligned)
            Text("Screen Recording permission is OFF — window titles can't be read, so nothing can be detected. Allow FocusMac in System Settings → Privacy & Security → Screen Recording, then click here to recheck.")
                .font(.system(size: 10))
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Fix") {
                PermissionManager.resetScreenPermission()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    PermissionManager.requestScreen()
                    PermissionManager.openPrivacyPane("Privacy_ScreenCapture")
                }
            }
            .buttonStyle(FocusActionStyle(filled: true, tint: palette.misaligned))
            Button("Recheck") {
                manager.refreshPermission()
            }
            .buttonStyle(FocusActionStyle(filled: false, tint: palette.accent))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(palette.misaligned.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.misaligned.opacity(0.3), lineWidth: 1))
    }

    private var liveStatusStrip: some View {
        HStack(spacing: 10) {
            ActivityDot(phase: manager.phase)
            Text(phaseTitle)
                .font(.system(size: 9.5, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(phaseTint)
            if let classification = manager.classification {
                Text(classification.reason)
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            if let activity = manager.currentActivity {
                Text(activity.appName + (activity.site.map { " · \($0)" } ?? ""))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.secondary)
            }
            Text("LIVE")
                .font(.system(size: 8.5, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(palette.aligned)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(palette.background.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.border, lineWidth: 1))
    }

    private var phaseTitle: String {
        switch manager.phase {
        case .blocked: return "BLOCKED"
        case .warning: return "WARNING"
        case .focused: return manager.sessionActive ? "FOCUSED" : "MONITORING"
        }
    }

    private var phaseTint: Color {
        switch manager.phase {
        case .blocked: return palette.misaligned
        case .warning: return palette.warn
        case .focused: return palette.aligned
        }
    }

    private var nextScheduledBlock: ScheduleBlock? {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let minutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let today = manager.schedule
            .filter { $0.days.contains(weekday) }
            .sorted { $0.startMinutes < $1.startMinutes }
        return today.first(where: { $0.startMinutes > minutes }) ?? today.first
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .kerning(1)
            .foregroundStyle(palette.secondary)
    }

    private func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(palette.card.opacity(scheme == .dark ? 0.55 : 0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
    }

    private var focusCard: some View {
        HStack(spacing: 16) {
            FocusRingView(value: manager.score, tint: palette.aligned, size: 72)
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("FOCUS SCORE")
                Text(manager.insight)
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Earn XP by staying aligned with your goal. Distractions deduct.")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary.opacity(0.8))
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("WEEKLY SCHEDULE")
                Spacer()
                Button(showScheduleEditor ? "Cancel" : "Add Block") {
                    if showScheduleEditor {
                        showScheduleEditor = false
                    } else {
                        scheduleTitle = ""
                        scheduleDays = [2, 3, 4, 5, 6]
                        scheduleIsStudy = true
                        scheduleStart = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                        scheduleEnd = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
                        editingScheduleBlock = nil
                        showScheduleEditor = true
                    }
                }
                .buttonStyle(FocusActionStyle(filled: false, tint: palette.accent))
            }
            quickAdd
            presetRow
            if showScheduleEditor {
                scheduleEditor
            }
            if manager.schedule.isEmpty && !showScheduleEditor {
                Text("No schedule yet. The AI won't penalize you during free time, breaks, or meals you schedule.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
            }
            if !manager.schedule.isEmpty {
                scheduleTableHeader
            }
            ForEach(manager.schedule.sorted(by: { $0.startMinutes < $1.startMinutes })) { block in
                scheduleRow(block)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.accent)
                TextField("Quick add — e.g. \"Study 9-11 mon-fri\" or \"Gym 6-7pm daily\"", text: $quickAddText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 9).fill(palette.background.opacity(0.5)))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(quickAddError ? palette.misaligned : palette.border, lineWidth: 1))
                    .onSubmit { performQuickAdd() }
                Button("Add") {
                    performQuickAdd()
                }
                .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
            }
            if quickAddError {
                Text("Couldn't understand that — include a time range, e.g. \"Study 9-11 mon-fri\".")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.misaligned)
            }
        }
    }

    private func performQuickAdd() {
        guard let parsed = ScheduleParser.parse(quickAddText) else {
            quickAddError = true
            return
        }
        quickAddError = false
        let detected = ScheduleActivityType.detect(from: parsed.title)
        let block = ScheduleBlock(
            title: parsed.title,
            type: detected,
            startMinutes: parsed.startMinutes,
            endMinutes: parsed.endMinutes,
            days: parsed.days
        )
        let duplicate = manager.schedule.contains { $0.title == block.title && $0.startMinutes == block.startMinutes }
        if !duplicate {
            manager.addScheduleBlock(block)
        }
        quickAddText = ""
    }

    private var presetRow: some View {
        HStack(spacing: 6) {
            Text("ONE-TAP:")
                .font(.system(size: 8.5, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(palette.secondary)
            ForEach(ScheduleParser.presetBlocks(), id: \.title) { preset in
                let alreadyAdded = manager.schedule.contains { $0.title == preset.title }
                Button {
                    if !alreadyAdded {
                        manager.addScheduleBlock(preset)
                    }
                } label: {
                    Text(preset.title)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(alreadyAdded ? palette.secondary.opacity(0.5) : palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(alreadyAdded ? palette.background.opacity(0.4) : palette.accent.opacity(0.12)))
                        .overlay(Capsule().stroke(alreadyAdded ? palette.border : palette.accent.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(alreadyAdded)
            }
            Spacer()
        }
    }

    private var scheduleEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("START").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                    DatePicker("", selection: $scheduleStart, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("END").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                    DatePicker("", selection: $scheduleEnd, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("WHAT I'LL DO").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                    TextField("e.g. Study system design, Gym, Lunch", text: $scheduleTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(palette.background.opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.border))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("TYPE").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                Picker("", selection: $scheduleIsStudy) {
                    Text("Study").tag(true)
                    Text("Not study").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("DAYS").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        let selected = scheduleDays.contains(day)
                        Button {
                            if selected {
                                scheduleDays.remove(day)
                            } else {
                                scheduleDays.insert(day)
                            }
                        } label: {
                            Text(ScheduleBlock.weekdayNames[day - 1])
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(selected ? Color.white : palette.secondary)
                                .frame(width: 40, height: 26)
                                .background(Capsule().fill(selected ? palette.accent : palette.background.opacity(0.5)))
                                .overlay(Capsule().stroke(palette.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Button("Add to Schedule") {
                    saveScheduleBlock()
                }
                .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
                Spacer()
                if let block = editingScheduleBlock {
                    Button("Delete") {
                        manager.removeScheduleBlock(id: block.id)
                        showScheduleEditor = false
                    }
                    .buttonStyle(FocusActionStyle(filled: false, tint: palette.misaligned))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.background.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.border, lineWidth: 1))
    }

    private func saveScheduleBlock() {
        let start = minutes(from: scheduleStart)
        var end = minutes(from: scheduleEnd)
        if end <= start {
            end += 24 * 60
        }
        let title = scheduleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = resolvedType(title: title)
        let resolvedTitle = title.isEmpty ? (scheduleIsStudy ? "Study" : "Work") : title
        let days = scheduleDays.isEmpty ? Set(1...7) : scheduleDays
        if let existing = editingScheduleBlock {
            var updated = existing
            updated.title = resolvedTitle
            updated.type = type
            updated.startMinutes = start
            updated.endMinutes = end
            updated.days = days
            manager.updateScheduleBlock(updated)
        } else {
            manager.addScheduleBlock(ScheduleBlock(
                title: resolvedTitle,
                type: type,
                startMinutes: start,
                endMinutes: end,
                days: days
            ))
        }
        showScheduleEditor = false
    }

    private func resolvedType(title: String) -> ScheduleActivityType {
        if scheduleIsStudy { return .study }
        let detected = ScheduleActivityType.detect(from: title)
        if detected == .study || detected == .deepWork { return .work }
        return detected
    }

    private func minutes(from date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    private var scheduleTableHeader: some View {
        HStack(spacing: 10) {
            Text("TIME")
                .frame(width: 130, alignment: .leading)
            Text("TASK")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("TYPE")
                .frame(width: 96, alignment: .trailing)
            Text("")
                .frame(width: 22)
        }
        .font(.system(size: 8.5, weight: .bold))
        .kerning(0.8)
        .foregroundStyle(palette.secondary)
        .padding(.horizontal, 8)
    }

    private func scheduleRow(_ block: ScheduleBlock) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(block.startLabel) – \(block.endLabel)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.text)
                Text(block.daysLabel)
                    .font(.system(size: 9.5))
                    .foregroundStyle(palette.secondary)
            }
            .frame(width: 130, alignment: .leading)
            Text(block.title)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(block.isStudy ? "STUDY" : "NOT STUDY")
                .font(.system(size: 8.5, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(block.isStudy ? palette.aligned : palette.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(block.isStudy ? palette.aligned.opacity(0.12) : palette.background.opacity(0.4)))
                .overlay(Capsule().stroke(block.isStudy ? palette.aligned.opacity(0.35) : palette.border, lineWidth: 1))
                .frame(width: 96, alignment: .trailing)
            Button {
                scheduleTitle = block.title
                scheduleStart = Calendar.current.date(bySettingHour: block.startMinutes / 60, minute: block.startMinutes % 60, second: 0, of: Date()) ?? Date()
                scheduleEnd = Calendar.current.date(bySettingHour: block.endMinutes % (24 * 60) / 60, minute: block.endMinutes % 60, second: 0, of: Date()) ?? Date()
                scheduleDays = block.days
                scheduleIsStudy = block.isStudy
                editingScheduleBlock = block
                showScheduleEditor = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 22)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(palette.background.opacity(0.4)))
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("FOCUS SESSION")
            HStack(spacing: 8) {
                StatCell(label: "SESSION", value: Format.duration(manager.sessionDuration), tint: palette.text, palette: palette)
                StatCell(label: "FOCUSED", value: Format.duration(manager.focusedToday), tint: palette.aligned, palette: palette)
                StatCell(label: "DRIFT", value: Format.duration(manager.distractedToday), tint: palette.misaligned, palette: palette)
                StatCell(label: "SESSION XP", value: Format.xp(manager.xpSession), tint: palette.warn, palette: palette)
                StatCell(label: "TOTAL XP", value: "\(manager.totalXP)", tint: palette.text, palette: palette)
            }
            Text("Schedule free time, breaks, and meals — the AI steps back during those blocks and only rewards alignment with your goal the rest of the day.")
                .font(.system(size: 10.5))
                .foregroundStyle(palette.secondary.opacity(0.8))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var lifelineCard: some View {
        let active = manager.isLifelineActive
        let remaining = active
            ? max(0, Int((manager.lifelineEndsAt?.timeIntervalSince(now) ?? 0).rounded()))
            : 0
        let countdown = String(format: "%02d:%02d", remaining / 60, remaining % 60)
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader("LIFELINES")
            HStack(spacing: 8) {
                Image(systemName: "lifeprofile")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.warn)
                Text(active ? "Lifeline active — \(countdown) of free time left" : "\(manager.lifelinesRemaining) of 3 lifelines left today")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(palette.text)
                Spacer()
                if !active {
                    Button("Use 15-min Lifeline") {
                        manager.useLifeline()
                    }
                    .buttonStyle(FocusActionStyle(filled: true, tint: palette.warn))
                    .disabled(manager.lifelinesRemaining <= 0)
                }
            }
            if active {
                ProgressView(value: Double(remaining), total: 15 * 60)
                    .progressViewStyle(.linear)
                    .tint(palette.warn)
            }
            Text("A lifeline pauses blocking and XP drain for 15 minutes — 3 free every day. You've used one on \(manager.lifelineDaysUsed) day\(manager.lifelineDaysUsed == 1 ? "" : "s") (\(manager.lifelineTotalUses) total). Unused lifelines don't carry over.")
                .font(.system(size: 10))
                .foregroundStyle(palette.secondary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var timelineCard: some View {
        let todays = manager.timeline.filter { Calendar.current.isDateInToday($0.startedAt) }
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader("TODAY — TIME SPENT")
            if todays.isEmpty {
                Text("Nothing tracked yet. Watching, browsing, and coding all get counted here.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
            } else {
                let usage = appUsage(todays)
                let totalTime = max(usage.reduce(TimeInterval(0)) { $0 + $1.total }, 1)
                HStack(spacing: 8) {
                    StatCell(label: "TOTAL TRACKED", value: Format.duration(totalTime), tint: palette.text, palette: palette)
                    StatCell(label: "APPS & SITES", value: "\(usage.count)", tint: palette.accent, palette: palette)
                    StatCell(label: "MISALIGNED", value: "\(usage.filter(\.hasMisaligned).count)", tint: palette.misaligned, palette: palette)
                    StatCell(label: "BIGGEST TIMESINK", value: usage.first?.name.capitalized ?? "—", tint: palette.warn, palette: palette)
                }
                let maxTotal = max(usage.map(\.total).max() ?? 1, 1)
                ForEach(usage) { item in
                    appUsageRow(item, maxTotal: maxTotal, totalTime: totalTime)
                }
                Divider().overlay(palette.border)
                sectionHeader("RECENT ACTIVITY")
                ForEach(todays.suffix(6).reversed()) { activity in
                    timelineRow(activity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private struct AppUsage: Identifiable {
        let id: String
        let name: String
        let site: String?
        var hasAligned: Bool
        var hasMisaligned: Bool
        var total: TimeInterval
        var start: Date
        var end: Date
    }

    private func appUsage(_ activities: [Activity]) -> [AppUsage] {
        var order: [String] = []
        var map: [String: AppUsage] = [:]
        for activity in activities {
            let key = activity.site ?? activity.appName
            let name = activity.site ?? activity.appName
            if var existing = map[key] {
                existing.total += activity.duration
                existing.start = min(existing.start, activity.startedAt)
                existing.end = max(existing.end, activity.lastSeenAt)
                if activity.alignment == .misaligned {
                    existing.hasMisaligned = true
                }
                if activity.alignment == .aligned {
                    existing.hasAligned = true
                }
                map[key] = existing
            } else {
                order.append(key)
                map[key] = AppUsage(
                    id: key,
                    name: name,
                    site: activity.site,
                    hasAligned: activity.alignment == .aligned,
                    hasMisaligned: activity.alignment == .misaligned,
                    total: activity.duration,
                    start: activity.startedAt,
                    end: activity.lastSeenAt
                )
            }
        }
        return order.compactMap { map[$0] }.sorted { $0.total > $1.total }
    }

    private func appUsageRow(_ item: AppUsage, maxTotal: TimeInterval, totalTime: TimeInterval) -> some View {
        let tint = item.hasMisaligned ? palette.misaligned : (item.hasAligned ? palette.aligned : palette.secondary)
        let pct = totalTime > 0 ? Int(round(item.total / totalTime * 100)) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.opacity(0.13))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon(for: item.name))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name.capitalized)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    Text(item.hasMisaligned ? "Distracting" : (item.site != nil ? "Website" : "App"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(tint.opacity(0.9))
                }
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.secondary)
                    .frame(width: 38, alignment: .trailing)
                Text(Format.duration(item.total))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.text)
                    .frame(width: 58, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.background.opacity(0.55))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.5), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * CGFloat(item.total / maxTotal)))
                }
            }
            .frame(height: 7)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.background.opacity(0.35)))
    }

    private func icon(for name: String) -> String {
        switch name.lowercased() {
        case "youtube": return "play.rectangle.fill"
        case "linkedin": return "briefcase.fill"
        case "x": return "at"
        case "reddit": return "bubble.left.and.bubble.right.fill"
        case "github", "gitlab", "bitbucket": return "chevron.left.forwardslash.chevron.right"
        case "netflix", "primevideo", "hulu", "disneyplus", "hbo", "crunchyroll": return "tv.fill"
        case "instagram": return "camera.fill"
        case "tiktok": return "music.note"
        case "whatsapp", "telegram", "discord", "slack": return "message.fill"
        case "spotify", "music", "apple music": return "music.note.list"
        case "google", "bing", "duckduckgo", "yahoo": return "magnifyingglass"
        case "gmail", "mail", "outlook": return "envelope.fill"
        case "openai", "anthropic", "claude", "gemini", "chatgpt": return "sparkles"
        case "stackoverflow", "stackexchange": return "questionmark.circle.fill"
        case "medium", "substack": return "book.fill"
        case "wikipedia": return "books.vertical.fill"
        case "coursera", "udemy", "khanacademy", "edx", "brilliant": return "graduationcap.fill"
        case "leetcode", "hackerrank", "codewars": return "function"
        case "notion", "obsidian", "notes": return "note.text"
        case "xcode", "visual studio code", "code", "cursor", "zed": return "chevron.left.forwardslash.chevron.right"
        case "terminal", "iterm2", "warp", "ghostty": return "terminal.fill"
        case "indeed", "glassdoor", "naukri", "monster", "wellfound", "linkedin jobs": return "person.badge.plus"
        case "twitch": return "gamecontroller.fill"
        case "steam": return "gamecontroller.fill"
        default: return "globe"
        }
    }

    private func timelineRow(_ activity: Activity) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(timelineTint(activity).opacity(0.13))
                    .frame(width: 26, height: 26)
                Image(systemName: timelineIcon(activity))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(timelineTint(activity))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text((activity.site ?? activity.appName).capitalized)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(palette.text)
                if let title = activity.windowTitle, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 9.5))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(Format.time(activity.startedAt))–\(Format.time(activity.lastSeenAt))")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(palette.secondary)
            Text(Format.duration(activity.duration))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(timelineTint(activity))
                .frame(width: 54, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func timelineIcon(_ activity: Activity) -> String {
        switch activity.alignment {
        case .aligned: return "checkmark.circle.fill"
        case .misaligned: return "exclamationmark.circle.fill"
        default: return "minus.circle.fill"
        }
    }

    private func timelineTint(_ activity: Activity) -> Color {
        switch activity.alignment {
        case .aligned: return palette.aligned
        case .misaligned: return palette.misaligned
        default: return palette.secondary
        }
    }

    private var guardrailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("GUARDRAILS")
            HStack {
                Text("Blocking mode")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.secondary)
                Spacer()
                Text("Instant")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
            Divider().overlay(palette.border)
            Text("Distracting apps are blocked instantly, anywhere, anytime — and stay blocked until you close them. Free time on your schedule stays free.")
                .font(.system(size: 10))
                .foregroundStyle(palette.secondary.opacity(0.8))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var distractionReportCard: some View {
        let summary = manager.distractionSummary
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("TODAY'S DISTRACTIONS")
                Spacer()
                Button("Full Report") {
                    showDistractionReport = true
                }
                .buttonStyle(FocusActionStyle(filled: false, tint: palette.warn))
            }
            HStack(spacing: 24) {
                StatCell(label: "OPENED", value: "\(summary.count)", tint: palette.warn, palette: palette)
                StatCell(
                    label: "TOTAL TIME",
                    value: Format.duration(summary.totalMinutes * 60),
                    tint: palette.misaligned,
                    palette: palette
                )
                StatCell(
                    label: "TOP DISTRACTION",
                    value: summary.bySite.first?.label ?? "—",
                    tint: palette.text,
                    palette: palette
                )
            }
            if summary.events.isEmpty {
                Text("No distractions opened today. Clean day.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
            } else {
                ForEach(summary.events.suffix(5).reversed()) { event in
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(palette.warn)
                        Text(event.site ?? event.appName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.text)
                        Text(event.title ?? "")
                            .font(.system(size: 10))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(event.startedAt.formatted(date: .omitted, time: .shortened))–\(event.endedAt?.formatted(date: .omitted, time: .shortened) ?? "now")")
                            .font(.system(size: 10))
                            .foregroundStyle(palette.secondary)
                        Text(Format.duration(event.duration))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.warn)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground())
    }

    private var attendanceCard: some View {
        let checksToday = manager.attendanceLog.filter { Calendar.current.isDateInToday($0.at) }.count
        let distractedToday = manager.attendanceLog.filter { Calendar.current.isDateInToday($0.at) && (!$0.person || $0.lookingAway || $0.phoneUse) }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("ATTENDANCE")
                Spacer()
                Button("Report") {
                    showAttendanceReport = true
                }
                .buttonStyle(FocusActionStyle(filled: false, tint: palette.warn))
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(manager.attendanceEnabled && !manager.attendanceStatus.hasPrefix("⚠") ? palette.aligned : palette.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(manager.attendanceStatus)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(manager.attendanceStatus.hasPrefix("⚠") ? palette.warn : palette.text)
            }
            if let last = manager.lastAttendanceAt {
                Text("Last check \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary)
            }
            HStack(spacing: 14) {
                StatCell(label: "CHECKS", value: "\(checksToday)", tint: palette.text, palette: palette)
                StatCell(label: "DISTRACTED", value: "\(distractedToday)", tint: palette.misaligned, palette: palette)
                StatCell(label: "MOUSE IDLE", value: "\(manager.mouseIdleCount)", tint: Theme.gold, palette: palette)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var footer: some View {
        HStack {
            Button("Settings") {
                manager.onRequestSettings?()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(palette.secondary)
            Spacer()
            Button("Quit FocusMac") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(palette.secondary)
        }
    }
}