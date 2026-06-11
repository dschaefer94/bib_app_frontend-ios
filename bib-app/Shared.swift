import Foundation

@MainActor
final class Shared {
    static let item = Shared()

    let dataController: DataController

    private init() {
        dataController = DataController()
    }
}
