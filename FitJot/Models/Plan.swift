import SwiftData

@Model
final class Plan {
    var name: String
    var sortOrder: Int
    @Relationship(deleteRule: .cascade, inverse: \Exercise.plan)
    var exercises: [Exercise] = []

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }

    var label: String {
        var number = sortOrder + 1
        var result = ""
        while number > 0 {
            number -= 1
            result = String(UnicodeScalar(65 + number % 26)!) + result
            number /= 26
        }
        return result
    }

    var sortedExercises: [Exercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }
}
