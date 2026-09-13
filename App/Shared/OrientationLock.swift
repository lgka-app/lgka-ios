import UIKit

/// Orientation policy: the app is portrait-only except while a PDF is open
/// (pdf_viewer_screen parity). Main-actor isolated so the delegate and the
/// viewer agree without unsynchronized global state.
@MainActor
final class OrientationLock {
    static let shared = OrientationLock()
    var mask: UIInterfaceOrientationMask = .portrait

    func allowAll() { mask = .all }

    func restorePortrait() {
        mask = .portrait
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?)
        -> UIInterfaceOrientationMask { OrientationLock.shared.mask }
}
