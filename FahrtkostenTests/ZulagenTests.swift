import XCTest
@testable import Fahrtkosten

final class ZulagenTests: XCTestCase {

    private var store: DataStore!

    override func setUp() {
        super.setUp()
        store = DataStore()
        store.wochenendzulageEnabled  = true
        store.monteurszulageEnabled   = true
        store.eurChfRate              = 0.93
        store.wochenendzulageInland   = 60
        store.wochenendzulageSchweiz  = 90
        store.wochenendzulageAusland  = 72
        store.monteurszulageInland    = 12
        store.monteurszulageSchweiz   = 18
        store.monteurszulageAusland   = 50
    }

    // MARK: - Helpers

    /// 12 Uhr mittags in Berlin, damit die Kalendertag-/Wochentagsermittlung unabhängig
    /// von der Zeitzone der Testmaschine ist.
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func meal(
        day: Date,
        region: TravelRegion,
        hours: Double,
        workedAtPlant: Bool = false,
        isHoliday: Bool = false,
        isTraining: Bool = false,
        weekendAwayOnly: Bool = false
    ) -> MealEntry {
        MealEntry(
            date: day,
            startTime: day,
            endTime: day.addingTimeInterval(hours * 3600),
            note: "",
            region: region,
            excludeTrips: true, // totalWorkHours() soll nur meal.hours verwenden, keine Fahrten
            workedAtPlant: workedAtPlant,
            isHoliday: isHoliday,
            isTraining: isTraining,
            weekendAwayOnly: weekendAwayOnly
        )
    }

    // MARK: - Wochenendzulage

    func testWochenendzulageOnSaturdayInland() {
        let saturday = date(2026, 10, 31)
        let m = meal(day: saturday, region: .inland, hours: 8)
        XCTAssertEqual(store.wochenendzulage(for: m), 60)
    }

    func testWochenendzulageOnWeekdayIsZero() {
        let monday = date(2026, 10, 26)
        let m = meal(day: monday, region: .inland, hours: 8)
        XCTAssertEqual(store.wochenendzulage(for: m), 0)
    }

    func testWochenendzulageDisabledByToggle() {
        store.wochenendzulageEnabled = false
        let saturday = date(2026, 10, 31)
        let m = meal(day: saturday, region: .inland, hours: 8)
        XCTAssertEqual(store.wochenendzulage(for: m), 0)
    }

    func testWochenendzulageSkippedForTraining() {
        let saturday = date(2026, 10, 31)
        let m = meal(day: saturday, region: .inland, hours: 8, isTraining: true)
        XCTAssertEqual(store.wochenendzulage(for: m), 0)
    }

    func testWochenendzulageSkippedForWeekendAwayOnly() {
        let saturday = date(2026, 10, 31)
        let m = meal(day: saturday, region: .inland, hours: 8, weekendAwayOnly: true)
        XCTAssertEqual(store.wochenendzulage(for: m), 0)
    }

    func testWochenendzulageOnHolidayWeekday() {
        let monday = date(2026, 10, 26)
        let m = meal(day: monday, region: .inland, hours: 8, isHoliday: true)
        XCTAssertEqual(store.wochenendzulage(for: m), 60)
    }

    func testWochenendzulageAuslandUsesSchweizRateWhenWorkedAtPlant() {
        let saturday = date(2026, 10, 31)
        let m = meal(day: saturday, region: .ausland, hours: 8, workedAtPlant: true)
        XCTAssertEqual(store.wochenendzulage(for: m), 90 / 0.93, accuracy: 0.0001)
    }

    func testWochenendzulageAuslandUsesAuslandRateWhenNotWorkedAtPlant() {
        let saturday = date(2026, 10, 31)
        let m = meal(day: saturday, region: .ausland, hours: 8, workedAtPlant: false)
        XCTAssertEqual(store.wochenendzulage(for: m), 72)
    }

    // MARK: - Monteurszulage

    func testMonteurszulageBelow3HoursIsZero() {
        let m = meal(day: date(2026, 10, 26), region: .inland, hours: 2)
        XCTAssertEqual(store.monteurszulage(for: m), 0)
    }

    func testMonteurszulageHalfRateBetween3And6Hours() {
        let m = meal(day: date(2026, 10, 26), region: .inland, hours: 4)
        XCTAssertEqual(store.monteurszulage(for: m), 6) // 12 € * 0.5
    }

    func testMonteurszulageFullRateFrom6Hours() {
        let m = meal(day: date(2026, 10, 26), region: .inland, hours: 6)
        XCTAssertEqual(store.monteurszulage(for: m), 12)
    }

    func testMonteurszulageDisabledByToggle() {
        store.monteurszulageEnabled = false
        let m = meal(day: date(2026, 10, 26), region: .inland, hours: 8)
        XCTAssertEqual(store.monteurszulage(for: m), 0)
    }

    func testMonteurszulageZeroForWeekendAwayOnly() {
        let m = meal(day: date(2026, 10, 26), region: .inland, hours: 8, weekendAwayOnly: true)
        XCTAssertEqual(store.monteurszulage(for: m), 0)
    }

    func testMonteurszulageSchweizRegionUsesSchweizRateRegardlessOfPlant() {
        let m = meal(day: date(2026, 10, 26), region: .schweiz, hours: 8)
        XCTAssertEqual(store.monteurszulage(for: m), 18 / 0.93, accuracy: 0.0001)
    }
}
