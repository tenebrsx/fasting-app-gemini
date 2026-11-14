import Charts
import SwiftData
import SwiftUI

private enum HistoryChartMetric: String, CaseIterable, Identifiable {
    case protein
    case calories

    var id: String { rawValue }
    var title: String { self == .protein ? "Protein" : "Calories" }
    var macroKind: MacroKind { self == .protein ? .protein : .calories }
}

private struct DayChartPoint: Identifiable {
    let date: Date
    let value: Double
    let isMet: Bool

    var id: Date { date }
}

struct HistoryView: View {
    @Environment(ToastCenter.self) private var toastCenter

    @Query(sort: \FastEntry.start, order: .reverse) private var fasts: [FastEntry]
    @Query(sort: \MealEntry.time, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \UserSettings.updatedAt, order: .reverse) private var settingsList: [UserSettings]

    @State private var metric: HistoryChartMetric = .protein
    @State private var editingFast: FastEntry?

    private var settings: UserSettings? {
        settingsList.first
    }

    private var completedFasts: [FastEntry] {
        fasts.filter { $0.end != nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("History")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.top, 4)

                statsGrid

                chartCard

                HStack {
                    Text("Fasts")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.top, 4)

                fastsList
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $editingFast) { fast in
            EditFastSheet(fast: fast, allFasts: fasts) { message in
                toastCenter.show(message)
            }
        }
    }

    private var statsGrid: some View {
        let done = completedFasts
        let durations = done.map { $0.duration() }
        let totalSeconds = durations.reduce(0, +)
        let longest = durations.max()
        let average = done.isEmpty ? nil : totalSeconds / Double(done.count)
        let streak = done.prefix(while: { $0.didHitGoal }).count
        let hits = done.filter { $0.didHitGoal }.count
        let hitPct = done.isEmpty ? "—" : "\(Int((Double(hits) / Double(done.count) * 100).rounded()))%"

        let items: [(String, String)] = [
            ("\(done.count)", "Fasts"),
            (longest.map { Formatters.duration($0) } ?? "—", "Longest"),
            (average.map { Formatters.duration($0) } ?? "—", "Average"),
            ("\(streak)", "Goal streak"),
            ("\(Int((totalSeconds / 3600.0).rounded()))h", "Total fasted"),
            (hitPct, "Goals hit"),
        ]

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            spacing: 10
        ) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    Text(item.0)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.1)
                        .font(.caption)
                        .foregroundStyle(Theme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appCard(padding: 12, radius: Theme.radiusSM)
            }
        }
    }

    private var chartCard: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = settings?.target(for: metric.macroKind)

        let points: [DayChartPoint] = (0..<14).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -(13 - offset), to: today) else { return nil }
            let dayTotal = meals
                .filter { cal.isDate($0.time, inSameDayAs: day) }
                .reduce(0.0) { $0 + $1.value(for: metric.macroKind) }
            let isMet = metric == .protein && (target ?? 0) > 0 && dayTotal >= (target ?? 0)
            return DayChartPoint(date: day, value: dayTotal, isMet: isMet)
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Last 14 days")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                Picker("Metric", selection: $metric) {
                    ForEach(HistoryChartMetric.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 155)
            }

            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(
                        point.value <= 0
                            ? Theme.line
                            : (point.isMet ? Theme.ok : Theme.ember)
                    )
                    .cornerRadius(4)
                }

                if let target, target > 0 {
                    RuleMark(y: .value("Target", target))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(Theme.mist)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("\(Int(target.rounded()))\(metric == .calories ? "" : "g")")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.mist)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { value in
                    AxisValueLabel(format: .dateTime.day())
                        .foregroundStyle(Theme.mist)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Theme.line.opacity(0.6))
                    AxisValueLabel().foregroundStyle(Theme.mist)
                }
            }
            .frame(height: 165)
        }
        .appCard(padding: 16)
    }

    @ViewBuilder
    private var fastsList: some View {
        if fasts.isEmpty {
            Text("No fasts yet. Start one from the Timer tab.")
                .font(.subheadline)
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .appCard(padding: 20)
        } else {
            VStack(spacing: 10) {
                ForEach(fasts) { fast in
                    Button {
                        editingFast = fast
                    } label: {
                        FastHistoryRow(fast: fast)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct FastHistoryRow: View {
    let fast: FastEntry

    var body: some View {
        let isLive = fast.isActive
        let hit = fast.didHitGoal
        let targetText = Formatters.hoursLabel(fast.targetHours)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Formatters.duration(fast.duration()))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.ink)
                Text("\(Formatters.fullDateTime(fast.start)) → \(fast.end.map { Formatters.smartTime($0) } ?? "now")")
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
            }

            Spacer(minLength: 8)

            Text(isLive ? "In progress" : (hit ? "\(targetText) goal ✓" : "\(targetText) goal"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isLive ? Theme.onPrimary : (hit ? Theme.ok : Theme.mist))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isLive ? Theme.ember : (hit ? Theme.ok.opacity(0.16) : Theme.surface2),
                    in: Capsule()
                )
        }
        .appCard(padding: 14)
    }
}

private struct EditFastSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let fast: FastEntry
    let allFasts: [FastEntry]
    let onComplete: (String) -> Void

    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var targetHoursText: String
    @State private var notes: String
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    init(fast: FastEntry, allFasts: [FastEntry], onComplete: @escaping (String) -> Void) {
        self.fast = fast
        self.allFasts = allFasts
        self.onComplete = onComplete
        _startDate = State(initialValue: fast.start)
        _hasEndDate = State(initialValue: fast.end != nil)
        _endDate = State(initialValue: fast.end ?? Date())
        _targetHoursText = State(initialValue: fast.targetHours.rounded() == fast.targetHours ? "\(Int(fast.targetHours))" : "\(fast.targetHours)")
        _notes = State(initialValue: fast.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Started", selection: $startDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    Toggle("Completed", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Ended", selection: $endDate, in: startDate...Date(), displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Goal & Notes") {
                    HStack {
                        Text("Goal (hours)")
                        Spacer()
                        TextField("24", text: $targetHoursText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.danger)
                            .font(.footnote)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        if confirmDelete {
                            deleteFast()
                        } else {
                            confirmDelete = true
                        }
                    } label: {
                        Text(confirmDelete ? "Tap again to delete" : "Delete fast")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit fast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveFast() }
                }
            }
        }
    }

    private func saveFast() {
        guard let targetHours = Double(targetHoursText) else {
            errorMessage = ValidationError.invalidTargetHours.localizedDescription
            return
        }
        let resolvedEnd = hasEndDate ? endDate : nil
        do {
            try FastValidator.validateFast(
                start: startDate,
                end: resolvedEnd,
                targetHours: targetHours,
                editingID: fast.id,
                existingFasts: allFasts
            )
            fast.start = startDate
            fast.end = resolvedEnd
            fast.targetHours = targetHours
            fast.notes = notes
            fast.updatedAt = Date()
            try modelContext.save()
            onComplete("Fast saved")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteFast() {
        modelContext.delete(fast)
        try? modelContext.save()
        onComplete("Fast deleted")
        dismiss()
    }
}
