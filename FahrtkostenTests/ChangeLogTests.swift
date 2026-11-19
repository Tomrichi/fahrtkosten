import XCTest
@testable import Fahrtkosten

/// Deckt das unveränderliche, verkettete Änderungsprotokoll ab (Fahrtenbuchmodus):
/// kein Logging im Standardmodus, korrekte Hash-Verkettung, richtiger changeType.
final class ChangeLogTests: XCTestCase {

    private var store: DataStore!

    override func setUp() {
        super.setUp()
        store = DataStore()
        // DataStore persistiert über UserDefaults/iCloud – frühere Testläufe (oder die App
        // selbst) können bereits Daten hinterlassen haben. Für isolierte Tests explizit leeren.
        store.fahrtenbuchModusEnabled = false
        store.trips = []
        store.meals = []
        store.changeLog = []
    }

    private func sampleTrip() -> Trip {
        Trip(from: "A", to: "B", date: Date(), km: 10)
    }

    func testNoLoggingWhenFahrtenbuchModusDisabled() {
        let trip = sampleTrip()
        store.addTrip(trip)
        store.updateTrip(trip)
        store.deleteTrip(trip.id)
        XCTAssertTrue(store.changeLog.isEmpty)
    }

    func testCreatedEntryHasNoBeforeSnapshotAndGenesisPreviousHash() {
        store.fahrtenbuchModusEnabled = true
        let trip = sampleTrip()
        store.addTrip(trip)

        XCTAssertEqual(store.changeLog.count, 1)
        let entry = store.changeLog[0]
        XCTAssertEqual(entry.changeType, .created)
        XCTAssertEqual(entry.entityType, .trip)
        XCTAssertEqual(entry.entityID, trip.id)
        XCTAssertNil(entry.snapshotBefore)
        XCTAssertNotNil(entry.snapshotAfter)
        XCTAssertEqual(entry.previousHash, "genesis")
        XCTAssertFalse(entry.hash.isEmpty)
    }

    func testConsecutiveEntriesAreHashChained() {
        store.fahrtenbuchModusEnabled = true
        var trip = sampleTrip()
        store.addTrip(trip)
        trip.km = 25
        store.updateTrip(trip)
        store.deleteTrip(trip.id)

        XCTAssertEqual(store.changeLog.count, 3)
        XCTAssertEqual(store.changeLog[1].previousHash, store.changeLog[0].hash)
        XCTAssertEqual(store.changeLog[2].previousHash, store.changeLog[1].hash)

        // Alle Hashes sind untereinander verschieden (keine zufällige Kollision/Kopie).
        let hashes = Set(store.changeLog.map { $0.hash })
        XCTAssertEqual(hashes.count, 3)
    }

    func testUpdateEntryCapturesBeforeAndAfter() {
        store.fahrtenbuchModusEnabled = true
        var trip = sampleTrip()
        store.addTrip(trip)
        trip.km = 99
        store.updateTrip(trip)

        let entry = store.changeLog.last!
        XCTAssertEqual(entry.changeType, .updated)
        XCTAssertNotNil(entry.snapshotBefore)
        XCTAssertNotNil(entry.snapshotAfter)
    }

    func testDeleteEntryHasNoAfterSnapshot() {
        store.fahrtenbuchModusEnabled = true
        let trip = sampleTrip()
        store.addTrip(trip)
        store.deleteTrip(trip.id)

        let entry = store.changeLog.last!
        XCTAssertEqual(entry.changeType, .deleted)
        XCTAssertNotNil(entry.snapshotBefore)
        XCTAssertNil(entry.snapshotAfter)
    }

    func testDifferentEntityTypesAreLoggedIndependently() {
        store.fahrtenbuchModusEnabled = true
        store.addTrip(sampleTrip())
        store.addMeal(MealEntry(date: Date(), startTime: Date(), endTime: Date().addingTimeInterval(3600), note: "", region: .inland))

        XCTAssertEqual(store.changeLog.count, 2)
        XCTAssertEqual(store.changeLog[0].entityType, .trip)
        XCTAssertEqual(store.changeLog[1].entityType, .meal)
        // Zweiter Eintrag verkettet trotz unterschiedlichen Entitätstyps mit dem ersten.
        XCTAssertEqual(store.changeLog[1].previousHash, store.changeLog[0].hash)
    }
}
