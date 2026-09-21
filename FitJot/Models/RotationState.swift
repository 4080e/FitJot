import Foundation
import SwiftData

@Model
final class RotationState {
    private var lastPlanData: Data?
    private var visitedPlanData: Data = Data()

    var lastPlanID: Data? { lastPlanData }
    var lastPlanOrder: Int = 0
    private var visitedPlanIDs: [Data] {
        (try? JSONDecoder().decode([Data].self, from: visitedPlanData)) ?? []
    }

    // Compare canonical encoded IDs; decoded identifiers can use a different backing type.
    private func key(for id: PersistentIdentifier) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(id)
    }
    var completedRotations: Int = 0

    init() {}

    static func load(in context: ModelContext) throws -> RotationState {
        if let state = try context.fetch(FetchDescriptor<RotationState>()).first { return state }
        let state = RotationState()
        context.insert(state)
        return state
    }

    func nextPlan(in plans: [Plan]) -> Plan? {
        guard !plans.isEmpty else { return nil }
        guard let lastPlanID else { return plans.first }
        if let index = plans.firstIndex(where: { (try? key(for: $0.persistentModelID)) == lastPlanID }) {
            return plans[(index + 1) % plans.count]
        }
        // If the last plan was deleted, continue at the position it occupied.
        return plans.first { $0.sortOrder >= lastPlanOrder } ?? plans.first
    }

    func record(planID: PersistentIdentifier, plans: [Plan]) throws {
        let existingIDs = Set(try plans.map { try key(for: $0.persistentModelID) })
        let planKey = try key(for: planID)
        var visited = visitedPlanIDs.filter { existingIDs.contains($0) }
        guard let plan = plans.first(where: { $0.persistentModelID == planID }) else { return }
        lastPlanData = planKey
        lastPlanOrder = plan.sortOrder
        if !visited.contains(planKey) { visited.append(planKey) }
        if !existingIDs.isEmpty && existingIDs.isSubset(of: Set(visited)) {
            completedRotations += 1
            visited = []
        }
        visitedPlanData = try JSONEncoder().encode(visited)
    }

    func shouldSuggestRest(frequency: Int) -> Bool {
        frequency > 0 && completedRotations >= frequency
    }

    func recordRest() {
        completedRotations = 0
        visitedPlanData = Data()
    }
}
