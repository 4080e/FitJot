import SwiftData

// Keep the seed marker in the same store and transaction as the sample plans.
@Model
final class InitialDataState {
    var isSeeded: Bool

    init() {
        isSeeded = true
    }
}

@MainActor
enum InitialData {
    static func seedIfNeeded(in context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<InitialDataState>()) == 0 else { return }

        if try context.fetchCount(FetchDescriptor<Plan>()) == 0 {
            let samples: [(String, ExerciseType, Int)] = [
                ("腕立て", .repetitions, 10),
                ("プランク", .timed, 30),
                ("スクワット", .repetitions, 10)
            ]
            for (index, sample) in samples.enumerated() {
                let plan = Plan(name: "プラン\(index + 1)", sortOrder: index)
                context.insert(plan)
                let exercise = Exercise(name: sample.0, type: sample.1,
                                        standardAmount: sample.2, standardSets: 3,
                                        intervalSeconds: 60, sortOrder: 0)
                context.insert(exercise)
                plan.exercises.append(exercise)
            }
        }
        context.insert(InitialDataState())
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Plan.self, Exercise.self, InitialDataState.self, TrainingHistory.self, RotationState.self, RestRecord.self])
        let configuration = ModelConfiguration(schema: schema,
                                               isStoredInMemoryOnly: inMemory,
                                               cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        try seedIfNeeded(in: container.mainContext)
        return container
    }
}
