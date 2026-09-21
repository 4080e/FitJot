import Foundation
import SwiftData

@Model
final class RestRecord {
    var date: Date

    init(date: Date) { self.date = date }

    static func record(at date: Date = .now, in context: ModelContext) throws {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<RestRecord>(predicate: #Predicate { $0.date >= start && $0.date < end })
        guard try context.fetchCount(descriptor) == 0 else { return }
        do {
            context.insert(RestRecord(date: date))
            try RotationState.load(in: context).recordRest()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
