import XCTest
@testable import Fahrtkosten

/// Regressionsschutz für den Bugfix: Übersicht, Statistik, PDF- und CSV-Export müssen alle
/// dieselbe, auf geschäftliche Fahrten beschränkte Erstattungssumme verwenden
/// (tripReimbursement in Helpers.swift), statt jeweils eigene, ungefilterte Summen zu bilden.
final class TripReimbursementTests: XCTestCase {

    func testOnlyBusinessTripsAreReimbursed() {
        let business = Trip(from: "A", to: "B", km: 100, art: .geschaeftlich)
        let privat   = Trip(from: "C", to: "D", km: 50,  art: .privat)
        let result = tripReimbursement([business, privat], rate: 0.38)
        XCTAssertEqual(result, 38.0, accuracy: 0.001) // nur 100 km geschäftlich
    }

    func testEmptyListReturnsZero() {
        XCTAssertEqual(tripReimbursement([], rate: 0.38), 0)
    }

    func testAllPrivateReturnsZero() {
        let trips = [Trip(from: "A", to: "B", km: 20, art: .privat)]
        XCTAssertEqual(tripReimbursement(trips, rate: 0.38), 0)
    }

    func testMatchesDataStoreTotalKmAmount() {
        let store = DataStore()
        store.trips = []
        store.kmRate = 0.38
        let trips = [
            Trip(from: "A", to: "B", km: 100, art: .geschaeftlich),
            Trip(from: "C", to: "D", km: 50,  art: .privat)
        ]
        trips.forEach { store.addTrip($0) }
        XCTAssertEqual(tripReimbursement(store.trips, rate: store.kmRate), store.totalKmAmount, accuracy: 0.001)
    }
}
