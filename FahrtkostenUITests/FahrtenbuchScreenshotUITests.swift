import XCTest

/// Nimmt Screenshots des Fahrtenbuchmodus mit mehrmonatigen Demodaten auf (Kilometerstände,
/// Monats-/Jahresauswertung, Änderungsprotokoll) – für Kundenanfragen, nicht Teil der
/// regulären Testsuite. Aufnahme der Screenshots erfolgt extern per
/// `xcrun simctl io <udid> screenshot`, getaktet über die festen Wartezeiten hier.
final class FahrtenbuchScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testFahrtenbuchScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-debugForcePro", "YES", "-fahrtenbuchDemo"]
        app.launch()

        func shot(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        sleep(5) // Splash

        // Einmalige System-Benachrichtigung ("Bereit für Apple Intelligence") nach frischem
        // Simulator-Reset wegwischen – sie bleibt sonst dauerhaft stehen und blockiert Taps
        // auf allem darunter. Koordinatenbasierte Wischgeste, da die Banner zu SpringBoard
        // gehört, nicht zur App.
        let dismissStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        let dismissEnd   = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -0.3))
        dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
        sleep(2)

        // ── Fahrt bearbeiten (Kilometerstände sichtbar) ─────────────────────
        // Manuell scrollen statt dem automatischen "scroll to visible" zu vertrauen – die
        // Fahrtenliste ist ein SwiftUI ScrollView/LazyVStack, kein natives UITableView, und
        // XCUITest findet den Scroll-Container dafür zuverlässig nicht automatisch.
        // Koordinaten bewusst mittig im Listenbereich (nicht nahe der unteren Tab-Bar), sonst
        // greift die Geste ins Leere.
        func scrollListUp() {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            let end   = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        scrollListUp()
        sleep(1)
        scrollListUp()
        sleep(1)

        // Zeilen sind als zusammengesetztes Accessibility-Element mit vollem Satz
        // ("Fahrt am ... von ... nach ...") exponiert – ein kurzer Treffer nur auf den
        // Zielort matcht stattdessen ein unsichtbares Duplikat-Element (nicht hittable).
        let editRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'nach Werksgelände'")).firstMatch
        if editRow.waitForExistence(timeout: 5) {
            editRow.tap()
        }
        sleep(2)
        shot("01_Fahrt_bearbeiten_Kilometerstand")

        let saveButton = app.navigationBars["Fahrt bearbeiten"].buttons["Speichern"]
        if saveButton.waitForExistence(timeout: 3) {
            saveButton.tap()
        }
        sleep(1)

        // ── Fahrt löschen (für "deleted"-Eintrag im Änderungsprotokoll) ─────
        let globusRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'nach Globus'")).firstMatch
        if globusRow.waitForExistence(timeout: 5) {
            globusRow.press(forDuration: 1.2)
            sleep(1)
            let deleteMenuItem = app.buttons["Löschen"]
            if deleteMenuItem.waitForExistence(timeout: 3) {
                deleteMenuItem.tap()
            }
        }
        sleep(2)
        shot("02_Fahrtenliste_nach_Bearbeiten_Loeschen")

        // ── Statistik: Jahresauswertung ──────────────────────────────────────
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Statistik'")).firstMatch.tap()
        sleep(3)
        shot("03_Statistik_Jahresauswertung")

        // ── Statistik: Monatsauswertung (nach unten scrollen, Tab "Monate" ist Standard) ──
        scrollListUp()
        sleep(1)
        scrollListUp()
        sleep(2)
        shot("04_Statistik_Monatsauswertung")

        // ── Einstellungen → Fahrtenbuchmodus → Änderungsprotokoll ────────────
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Übersicht'")).firstMatch.tap()
        sleep(1)
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'gearshape'")).firstMatch
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
        }
        sleep(1)

        // Fahrtenbuchmodus-Abschnitt liegt weiter unten im Einstellungen-Formular – erst
        // dorthin scrollen, sonst ist die Zeile noch nicht gerendert/hittable.
        scrollListUp()
        sleep(1)
        scrollListUp()
        sleep(1)

        let fahrtenbuchRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Fahrtenbuchmodus'")).firstMatch
        if fahrtenbuchRow.waitForExistence(timeout: 3) {
            fahrtenbuchRow.tap()
        }
        sleep(1)
        shot("debug_after_expand")

        let changeLogLink = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Änderungsprotokoll ansehen'")).firstMatch
        if changeLogLink.waitForExistence(timeout: 3) {
            changeLogLink.tap()
        } else {
            scrollListUp()
            sleep(1)
            shot("debug_after_extra_scroll")
            if changeLogLink.waitForExistence(timeout: 3) {
                changeLogLink.tap()
            }
        }
        sleep(3)
        shot("05_Aenderungsprotokoll")
    }

    /// Eigenständiger, kürzerer Testlauf nur für den Änderungsprotokoll-Screenshot – weniger
    /// vorherige Schritte/Scrollgesten bedeuten weniger Fehlerquellen für dieses eine Bild.
    func testChangeLogScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["-debugForcePro", "YES", "-fahrtenbuchDemo"]
        app.launch()

        func shot(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        sleep(5) // Splash
        let dismissStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        let dismissEnd   = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -0.3))
        dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
        sleep(2)

        func scrollListUp() {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            let end   = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        // Der Einstellungen-Zahnrad-Button sitzt im Übersicht-Tab, nicht im Fahrten-Tab.
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Übersicht'")).firstMatch.tap()
        sleep(2)

        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'gearshape'")).firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }
        sleep(2)

        scrollListUp()
        sleep(1)
        scrollListUp()
        sleep(1)
        shot("debug2_before_fahrtenbuch_tap")

        let fahrtenbuchRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Fahrtenbuchmodus'")).firstMatch
        if fahrtenbuchRow.waitForExistence(timeout: 5) {
            fahrtenbuchRow.tap()
        }
        sleep(2)
        shot("debug2_after_fahrtenbuch_tap")

        let changeLogLink = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Änderungsprotokoll ansehen'")).firstMatch
        if changeLogLink.waitForExistence(timeout: 5) {
            changeLogLink.tap()
        }
        sleep(3)
        shot("05_Aenderungsprotokoll_v2")
    }
}
