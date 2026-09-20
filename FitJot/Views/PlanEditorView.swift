import SwiftUI
import SwiftData

struct PlanEditorView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Plan.sortOrder) private var plans: [Plan]
    @State private var showingAdd = false
    @State private var name = ""
    @State private var saveError: String?

    var body: some View {
        List {
            ForEach(plans) { plan in
                NavigationLink {
                    PlanDetailEditor(plan: plan)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(plan.label) \(plan.name)")
                        ForEach(plan.sortedExercises) { exercise in
                            Text("\(exercise.name) · \(exercise.standardAmount)\(exercise.type == .repetitions ? "回" : "秒") × \(exercise.standardSets)セット")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in
                var remaining = plans
                for index in offsets { context.delete(plans[index]) }
                remaining.remove(atOffsets: offsets)
                for (index, plan) in remaining.enumerated() { plan.sortOrder = index }
                saveError = context.saveEditingChanges()
            }
            .onMove { source, destination in
                var reordered = plans
                reordered.move(fromOffsets: source, toOffset: destination)
                for (index, plan) in reordered.enumerated() { plan.sortOrder = index }
                saveError = context.saveEditingChanges()
            }
            Button("プランを追加", systemImage: "plus") {
                name = ""
                showingAdd = true
            }
        }
        .navigationTitle("編集")
        .toolbar {
            EditButton()
                .environment(\.locale, Locale(identifier: "ja"))
        }
        .alert("プランを追加", isPresented: $showingAdd) {
            TextField("プラン名", text: $name)
            Button("キャンセル", role: .cancel) {}
            Button("追加") {
                context.insert(Plan(name: name.trimmingCharacters(in: .whitespacesAndNewlines), sortOrder: plans.count))
                saveError = context.saveEditingChanges()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .editingSaveAlert(error: $saveError)
    }
}

private struct PlanDetailEditor: View {
    @Environment(\.modelContext) private var context
    let plan: Plan
    @State private var showingRename = false
    @State private var name = ""
    @State private var showingAddExercise = false
    @State private var editingExercise: Exercise?
    @State private var saveError: String?

    var body: some View {
        List {
            Section("プラン") {
                Button {
                    name = plan.name
                    showingRename = true
                } label: {
                    LabeledContent("プラン名", value: plan.name)
                }
            }
            Section("種目") {
                ForEach(plan.sortedExercises) { exercise in
                    Button {
                        editingExercise = exercise
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name).foregroundStyle(.primary)
                            Text("\(exercise.standardAmount)\(exercise.type == .repetitions ? "回" : "秒") × \(exercise.standardSets)セット")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    var remaining = plan.sortedExercises
                    for index in offsets { context.delete(remaining[index]) }
                    remaining.remove(atOffsets: offsets)
                    plan.exercises = remaining
                    for (index, exercise) in remaining.enumerated() { exercise.sortOrder = index }
                    saveError = context.saveEditingChanges()
                }
                .onMove { source, destination in
                    var reordered = plan.sortedExercises
                    reordered.move(fromOffsets: source, toOffset: destination)
                    for (index, exercise) in reordered.enumerated() { exercise.sortOrder = index }
                    saveError = context.saveEditingChanges()
                }
                Button("種目を追加", systemImage: "plus") { showingAddExercise = true }
            }
        }
        .navigationTitle("\(plan.label) \(plan.name)")
        .toolbar {
            EditButton()
                .environment(\.locale, Locale(identifier: "ja"))
        }
        .alert("プラン名を変更", isPresented: $showingRename) {
            TextField("プラン名", text: $name)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                plan.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                saveError = context.saveEditingChanges()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .sheet(isPresented: $showingAddExercise) {
            ExerciseEditorView(plan: plan)
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseEditorView(plan: plan, exercise: exercise)
        }
        .editingSaveAlert(error: $saveError)
    }
}

extension ModelContext {
    func saveEditingChanges() -> String? {
        do {
            try save()
            return nil
        } catch {
            rollback()
            return error.localizedDescription
        }
    }
}

extension View {
    func editingSaveAlert(error: Binding<String?>) -> some View {
        alert("保存できませんでした", isPresented: Binding(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) { error.wrappedValue = nil }
        } message: {
            Text(error.wrappedValue ?? "")
        }
    }
}
