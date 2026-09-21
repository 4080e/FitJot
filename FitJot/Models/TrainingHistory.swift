import Foundation
import SwiftData

struct ExerciseHistory: Codable {
    let name: String
    let type: ExerciseType
    let amount: Int
    let plannedSets: Int
    let completedSets: Int
    let skipped: Bool
    let elapsed: TimeInterval
}

@Model
final class TrainingHistory {
    @Attribute(.unique) var sessionID: UUID
    var performedAt: Date
    var planName: String
    var duration: TimeInterval
    var exercises: [ExerciseHistory]

    init(session: TrainingSession) {
        sessionID = session.id
        let start = session.trainingStartedAt ?? session.endedAt ?? .now
        performedAt = start
        planName = session.planName
        duration = max(0, (session.endedAt ?? start).timeIntervalSince(start))
        exercises = session.exercises.map {
            ExerciseHistory(name: $0.name, type: $0.type, amount: $0.amount,
                            plannedSets: $0.sets, completedSets: $0.completedSets,
                            skipped: $0.completedSets == 0, elapsed: $0.elapsed)
        }
    }

    static func save(session: TrainingSession, in context: ModelContext) throws {
        guard session.phase == .finished, session.exercises.contains(where: { $0.completedSets > 0 }) else { return }
        let id = session.id
        let existing = FetchDescriptor<TrainingHistory>(predicate: #Predicate { $0.sessionID == id })
        guard try context.fetchCount(existing) == 0 else { return }
        context.insert(TrainingHistory(session: session))
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}
