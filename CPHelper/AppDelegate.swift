import UIKit
import UserNotifications
import FirebaseCore

enum FirebaseBootstrap {
    private static let lock = NSLock()
    private static var isConfigured = false

    static func configureIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        guard !isConfigured else { return }
        FirebaseApp.configure()
        isConfigured = true
    }
}

final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configureIfNeeded()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
