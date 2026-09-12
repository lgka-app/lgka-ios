import XCTest

/// Automated store/marketing screenshots, driven by scripts/screenshots.sh.
///
/// Configuration comes from the test runner's environment
/// (`TEST_RUNNER_LGKA_*` on the xcodebuild command line):
///   LGKA_SCREENSHOT_DIR  absolute output directory (required)
///   LGKA_LOGIN           user:pass for the school website (required)
///   LGKA_THEME           dark | light | system (default light)
///   LGKA_LOCALE          de | en (default de)
///   LGKA_CLASS           schedule class to preselect (default 7b)
///
/// One app session per run: the app is launched once through the DEBUG seed
/// (see `DebugSeed` in App/LGKAApp.swift — reset, theme, accent, class; never a
/// login), the welcome screen is captured, onboarding is walked through, the real
/// credentials are typed into the login form and every further capture is taken
/// on that same session — no relaunch per screenshot, no coordinates, no mouse.
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

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        let locale = env["LGKA_LOCALE"] ?? "de"
        app.launchArguments += ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "de" ? "de_DE" : "en_US"]
        app.launchEnvironment["LGKA_DEBUG_RESET"] = "1"
        app.launchEnvironment["LGKA_DEBUG_NO_AUTOFILL"] = "1"
        app.launchEnvironment["LGKA_DEBUG_THEME"] = env["LGKA_THEME"] ?? "light"
        app.launchEnvironment["LGKA_DEBUG_ACCENT"] = env["LGKA_ACCENT"] ?? "blue"
        app.launchEnvironment["LGKA_DEBUG_CLASS"] = env["LGKA_CLASS"] ?? "7b"
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
                    // the prompt can animate away between the check and the tap (seen on iPad):
                    // only tap a button that is still hittable, never fail on one that vanished
                    if button.exists, button.isHittable { button.tap(); tapped = true; break }
                }
                if tapped { break }
            }
            if !tapped {
                // last resort: the sheet's first non-primary button, then log what we saw
                if let first = app.sheets.firstMatch.buttons.allElementsBoundByIndex.first(where: { $0.isHittable && !["Save", "Sichern", "Update", "Aktualisieren"].contains($0.label) }) {
                    first.tap(); tapped = true
                }
            }
            if !tapped, !promptVisible(hosts) { return } // it went away on its own
            if !tapped {
                print("PROMPT HIERARCHY APP:\n\(app.debugDescription.prefix(6000))")
                print("PROMPT HIERARCHY SPRINGBOARD:\n\(springboard.debugDescription.prefix(6000))")
                return
            }
            sleep(1)
        }
    }

    private func save(_ name: String, in app: XCUIApplication) throws {
        dismissSystemPrompts(app)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(promptVisible([app, springboard]), "system prompt visible during capture of \(name)")
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try png.write(to: outputDir.appendingPathComponent("\(name).png"), options: .atomic)
        print("SCREENSHOT \(name)")
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    private func wait(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 20, _ what: String? = nil) {
        XCTAssertTrue(element(app, id).waitForExistence(timeout: timeout), what ?? "missing \(id)")
    }

    private func tap(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 20) {
        wait(app, id, timeout: timeout)
        let target = element(app, id)
        // Right after the login form hands over to the hub, XCUITest can still consider the hub's
        // cards "not hittable" (a stale hit-test through the dismissed keyboard/scroll view) even
        // though they are fully on screen — a coordinate tap does not run that check.
        if target.isHittable { target.tap() } else { target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
    }

    /// Waits for the home hub to have live data (weather card present) and no skeletons.
    private func waitForHome(_ app: XCUIApplication, timeout: TimeInterval = 40) {
        wait(app, "home.weather", timeout: timeout, "home hub did not appear")
        // events load last; never capture their skeleton (an empty calendar is legitimate, so no assert)
        _ = element(app, "home.event").firstMatch.waitForExistence(timeout: 25)
        // let the sky shader and list settle
        sleep(2)
    }

    /// Pops the pushed screen via the navigation bar's back button and waits for `expect`
    /// (the hub's weather card by default) to be back.
    private func back(_ app: XCUIApplication, expect: String = "home.weather") {
        let backButton = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "no back button")
        backButton.tap()
        wait(app, expect, timeout: 15, "\(expect) did not come back after popping")
        sleep(1)
    }

    /// Closes the full-screen PDF viewer.
    private func closePdf(_ app: XCUIApplication) {
        tap(app, "pdf.close", timeout: 10)
        wait(app, "home.weather", timeout: 15, "home hub did not come back after the PDF viewer")
        sleep(1)
    }

    func testScreenshots() throws {
        guard let login = env["LGKA_LOGIN"], let sep = login.firstIndex(of: ":") else {
            XCTFail("LGKA_LOGIN not set"); return
        }
        let app = launch()

        // 01 — welcome
        wait(app, "onboarding.continue", "welcome screen did not appear")
        sleep(1)
        try save("01_welcome", in: app)

        // onboarding → login form (real credentials: this is also the login-gate regression)
        for _ in 0..<4 { tap(app, "onboarding.continue") }
        let user = element(app, "auth.username")
        wait(app, "auth.username", timeout: 10, "login form did not appear")
        user.tap()
        user.typeText(String(login[..<sep]))
        let pass = element(app, "auth.password")
        pass.tap()
        pass.typeText(String(login[login.index(after: sep)...]))
        tap(app, "auth.login")

        // 02 — home hub after the login
        waitForHome(app, timeout: 60)
        try save("02_home", in: app)

        // 03 — weather
        tap(app, "home.weather")
        wait(app, "weather.page", "weather page did not open")
        sleep(3)
        try save("03_weather", in: app)
        back(app)

        // 04 / 05 — news list and the first article
        tap(app, "home.news")
        let row = element(app, "news.row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "news list did not load")
        sleep(1)
        try save("04_news", in: app)
        row.tap()
        wait(app, "news.detail", timeout: 30, "news detail did not open")
        sleep(2)
        try save("05_news_detail", in: app)
        back(app, expect: "news.row") // → list
        back(app) // → hub

        // 06 — substitution plan (today, else tomorrow; skipped on a day without one)
        let today = element(app, "home.plan.today")
        let tomorrow = element(app, "home.plan.tomorrow")
        _ = today.waitForExistence(timeout: 20)
        let target = today.isEnabled ? today : tomorrow
        if target.exists, target.isEnabled {
            target.tap()
            wait(app, "pdf.close", "PDF viewer did not open")
            sleep(3)
            try save("06_plan", in: app)
            closePdf(app)
        } else {
            print("SCREENSHOT 06_plan skipped: no substitution plan available today")
        }

        // 07 — timetable, opened on the selected class's page (class index), not on page 1
        tap(app, "home.schedule")
        wait(app, "pdf.close", timeout: 40, "PDF viewer did not open")
        sleep(4) // PDFKit layout + class-page jump
        try save("07_schedule", in: app)
        closePdf(app)

        // 08 — settings sheet
        tap(app, "home.settings")
        wait(app, "settings.close", timeout: 10, "settings sheet did not open")
        sleep(1)
        try save("08_settings", in: app)
    }
}
