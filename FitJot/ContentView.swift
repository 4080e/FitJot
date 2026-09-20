import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Plan.sortOrder) private var plans: [Plan]
    @State private var selectedPlanID: PersistentIdentifier?

    private var currentPlanID: PersistentIdentifier? {
        selectedPlanID ?? plans.first?.persistentModelID
    }

    var body: some View {
        TabView {
            Tab("次回", systemImage: "figure.strengthtraining.traditional") {
                NavigationStack {
                    List {
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
                                Button {} label: {
                                    Text("トレーニングスタート")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                Button {} label: {
                                    Text("今日は休養")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            .controlSize(.large)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                    .navigationTitle("次回")
                }
            }

            Tab("履歴", systemImage: "calendar") {
                NavigationStack {
                    ContentUnavailableView("履歴はまだありません", systemImage: "calendar")
                        .navigationTitle("履歴")
                }
            }

            Tab("編集", systemImage: "slider.horizontal.3") {
                NavigationStack {
                    List(plans) { plan in
                        Section(plan.label) {
                            ForEach(plan.sortedExercises) { exercise in
                                ExerciseRow(exercise: exercise)
                            }
                        }
                    }
                    .navigationTitle("編集")
                }
            }
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
