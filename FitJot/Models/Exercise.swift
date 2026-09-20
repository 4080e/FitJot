import SwiftData

enum ExerciseType: String, Codable {
    case repetitions
    case timed
}

@Model
final class Exercise {
    var name: String
    var type: ExerciseType
    var standardAmount: Int
    var standardSets: Int
    var intervalSeconds: Int
    var sortOrder: Int
    var plan: Plan?

    init(name: String, type: ExerciseType, standardAmount: Int,
         standardSets: Int, intervalSeconds: Int, sortOrder: Int) {
        self.name = name
        self.type = type
        self.standardAmount = standardAmount
        self.standardSets = standardSets
        self.intervalSeconds = intervalSeconds
        self.sortOrder = sortOrder
    }
}
