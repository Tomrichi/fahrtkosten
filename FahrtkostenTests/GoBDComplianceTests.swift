import XCTest
import CoreLocation
@testable import Fahrtkosten

/// Deckt die GoBD-Nachbesserungen ab: GPS-Routen-Kodierung (encodeRoute) und die
/// Zeitnähe-Prüfung (wasCreatedLate), die den "angelegt"-Zeitstempel aus dem
/// Änderungsprotokoll gegen das (frei editierbare) Fahrtdatum abgleicht.
final class GoBDComplianceTests: XCTestCase {

    private var store: DataStore!

    override func setUp() {
        super.setUp()
        store = DataStore()
        store.fahrtenbuchModusEnabled = false
        store.trips = []
        store.changeLog = []
    }

    // MARK: - encodeRoute

    func testEncodeRouteReturnsNilForSingleOrNoPoints() {
        XCTAssertNil(encodeRoute([]))
        XCTAssertNil(encodeRoute([CLLocationCoordinate2D(latitude: 48.775, longitude: 9.182)]))
    }

    func testEncodeRouteJoinsPointsWithSemicolon() {
        let coords = [
            CLLocationCoordinate2D(latitude: 48.775, longitude: 9.182),
            CLLocationCoordinate2D(latitude: 48.776, longitude: 9.183)
        ]
        XCTAssertEqual(encodeRoute(coords), "48.77500,9.18200;48.77600,9.18300")
    }

    func testEncodeRouteDecimatesLongRoutesToMaxPoints() {
        let coords = (0..<1000).map { CLLocationCoordinate2D(latitude: Double($0) / 1000, longitude: 9.0) }
        let encoded = encodeRoute(coords, maxPoints: 200)!
        let pointCount = encoded.split(separator: ";").count
        XCTAssertLessThanOrEqual(pointCount, 200)
        XCTAssertGreaterThan(pointCount, 1)
    }

    // MARK: - wasCreatedLate

    private func sampleTrip(date: Date) -> Trip {
        Trip(from: "A", to: "B", date: date, km: 10)
    }

    func testNotLateWithoutChangeLogEntry() {
        let trip = sampleTrip(date: Date().addingTimeInterval(-30 * 86400))
        XCTAssertFalse(store.wasCreatedLate(trip))
    }

    func testNotLateWhenCreatedWithinThreshold() {
        let tripDate = Date().addingTimeInterval(-3 * 86400)
        let trip = sampleTrip(date: tripDate)
        store.changeLog = [ChangeLogEntry(
            id: UUID(), entityType: .trip, entityID: trip.id, changeType: .created,
            timestamp: Date(), snapshotBefore: nil, snapshotAfter: nil,
            previousHash: "genesis", hash: "abc"
        )]
        XCTAssertFalse(store.wasCreatedLate(trip))
    }

    func testLateWhenCreatedAfterThreshold() {
        let tripDate = Date().addingTimeInterval(-10 * 86400)
        let trip = sampleTrip(date: tripDate)
        store.changeLog = [ChangeLogEntry(
            id: UUID(), entityType: .trip, entityID: trip.id, changeType: .created,
            timestamp: Date(), snapshotBefore: nil, snapshotAfter: nil,
            previousHash: "genesis", hash: "abc"
        )]
        XCTAssertTrue(store.wasCreatedLate(trip))
    }
}
