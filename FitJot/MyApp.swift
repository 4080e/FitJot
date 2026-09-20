import SwiftUI
import SwiftData

@main struct MyApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try InitialData.makeContainer()
        } catch {
            fatalError("データ保存の初期化に失敗しました: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
