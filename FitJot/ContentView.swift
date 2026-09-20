import SwiftUI

struct ContentView: View {
    @State private var selectedPlanID = "A"

    var body: some View {
        TabView {
            Tab("次回", systemImage: "figure.strengthtraining.traditional") {
                NavigationStack {
                    List {
                        ForEach(SamplePlan.plans) { plan in
                            Section {
                                Button {
                                    selectedPlanID = plan.id
                                } label: {
                                    HStack {
                                        Text("\(plan.id) \(plan.name)")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: selectedPlanID == plan.id
                                              ? "chevron.down" : "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityValue(selectedPlanID == plan.id ? "選択中" : "未選択")
                                .accessibilityAddTraits(selectedPlanID == plan.id ? .isSelected : [])

                                if selectedPlanID == plan.id {
                                    ExerciseRow(plan: plan)
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
                    List(SamplePlan.plans) { plan in
                        Section(plan.id) {
                            ExerciseRow(plan: plan)
                        }
                    }
                    .navigationTitle("編集")
                }
            }
        }
    }
}

private struct SamplePlan: Identifiable {
    let id: String
    let name: String
    let exerciseName: String
    let amount: String

    static let plans = [
        SamplePlan(id: "A", name: "プラン1", exerciseName: "腕立て", amount: "10回 × 3セット"),
        SamplePlan(id: "B", name: "プラン2", exerciseName: "プランク", amount: "30秒 × 3セット"),
        SamplePlan(id: "C", name: "プラン3", exerciseName: "スクワット", amount: "10回 × 3セット")
    ]
}

private struct ExerciseRow: View {
    let plan: SamplePlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.exerciseName)
            Text(plan.amount)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
