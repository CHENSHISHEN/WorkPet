import Foundation

protocol NotificationAdapter {
    var name: String { get }

    @MainActor
    func start(emit: @escaping (WorkNotification) -> Void)
}

