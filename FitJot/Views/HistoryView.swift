import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingHistory.performedAt, order: .reverse) private var histories: [TrainingHistory]
    @Query(sort: \RestRecord.date, order: .reverse) private var restRecords: [RestRecord]
    @State private var deletingRest: RestRecord?
    @State private var month = Date.now
    @State private var selectedDate = Date.now
    @State private var deleting: TrainingHistory?
    @State private var saveError: String?
    private let japaneseLocale = Locale(identifier: "ja_JP")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = japaneseLocale
        return calendar
    }

    private func dateText(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = japaneseLocale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: month)!.start
    }
    private var leadingDays: Int {
        (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
    }
    private var dayCount: Int { calendar.range(of: .day, in: .month, for: month)!.count }
    private var selectedHistories: [TrainingHistory] {
        histories.filter { calendar.isDate($0.performedAt, inSameDayAs: selectedDate) }
    }
    private var markedDays: Set<Date> {
        Set(histories.map { calendar.startOfDay(for: $0.performedAt) })
    }

    private var selectedRests: [RestRecord] {
        restRecords.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }
    private var restDays: Set<Date> {
        Set(restRecords.map { calendar.startOfDay(for: $0.date) })
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("前の月")
                    Spacer()
                    Text(dateText(month, template: "yMMMM")).font(.headline)
                    Spacer()
                    Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("次の月")
                }
                .buttonStyle(.borderless)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                    ForEach(0..<7, id: \.self) { offset in
                        Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + offset) % 7])
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(0..<(leadingDays + dayCount), id: \.self) { cell in
                        if cell < leadingDays {
                            Color.clear.frame(height: 44).accessibilityHidden(true)
                        } else {
                            let date = calendar.date(byAdding: .day, value: cell - leadingDays, to: monthStart)!
                            let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                            let marked = markedDays.contains(calendar.startOfDay(for: date))
                            let rested = restDays.contains(calendar.startOfDay(for: date))
                            Button { selectedDate = date } label: {
                                VStack(spacing: 3) {
                                    Text("\(cell - leadingDays + 1)")
                                        .font(.body).minimumScaleFactor(0.6).lineLimit(1)
                                    HStack(spacing: 3) {
                                        Circle().fill(marked ? Color.accentColor : .clear)
                                            .frame(width: 5, height: 5)
                                        Image(systemName: "moon.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                            .opacity(rested ? 1 : 0)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(selected ? Color.accentColor.opacity(0.18) : .clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(dateText(date, template: "yMMMMdEEEE"))
                            .accessibilityValue(marked && rested ? "トレーニング実施日・休養" : marked ? "トレーニング実施日" : rested ? "休養" : "記録なし")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
            }
            Section(dateText(selectedDate, template: "yMMMMd")) {
                if selectedHistories.isEmpty && selectedRests.isEmpty {
                    Text("この日の記録はありません").foregroundStyle(.secondary)
                }
                ForEach(selectedRests) { rest in
                    HStack {
                        Label("休養", systemImage: "moon.fill")
                        Spacer()
                        Button("削除", role: .destructive) { deletingRest = rest }
                            .buttonStyle(.borderless)
                    }
                }
                ForEach(selectedHistories) { history in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(history.planName).font(.headline)
                        Text(dateText(history.performedAt, template: "Hm"))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("所要時間：\(durationText(history.duration))")
                        ForEach(Array(history.exercises.enumerated()), id: \.offset) { _, exercise in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                Text(exerciseSummary(exercise))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Button("履歴を削除", role: .destructive) { deleting = history }
                            .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                    .swipeActions {
                        Button("削除", role: .destructive) { deleting = history }
                    }
                }
            }
        }
        .environment(\.locale, japaneseLocale)
        .navigationTitle("履歴")
        .confirmationDialog("この履歴を削除しますか？", isPresented: Binding(
            get: { deleting != nil || deletingRest != nil }, set: { if !$0 { deleting = nil; deletingRest = nil } }
        ), titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                if let deleting {
                    context.delete(deleting)
                    saveError = context.saveEditingChanges()
                }
                if let deletingRest {
                    context.delete(deletingRest)
                    saveError = context.saveEditingChanges()
                }
                deleting = nil
                deletingRest = nil
            }
            Button("キャンセル", role: .cancel) { deleting = nil; deletingRest = nil }
        }
        .editingSaveAlert(error: $saveError)
    }

    private func changeMonth(_ offset: Int) {
        guard let date = calendar.date(byAdding: .month, value: offset, to: monthStart) else { return }
        month = date
        selectedDate = date
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 { return "\(seconds)秒" }
        return "\(seconds / 60)分\(seconds % 60)秒"
    }

    private func exerciseSummary(_ exercise: ExerciseHistory) -> String {
        if exercise.skipped { return "スキップ" }
        let result = "\(exercise.amount)\(exercise.type == .repetitions ? "回" : "秒") × \(exercise.completedSets)セット"
        if exercise.completedSets < exercise.plannedSets {
            return result + "（予定\(exercise.plannedSets)セット）"
        }
        return result
    }

}
