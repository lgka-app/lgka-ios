import UIKit

/// Orientation policy: the app is portrait-only except while a PDF is open
/// (pdf_viewer_screen parity). Main-actor isolated so the delegate and the
/// viewer agree without unsynchronized global state.
@MainActor
final class OrientationLock {
    static let shared = OrientationLock()
    var mask: UIInterfaceOrientationMask = .portrait

    func allowAll() {
        mask = .all
        updateSupportedOrientations()
    }

    func restorePortrait() {
        mask = .portrait
        updateSupportedOrientations()
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }

    /// UIKit caches the supported orientations; without this a changed mask only
    /// applies after the next device rotation.
    private func updateSupportedOrientations() {
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?)
        -> UIInterfaceOrientationMask { OrientationLock.shared.mask }
}
