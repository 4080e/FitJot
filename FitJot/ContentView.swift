import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var rotationStates: [RotationState]
    @AppStorage("restRotationFrequency") private var restFrequency = 0
    @State private var confirmingRest = false
    @State private var saveError: String?
    @Query(sort: \Plan.sortOrder) private var plans: [Plan]
    @State private var trainingSession: TrainingSession?
    @State private var selectedPlanID: PersistentIdentifier?

    private var currentPlanID: PersistentIdentifier? {
        plans.first { $0.persistentModelID == selectedPlanID }?.persistentModelID
            ?? rotationStates.first?.nextPlan(in: plans)?.persistentModelID
            ?? plans.first?.persistentModelID
    }

    private var isRestSuggested: Bool {
        rotationStates.first?.shouldSuggestRest(frequency: restFrequency) == true
    }

    var body: some View {
        TabView {
            Tab("次回", systemImage: "figure.strengthtraining.traditional") {
                NavigationStack {
                    List {
                        if isRestSuggested {
                            Section {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("今日は休養がおすすめ", systemImage: "moon.zzz.fill")
                                        .font(.headline)
                                        .foregroundStyle(.blue)
                                    Text("設定したローテーションを完了しました")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .listRowBackground(Color.blue.opacity(0.08))
                            }
                        }
                        ForEach(plans) { plan in
                            Section {
                                Button {
                                    selectedPlanID = plan.persistentModelID
                                } label: {
                                    HStack {
                                        Text("\(plan.label) \(plan.name)")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: currentPlanID == plan.persistentModelID
                                              ? "chevron.down" : "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityValue(currentPlanID == plan.persistentModelID ? "選択中" : "未選択")
                                .accessibilityAddTraits(currentPlanID == plan.persistentModelID ? .isSelected : [])

                                if currentPlanID == plan.persistentModelID {
                                    ForEach(plan.sortedExercises) { exercise in
                                        ExerciseRow(exercise: exercise)
                                    }
                                }
                            }
                        }
                        Section {
                            VStack(spacing: 12) {
                                if isRestSuggested {
                                    trainingButton.fitJotSecondaryAction()
                                    restButton.buttonStyle(.borderedProminent)
                                } else {
                                    trainingButton.fitJotMainAction()
                                    restButton.buttonStyle(.bordered)
                                }
                            }
                            .controlSize(.large)
                            .tint(.blue)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                    .navigationTitle("次回")
                    .confirmationDialog("今日は休養として記録しますか？", isPresented: $confirmingRest, titleVisibility: .visible) {
                        Button("休養を記録") {
                            do { try RestRecord.record(in: context) }
                            catch { saveError = error.localizedDescription }
                        }
                        Button("キャンセル", role: .cancel) {}
                    }
                    .editingSaveAlert(error: $saveError)
                    .fullScreenCover(item: $trainingSession, onDismiss: { selectedPlanID = nil }) { session in
                        TrainingView(session: session)
                    }
                }
            }

            Tab("履歴", systemImage: "calendar") {
                NavigationStack {
                    HistoryView()
                }
            }

            Tab("編集", systemImage: "slider.horizontal.3") {
                NavigationStack {
                    PlanEditorView()
                }
            }
        }
    }

    private var trainingButton: some View {
        Button {
            if let plan = plans.first(where: { $0.persistentModelID == currentPlanID }) {
                trainingSession = TrainingSession(plan: plan)
            }
        } label: {
            Text("トレーニングスタート")
                .frame(maxWidth: .infinity)
        }
        .disabled(plans.first(where: { $0.persistentModelID == currentPlanID })?.exercises.isEmpty ?? true)
    }

    private var restButton: some View {
        Button { confirmingRest = true } label: {
            Text("今日は休養")
                .frame(maxWidth: .infinity)
        }
    }

}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
            Text("\(exercise.standardAmount)\(exercise.type == .repetitions ? "回" : "秒") × \(exercise.standardSets)セット")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(try! InitialData.makeContainer(inMemory: true))
}
