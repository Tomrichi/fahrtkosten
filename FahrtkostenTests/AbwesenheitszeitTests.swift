import XCTest
@testable import Fahrtkosten

/// Deckt die Abwesenheitszeit-Berechnung in DataStore.totalWorkHours(for:) ab: Summe der
/// Einzelzeiten (Standard seit Build 87) vs. durchgehende Spanne (Fahrtenbuchmodus).
final class AbwesenheitszeitTests: XCTestCase {

    private var store: DataStore!

    override func setUp() {
        super.setUp()
        store = DataStore()
        // DataStore persistiert über UserDefaults/iCloud – frühere Testläufe (oder die App
        // selbst) können bereits Daten hinterlassen haben. Für isolierte Tests explizit leeren.
        store.fahrtenbuchModusEnabled = false
        store.trips = []
        RollbackGuard.resetForTesting()
        store.meals = []
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Fahrt 8–9 Uhr, Lücke (z. B. Kundentermin) 9–11 Uhr, Fahrt 11–12 Uhr.
    private func addGapTrips(on day: (Int, Int, Int)) {
        store.addTrip(Trip(
            from: "Start", to: "Kunde", date: date(day.0, day.1, day.2, 8),
            km: 20, startTime: date(day.0, day.1, day.2, 8), endTime: date(day.0, day.1, day.2, 9)
        ))
        store.addTrip(Trip(
            from: "Kunde", to: "Start", date: date(day.0, day.1, day.2, 11),
            km: 20, startTime: date(day.0, day.1, day.2, 11), endTime: date(day.0, day.1, day.2, 12)
        ))
    }

    func testSumModeIgnoresGapBetweenTrips() {
        addGapTrips(on: (2026, 11, 10))
        let probe = MealEntry(
            date: date(2026, 11, 10, 8), startTime: date(2026, 11, 10, 8), endTime: date(2026, 11, 10, 12),
            note: "", region: .inland
        )
        // Summe: 1h + 1h = 2h, die 2h Lücke beim Kunden zählen nicht mit.
        XCTAssertEqual(store.totalWorkHours(for: probe), 2.0, accuracy: 0.001)
    }

    func testFahrtenbuchModusUsesFullSpanIncludingGap() {
        store.fahrtenbuchModusEnabled = true
        addGapTrips(on: (2026, 11, 10))
        let probe = MealEntry(
            date: date(2026, 11, 10, 8), startTime: date(2026, 11, 10, 8), endTime: date(2026, 11, 10, 12),
            note: "", region: .inland
        )
        // Spanne: früheste Abfahrt 8 Uhr bis späteste Rückkehr 12 Uhr = 4h, inkl. Lücke beim Kunden.
        XCTAssertEqual(store.totalWorkHours(for: probe), 4.0, accuracy: 0.001)
    }

    func testExcludeTripsShortCircuitsRegardlessOfMode() {
        store.fahrtenbuchModusEnabled = true
        addGapTrips(on: (2026, 11, 10))
        let probe = MealEntry(
            date: date(2026, 11, 10, 8), startTime: date(2026, 11, 10, 8), endTime: date(2026, 11, 10, 9, 30),
            note: "", region: .inland, excludeTrips: true
        )
        // excludeTrips: nur die eigene Arbeitszeit (1,5h), Fahrten werden ignoriert.
        XCTAssertEqual(store.totalWorkHours(for: probe), 1.5, accuracy: 0.001)
    }

    // MARK: - Tagessprung (Arbeitszeit über Mitternacht)

    func testRolledOverIfNeededAddsDayWhenEndBeforeStart() {
        // 06:00 Uhr Beginn, 01:00 Uhr "Ende" (eigentlich am Folgetag) – ohne Korrektur läge
        // das Ende vor dem Beginn.
        let start = date(2026, 11, 10, 6)
        let sameDayEnd = date(2026, 11, 10, 1)
        let corrected = rolledOverIfNeeded(sameDayEnd, after: start)
        XCTAssertGreaterThan(corrected, start)
        XCTAssertEqual(corrected.timeIntervalSince(start) / 3600, 19.0, accuracy: 0.001)
    }

    func testRolledOverIfNeededLeavesSameDayEndUnchanged() {
        let start = date(2026, 11, 10, 8)
        let end = date(2026, 11, 10, 17)
        XCTAssertEqual(rolledOverIfNeeded(end, after: start), end)
    }
}
