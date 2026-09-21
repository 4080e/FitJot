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
    @ObservationIgnored var onCountdownTick: (() -> Void)?
    private var lastCountdownSecond: Int?
    @ObservationIgnored var onCountdownEnd: (() -> Void)?

    struct CountdownNotification: Equatable {
        enum Kind { case interval, timedSet }
        let date: Date
        let kind: Kind
    }

    var currentNotification: CountdownNotification? {
        guard !isPaused, let deadline else { return nil }
        if phase == .interval { return CountdownNotification(date: deadline, kind: .interval) }
        if phase == .exercising && current.type == .timed {
            return CountdownNotification(date: deadline, kind: .timedSet)
        }
        return nil
    }

    // Predict automatic transitions without running a timer in the background.
    var backgroundNotifications: [CountdownNotification] {
        guard let first = currentNotification else { return [] }
        var events = [first]
        guard current.type == .timed else { return events }
        var completed = current.completedSets
        var date = first.date
        var kind = first.kind
        while events.count < 32 {
            if kind == .timedSet {
                completed += 1
                guard completed < current.sets else { break }
                if current.interval > 0 {
                    date = date.addingTimeInterval(TimeInterval(current.interval))
                    kind = .interval
                } else {
                    date = date.addingTimeInterval(TimeInterval(current.amount))
                }
            } else {
                date = date.addingTimeInterval(TimeInterval(current.amount))
                kind = .timedSet
            }
            events.append(CountdownNotification(date: date, kind: kind))
        }
        return events
    }

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
        lastCountdownSecond = nil
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
            lastCountdownSecond = nil
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
            onCountdownEnd?()
            if phase == .interval {
                beginSet(at: end)
            }
            else { completeSet(at: end) }
        }
        if let deadline {
            remaining = max(0, deadline.timeIntervalSince(now))
            let second = Int(ceil(remaining))
            if (1...3).contains(second), lastCountdownSecond != second {
                lastCountdownSecond = second
                onCountdownTick?()
            }
        }
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
