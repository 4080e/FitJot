import Foundation
import Observation
import SwiftData

struct TrainingExercise {
    let name: String
    let type: ExerciseType
    var amount: Int
    var sets: Int
    var interval: Int
    var completedSets = 0
    var elapsed: TimeInterval = 0
    var skipped = false
}

@Observable
final class TrainingSession: Identifiable {
    enum Phase { case ready, exercising, interval, finished }

    let id = UUID()
    private(set) var sourcePlanID: PersistentIdentifier?
    let planName: String
    var exercises: [TrainingExercise]
    private(set) var index = 0
    private(set) var phase: Phase = .ready
    private(set) var isPaused = false
    private(set) var remaining: TimeInterval = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var trainingStartedAt: Date?
    private(set) var endedAt: Date?
    private var deadline: Date?
    private var startedAt: Date?
    private var pausedAt: Date?
    private var pausedDuration: TimeInterval = 0

    init(planName: String, exercises: [TrainingExercise]) {
        self.planName = planName
        self.exercises = exercises
        if exercises.isEmpty { phase = .finished }
    }

    convenience init(plan: Plan) {
        self.init(planName: "\(plan.label) \(plan.name)", exercises: plan.sortedExercises.map {
            TrainingExercise(name: $0.name, type: $0.type, amount: $0.standardAmount,
                             sets: $0.standardSets, interval: $0.intervalSeconds)
        })
        sourcePlanID = plan.persistentModelID
    }

    var current: TrainingExercise { exercises[index] }

    func start(at now: Date = .now) {
        guard phase == .ready else { return }
        if trainingStartedAt == nil { trainingStartedAt = now }
        startedAt = now
        beginSet(at: now)
    }

    private func beginSet(at now: Date) {
        phase = .exercising
        remaining = current.type == .timed ? TimeInterval(current.amount) : 0
        deadline = current.type == .timed ? now.addingTimeInterval(remaining) : nil
    }

    func completeRepetitionSet(at now: Date = .now) {
        guard phase == .exercising, current.type == .repetitions else { return }
        completeSet(at: now)
    }

    private func completeSet(at now: Date) {
        exercises[index].completedSets += 1
        if current.completedSets >= current.sets {
            advance(at: now)
        } else if current.interval > 0 {
            phase = .interval
            remaining = TimeInterval(current.interval)
            deadline = now.addingTimeInterval(remaining)
        } else {
            beginSet(at: now)
        }
    }

    func update(at now: Date = .now) {
        guard phase != .finished, !isPaused else { return }
        // Use deadlines so delayed foreground updates do not accumulate timer drift.
        while let end = deadline, end <= now, phase != .finished {
            if phase == .interval { beginSet(at: end) }
            else { completeSet(at: end) }
        }
        if let deadline { remaining = max(0, deadline.timeIntervalSince(now)) }
        if let startedAt { elapsed = max(0, now.timeIntervalSince(startedAt) - pausedDuration) }
    }

    func togglePause(at now: Date = .now) {
        guard phase == .interval || (phase == .exercising && current.type == .timed) else { return }
        if isPaused {
            if let pausedAt { pausedDuration += now.timeIntervalSince(pausedAt) }
            deadline = now.addingTimeInterval(remaining)
            pausedAt = nil
            isPaused = false
        } else {
            update(at: now)
            guard deadline != nil, phase != .finished else { return }
            remaining = max(0, deadline!.timeIntervalSince(now))
            deadline = nil
            pausedAt = now
            isPaused = true
        }
    }

    func skipInterval(at now: Date = .now) {
        guard phase == .interval else { return }
        endPause(at: now)
        beginSet(at: now)
    }

    func endExercise(at now: Date = .now) {
        guard phase != .finished else { return }
        advance(at: now)
    }

    func finish(at now: Date = .now) {
        guard phase != .finished else { return }
        recordCurrent(at: now)
        deadline = nil
        isPaused = false
        endedAt = now
        phase = .finished
    }

    private func endPause(at now: Date) {
        if let pausedAt { pausedDuration += now.timeIntervalSince(pausedAt) }
        pausedAt = nil
        isPaused = false
    }

    private func recordCurrent(at now: Date) {
        endPause(at: now)
        if let startedAt { elapsed = max(0, now.timeIntervalSince(startedAt) - pausedDuration) }
        exercises[index].elapsed = elapsed
        exercises[index].skipped = current.completedSets == 0
    }

    private func advance(at now: Date) {
        recordCurrent(at: now)
        deadline = nil
        startedAt = nil
        pausedDuration = 0
        remaining = 0
        if index + 1 < exercises.count {
            index += 1
            elapsed = 0
            phase = .ready
        } else {
            endedAt = now
            phase = .finished
        }
    }
}
