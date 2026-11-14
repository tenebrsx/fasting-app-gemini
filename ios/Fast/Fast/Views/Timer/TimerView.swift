import SwiftData
import SwiftUI

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DataStore.self) private var dataStore
    @Environment(ToastCenter.self) private var toastCenter

    @Query(sort: \FastEntry.start, order: .reverse) private var fasts: [FastEntry]
    @Query(sort: \UserSettings.updatedAt, order: .reverse) private var settingsList: [UserSettings]

    @State private var selectedHours: Double?
    @State private var showEditStart = false
    @State private var showEndFast = false
    @State private var showCustomTarget = false

    private var activeFast: FastEntry? {
        fasts.first(where: { $0.end == nil })
    }

    private var lastEndedFast: FastEntry? {
        fasts.first(where: { $0.end != nil })
    }

    private var defaultHours: Double {
        settingsList.first?.defaultFastHours ?? 24
    }

    private var currentTargetHours: Double {
        if let activeFast {
            return activeFast.targetHours
        }
        return selectedHours ?? defaultHours
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let elapsed = activeFast?.duration(at: now) ?? 0
            let elapsedHours = elapsed / 3600.0
            let sinceLast = lastEndedFast?.end.map { max(0, now.timeIntervalSince($0)) }

            ScrollView {
                VStack(spacing: 18) {
                    headerView

                    FastingRingView(
                        isFasting: activeFast != nil,
                        elapsed: elapsed,
                        sinceLastFast: sinceLast,
                        targetHours: currentTargetHours
                    )

                    zoneBanner(elapsedHours: elapsedHours)

                    timesGrid(now: now)

                    presetsRow

                    actionButton

                    zonesList(elapsedHours: elapsedHours)

                    Text("Zones are rough approximations that vary from person to person. They're a guide, not medical advice.")
                        .font(.footnote)
                        .foregroundStyle(Theme.mist)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(Theme.bg.ignoresSafeArea())
        }
        .sheet(isPresented: $showEditStart) {
            if let activeFast {
                EditStartSheet(fast: activeFast, allFasts: fasts) {
                    toastCenter.show("Start time updated")
                }
            }
        }
        .sheet(isPresented: $showEndFast) {
            if let activeFast {
                EndFastSheet(fast: activeFast, allFasts: fasts) { durationText in
                    toastCenter.show("Fast ended · \(durationText)")
                }
            }
        }
        .sheet(isPresented: $showCustomTarget) {
            CustomTargetSheet(initialHours: currentTargetHours) { hours in
                applyTarget(hours)
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text(activeFast != nil ? "Fasting" : "Not fasting")
                .font(.title2.bold())
                .foregroundStyle(Theme.ink)
            Spacer()
            SyncStatusDot(syncState: dataStore.syncState)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func zoneBanner(elapsedHours: Double) -> some View {
        if activeFast != nil {
            let zone = FastingZone.zone(at: elapsedHours)
            HStack(spacing: 10) {
                Circle()
                    .fill(zone.color.opacity(zone.opacity))
                    .frame(width: 10, height: 10)
                Text("**\(zone.name)** · \(zone.detail)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }
            .appCard(padding: 12, radius: Theme.radiusSM)
        } else if let le = lastEndedFast, let end = le.end {
            Text("Last fast: \(Formatters.duration(end.timeIntervalSince(le.start))), ended \(Formatters.smartTime(end))")
                .font(.subheadline)
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
        }
    }

    private func timesGrid(now: Date) -> some View {
        HStack(spacing: 12) {
            Button {
                showEditStart = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Started")
                        .font(.caption)
                        .foregroundStyle(Theme.mist)
                    Text(activeFast.map { Formatters.smartTime($0.start, relativeTo: now) } ?? "—")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(activeFast != nil ? "Edit" : " ")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.ember)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard(padding: 14)
            }
            .buttonStyle(.plain)
            .disabled(activeFast == nil)

            VStack(alignment: .leading, spacing: 4) {
                Text(activeFast != nil ? "Goal" : "Goal if you start now")
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
                let goalDate = activeFast?.goalDate ?? now.addingTimeInterval(currentTargetHours * 3600.0)
                Text(Formatters.smartTime(goalDate, relativeTo: now))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(activeFast != nil ? Formatters.hoursLabel(currentTargetHours) : " ")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.mist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard(padding: 14)
        }
    }

    private var presetsRow: some View {
        let isCustom = !FastingZone.presets.contains(currentTargetHours)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FastingZone.presets, id: \.self) { hours in
                    let selected = currentTargetHours == hours
                    Button {
                        applyTarget(hours)
                    } label: {
                        Text(Formatters.hoursLabel(hours))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selected ? Theme.onPrimary : Theme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? Theme.ember : Theme.surface2, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showCustomTarget = true
                } label: {
                    Text(isCustom ? Formatters.hoursLabel(currentTargetHours) : "Custom")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isCustom ? Theme.onPrimary : Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isCustom ? Theme.ember : Theme.surface2, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionButton: some View {
        Button {
            if activeFast == nil {
                startFast()
            } else {
                showEndFast = true
            }
        } label: {
            Text(activeFast == nil ? "Start \(Formatters.hoursLabel(currentTargetHours)) fast" : "End fast")
        }
        .buttonStyle(
            PrimaryPillButtonStyle(
                background: activeFast == nil ? Theme.ember : Theme.coral,
                foreground: activeFast == nil ? Theme.onPrimary : .white,
                isLarge: true
            )
        )
    }

    private func zonesList(elapsedHours: Double) -> some View {
        VStack(spacing: 8) {
            ForEach(FastingZone.all.filter { $0.hours > 0 }) { zone in
                let reached = activeFast != nil && elapsedHours >= zone.hours
                let dimmed = zone.hours > currentTargetHours
                HStack(spacing: 12) {
                    Text(Formatters.hoursLabel(zone.hours))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(reached ? zone.color : Theme.mist)
                        .frame(width: 38, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(zone.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(zone.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.mist)
                    }

                    Spacer()

                    Circle()
                        .fill(reached ? zone.color.opacity(zone.opacity) : Theme.line)
                        .frame(width: 10, height: 10)
                }
                .opacity(dimmed && !reached ? 0.45 : 1.0)
                .appCard(padding: 12, radius: Theme.radiusSM)
            }
        }
    }

    private func startFast() {
        let now = Date()
        do {
            try FastValidator.validateFast(
                start: now,
                end: nil,
                targetHours: currentTargetHours,
                editingID: nil,
                existingFasts: fasts,
                now: now
            )
            let entry = FastEntry(start: now, targetHours: currentTargetHours, source: "app")
            modelContext.insert(entry)
            try modelContext.save()
            toastCenter.show("Fast started · \(Formatters.hoursLabel(currentTargetHours)) goal")
        } catch {
            toastCenter.show(error.localizedDescription)
        }
    }

    private func applyTarget(_ hours: Double) {
        do {
            try FastValidator.validateTargetHours(hours)
            selectedHours = hours
            if let activeFast {
                activeFast.targetHours = hours
                activeFast.updatedAt = Date()
                try modelContext.save()
            }
        } catch {
            toastCenter.show(error.localizedDescription)
        }
    }
}

private struct EditStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let fast: FastEntry
    let allFasts: [FastEntry]
    let onSaved: () -> Void

    @State private var startDate: Date
    @State private var errorMessage: String?

    init(fast: FastEntry, allFasts: [FastEntry], onSaved: @escaping () -> Void) {
        self.fast = fast
        self.allFasts = allFasts
        self.onSaved = onSaved
        _startDate = State(initialValue: fast.start)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Started at", selection: $startDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Theme.danger)
                        .font(.footnote)
                }
            }
            .navigationTitle("Edit start time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        do {
            try FastValidator.validateFast(
                start: startDate,
                end: fast.end,
                targetHours: fast.targetHours,
                editingID: fast.id,
                existingFasts: allFasts
            )
            fast.start = startDate
            fast.updatedAt = Date()
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EndFastSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let fast: FastEntry
    let allFasts: [FastEntry]
    let onEnded: (String) -> Void

    @State private var endDate = Date()
    @State private var notes: String
    @State private var errorMessage: String?

    init(fast: FastEntry, allFasts: [FastEntry], onEnded: @escaping (String) -> Void) {
        self.fast = fast
        self.allFasts = allFasts
        self.onEnded = onEnded
        _notes = State(initialValue: fast.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("You've fasted **\(Formatters.duration(endDate.timeIntervalSince(fast.start)))** of your \(Formatters.hoursLabel(fast.targetHours)) goal.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mist)
                }

                Section {
                    DatePicker("Ended at", selection: $endDate, in: fast.start...Date(), displayedComponents: [.date, .hourAndMinute])
                    TextField("How did it go?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Theme.danger)
                        .font(.footnote)
                }
            }
            .navigationTitle("End fast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("End fast") { save() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        do {
            try FastValidator.validateFast(
                start: fast.start,
                end: endDate,
                targetHours: fast.targetHours,
                editingID: fast.id,
                existingFasts: allFasts
            )
            fast.end = endDate
            fast.notes = notes
            fast.updatedAt = Date()
            try modelContext.save()
            onEnded(Formatters.duration(endDate.timeIntervalSince(fast.start)))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CustomTargetSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var hoursText: String
    @State private var errorMessage: String?
    let onApply: (Double) -> Void

    init(initialHours: Double, onApply: @escaping (Double) -> Void) {
        _hoursText = State(initialValue: initialHours.rounded() == initialHours ? "\(Int(initialHours))" : "\(initialHours)")
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hours (1 – 240)") {
                    TextField("Hours", text: $hoursText)
                        .keyboardType(.decimalPad)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Theme.danger)
                        .font(.footnote)
                }
            }
            .navigationTitle("Custom fast length")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let val = Double(hoursText) else {
                            errorMessage = ValidationError.invalidTargetHours.localizedDescription
                            return
                        }
                        do {
                            try FastValidator.validateTargetHours(val)
                            onApply(val)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
        .presentationDetents([.height(240)])
    }
}
