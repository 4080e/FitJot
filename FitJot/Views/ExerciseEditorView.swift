import SwiftUI
import SwiftData

struct ExerciseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let plan: Plan
    let exercise: Exercise?
    @State private var name: String
    @State private var type: ExerciseType
    @State private var amount: Int
    @State private var sets: Int
    @State private var interval: Int
    @State private var saveError: String?

    init(plan: Plan, exercise: Exercise? = nil) {
        self.plan = plan
        self.exercise = exercise
        _name = State(initialValue: exercise?.name ?? "")
        _type = State(initialValue: exercise?.type ?? .repetitions)
        _amount = State(initialValue: exercise?.standardAmount ?? 10)
        _sets = State(initialValue: exercise?.standardSets ?? 3)
        _interval = State(initialValue: exercise?.intervalSeconds ?? 20)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("種目") {
                    TextField("種目名", text: $name)
                    Picker("種別", selection: $type) {
                        Text("回数制").tag(ExerciseType.repetitions)
                        Text("時間制").tag(ExerciseType.timed)
                    }
                }
                Section("標準値") {
                    Stepper(value: $amount, in: 1...Int.max) {
                        Text(type == .repetitions ? "標準回数：\(amount)回" : "標準秒数：\(amount)秒")
                    }
                    Stepper("標準セット数：\(sets)", value: $sets, in: 1...Int.max)
                    Stepper("インターバル：\(interval)秒", value: $interval, in: 0...Int.max, step: 5)
                }
            }
            .navigationTitle(exercise == nil ? "種目を追加" : "種目を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .editingSaveAlert(error: $saveError)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exercise {
            exercise.name = trimmedName
            exercise.type = type
            exercise.standardAmount = amount
            exercise.standardSets = sets
            exercise.intervalSeconds = interval
        } else {
            let newExercise = Exercise(name: trimmedName, type: type, standardAmount: amount,
                                       standardSets: sets, intervalSeconds: interval,
                                       sortOrder: plan.exercises.count)
            context.insert(newExercise)
            plan.exercises.append(newExercise)
        }
        saveError = context.saveEditingChanges()
        if saveError == nil { dismiss() }
    }
}
