import XCTest

/// Automated store/marketing screenshots, driven by scripts/screenshots.sh.
///
/// Configuration comes from the test runner's environment
/// (`TEST_RUNNER_LGKA_*` on the xcodebuild command line):
///   LGKA_SCREENSHOT_DIR  absolute output directory (required)
///   LGKA_LOGIN           user:pass for the school website (required except welcome)
///   LGKA_THEME           dark | light | system (default light)
///   LGKA_LOCALE          de | en (default de)
///   LGKA_CLASS           schedule class to preselect (default 7b)
///
/// Every test launches the app fresh through the DEBUG seed (see
/// `DebugSeed` in App/LGKAApp.swift) — no coordinates, no mouse.
@MainActor
final class ScreenshotTests: XCTestCase {
    nonisolated private let env = ProcessInfo.processInfo.environment
    nonisolated private var outputDir: URL {
        URL(fileURLWithPath: env["LGKA_SCREENSHOT_DIR"] ?? NSTemporaryDirectory() + "lgka-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    private func launch(seeded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        let locale = env["LGKA_LOCALE"] ?? "de"
        app.launchArguments += ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "de" ? "de_DE" : "en_US"]
        app.launchEnvironment["LGKA_DEBUG_RESET"] = "1"
        app.launchEnvironment["LGKA_DEBUG_NO_AUTOFILL"] = "1"
        app.launchEnvironment["LGKA_DEBUG_THEME"] = env["LGKA_THEME"] ?? "light"
        app.launchEnvironment["LGKA_DEBUG_ACCENT"] = env["LGKA_ACCENT"] ?? "blue"
        if seeded {
            app.launchEnvironment["LGKA_DEBUG_LOGIN"] = env["LGKA_LOGIN"] ?? ""
            app.launchEnvironment["LGKA_DEBUG_CLASS"] = env["LGKA_CLASS"] ?? "7b"
        }
        app.launch()
        // Store captures are portrait on every device; an interrupted run can leave the simulator rotated.
        XCUIDevice.shared.orientation = .portrait
        return app
    }

    /// System prompts (e.g. the iOS "Save Password?" AutoFill sheet after a login)
    /// must never end up in a capture: dismiss them, then assert none is left.
    private static let promptTexts = ["Save Password?", "Passwort sichern?", "Update Password?", "Passwort aktualisieren?"]
    private static let dismissLabels = ["Not Now", "Nicht jetzt", "Never for This Website", "Nie für diese Website", "Cancel", "Abbrechen"]

    private func promptVisible(_ hosts: [XCUIApplication]) -> Bool {
        hosts.contains { host in Self.promptTexts.contains { host.staticTexts[$0].exists } }
    }

    private func dismissSystemPrompts(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let hosts = [app, springboard]
        for _ in 0..<4 {
            guard promptVisible(hosts) || hosts.contains(where: { h in Self.dismissLabels.contains { h.buttons[$0].exists } }) else { return }
            var tapped = false
            for host in hosts {
                for label in Self.dismissLabels {
                    let button = host.buttons[label].firstMatch
                    if button.exists { button.tap(); tapped = true; break }
                }
                if tapped { break }
            }
            if !tapped {
                // last resort: the sheet's first non-primary button, then log what we saw
                if let first = app.sheets.firstMatch.buttons.allElementsBoundByIndex.first(where: { !["Save", "Sichern", "Update", "Aktualisieren"].contains($0.label) }) {
                    first.tap(); tapped = true
                }
            }
            if !tapped {
                print("PROMPT HIERARCHY APP:\n\(app.debugDescription.prefix(6000))")
                print("PROMPT HIERARCHY SPRINGBOARD:\n\(springboard.debugDescription.prefix(6000))")
                return
            }
            sleep(1)
        }
    }

    private func save(_ name: String, in app: XCUIApplication? = nil) throws {
        if let app {
            dismissSystemPrompts(app)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            XCTAssertFalse(promptVisible([app, springboard]), "system prompt visible during capture of \(name)")
        }
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try png.write(to: outputDir.appendingPathComponent("\(name).png"), options: .atomic)
    }

    /// Waits for the home hub to have live data (weather card present).
    private func waitForHome(_ app: XCUIApplication) {
        _ = app.descendants(matching: .any)["home.weather"].waitForExistence(timeout: 40)
        // events load last; never capture their skeleton (an empty calendar is legitimate, so no assert)
        _ = app.descendants(matching: .any)["home.event"].firstMatch.waitForExistence(timeout: 25)
        // let the sky shader and list settle
        sleep(2)
    }

    private func tap(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 20) {
        let element = app.descendants(matching: .any)[id]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "missing \(id)")
        element.tap()
    }

    func test01Welcome() throws {
        let app = launch(seeded: false)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.continue"].waitForExistence(timeout: 20))
        sleep(1)
        try save("01_welcome", in: app)
    }

    func test02Home() throws {
        let app = launch(seeded: true)
        waitForHome(app)
        try save("02_home", in: app)
    }

    func test03Weather() throws {
        let app = launch(seeded: true)
        waitForHome(app)
        tap(app, "home.weather")
        XCTAssertTrue(app.descendants(matching: .any)["weather.page"].waitForExistence(timeout: 20), "weather page did not open")
        sleep(3)
        try save("03_weather", in: app)
    }

    func test04News() throws {
        let app = launch(seeded: true)
        waitForHome(app)
        tap(app, "home.news")
        _ = app.descendants(matching: .any)["news.row"].firstMatch.waitForExistence(timeout: 30)
        sleep(1)
        try save("04_news", in: app)
    }

    func test05NewsDetail() throws {
        let app = launch(seeded: true)
        waitForHome(app)
        tap(app, "home.news")
        let row = app.descendants(matching: .any)["news.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["news.detail"].waitForExistence(timeout: 30), "news detail did not open")
        sleep(2)
        try save("05_news_detail", in: app)
    }

    func test06Plan() throws {
        let app = launch(seeded: true)
        waitForHome(app)
        let today = app.descendants(matching: .any)["home.plan.today"]
        let tomorrow = app.descendants(matching: .any)["home.plan.tomorrow"]
        _ = today.waitForExistence(timeout: 20)
        let target = today.isEnabled ? today : tomorrow
        guard target.exists, target.isEnabled else { throw XCTSkip("no substitution plan available today") }
        target.tap()
        XCTAssertTrue(app.descendants(matching: .any)["a11y.close"].firstMatch.waitForExistence(timeout: 20)
                      || app.navigationBars.firstMatch.waitForExistence(timeout: 5), "PDF viewer did not open")
        sleep(3)
        try save("06_plan", in: app)
    }

    func test07Settings() throws {
        let app = launch(seeded: true)
        waitForHome(app)
        tap(app, "home.settings")
        XCTAssertTrue(app.descendants(matching: .any)["settings.close"].waitForExistence(timeout: 10), "settings sheet did not open")
        sleep(1)
        try save("07_settings", in: app)
    }

    /// Regression for the login gate: real credentials must lead to the home hub.
    func test08LoginFlow() throws {
        guard let login = env["LGKA_LOGIN"], let sep = login.firstIndex(of: ":") else {
            throw XCTSkip("LGKA_LOGIN not set")
        }
        let app = launch(seeded: false)
        tap(app, "onboarding.continue")
        tap(app, "onboarding.continue")
        tap(app, "onboarding.continue")
        tap(app, "onboarding.continue")
        let user = app.descendants(matching: .any)["auth.username"]
        XCTAssertTrue(user.waitForExistence(timeout: 10))
        user.tap()
        user.typeText(String(login[..<sep]))
        let pass = app.descendants(matching: .any)["auth.password"]
        pass.tap()
        pass.typeText(String(login[login.index(after: sep)...]))
        tap(app, "auth.login")
        XCTAssertTrue(app.descendants(matching: .any)["home.weather"].waitForExistence(timeout: 40),
                      "home hub did not appear after login")
        try save("08_after_login", in: app)
    }
}
