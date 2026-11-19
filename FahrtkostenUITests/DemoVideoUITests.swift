import XCTest

/// Fährt die App für die Aufnahme eines Promo-Videos ab (Instagram/YouTube/Facebook).
/// Wird extern per `xcrun simctl io <udid> recordVideo` aufgezeichnet, während dieser Test
/// läuft. Kein Teil der regulären Testsuite – bewusst ohne Assertions, reine UI-Choreografie
/// mit festen Wartezeiten für ein ruhiges, gut schneidbares Rohmaterial.
final class DemoVideoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// Tippt das Feld an und wartet aktiv, bis die Tastatur wirklich erscheint (mit Retry),
    /// bevor getippt wird – unter Last (parallele Bildschirmaufnahme + GPS-Simulation) braucht
    /// der erste Fokuswechsel manchmal mehrere Anläufe.
    private func focusAndType(_ field: XCUIElement, _ text: String, in app: XCUIApplication) {
        let keyboard = app.keyboards.element
        for _ in 0..<5 {
            field.tap()
            if keyboard.waitForExistence(timeout: 2) { break }
        }
        sleep(1)
        field.typeText(text)
    }

    func testRecordPromoDemo() {
        let app = XCUIApplication()
        app.launchArguments = ["-debugForcePro", "YES", "-demoSeed"]
        app.launch()

        // Splash-Screen abwarten
        sleep(4)

        // ── Beat 1: Fahrt manuell erfassen ──────────────────────────────────
        app.buttons["Neue Fahrt manuell eingeben"].tap()
        sleep(2)

        let start = app.textFields["Startort"]
        if start.waitForExistence(timeout: 3) {
            focusAndType(start, "Rathausplatz 1, 70173 Stuttgart", in: app)
        }

        let ziel = app.textFields["Zielort"]
        if ziel.exists {
            focusAndType(ziel, "Flughafen Stuttgart, 70629 Stuttgart", in: app)
        }

        let km = app.textFields["0,0"]
        if km.exists {
            focusAndType(km, "14,0", in: app)
        }

        // Tastatur schließen per Wisch-Geste (List/Form dismisst interaktiv) –
        // NICHT die NavigationBar antippen, da dort "Abbrechen" sitzt und ein
        // Treffer das Formular verwerfen würde.
        app.swipeUp()
        sleep(2)

        let addButton = app.navigationBars["Neue Fahrt"].buttons["Hinzufügen"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        }
        sleep(2)

        // ── Beat 2: GPS-Streckenaufzeichnung ────────────────────────────────
        app.buttons["GPS-Aufzeichnung starten"].tap()
        sleep(1)

        let startRecording = app.buttons["Aufzeichnung starten"]
        if startRecording.waitForExistence(timeout: 5) {
            startRecording.tap()
        }

        // Live-Tracking sichtbar lassen (simulierte Fahrt läuft parallel über simctl)
        sleep(7)

        let stopButton = app.buttons["Beenden"]
        if stopButton.waitForExistence(timeout: 3) {
            stopButton.tap()
        }
        sleep(3) // Geocoding + Übergang ins Formular

        let addFromGPS = app.navigationBars["Neue Fahrt"].buttons["Hinzufügen"]
        if addFromGPS.waitForExistence(timeout: 5) {
            addFromGPS.tap()
        }
        sleep(2)

        // ── Beat 3: Verpflegungspauschale ───────────────────────────────────
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Arbeitszeit'")).firstMatch.tap()
        sleep(4)

        // ── Beat 4: PDF-Export ───────────────────────────────────────────────
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Übersicht'")).firstMatch.tap()
        sleep(2)

        app.buttons["Export-Menü"].tap()
        sleep(1)

        let pdfMenuItem = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'PDF Vorschau'")
        ).firstMatch
        if pdfMenuItem.waitForExistence(timeout: 3) {
            pdfMenuItem.tap()
        }
        sleep(1)

        let createPDF = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'PDF erstellen'")
        ).firstMatch
        if createPDF.waitForExistence(timeout: 3) {
            createPDF.tap()
        }
        sleep(3) // PDF-Vorschau anzeigen lassen
    }
}
