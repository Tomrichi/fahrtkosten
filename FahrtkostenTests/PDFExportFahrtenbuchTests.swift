import XCTest
@testable import Fahrtkosten

/// Smoke-Test: PDF-Export mit aktivem Fahrtenbuchmodus (Kilometerstand-Zeile + Anhang
/// Änderungsprotokoll) darf nicht abstürzen und muss ein nicht-leeres PDF liefern.
final class PDFExportFahrtenbuchTests: XCTestCase {

    func testGeneratePDFWithFahrtenbuchModusAndChangeLog() {
        let store = DataStore()
        store.fahrtenbuchModusEnabled = true
        store.trips = []
        store.meals = []
        store.changeLog = []

        let trip = Trip(
            from: "Start", to: "Ziel", date: Date(), km: 42, purpose: "Kundentermin",
            odometerStart: 10000, odometerEnd: 10042
        )
        store.addTrip(trip) // erzeugt automatisch einen changeLog-Eintrag (Modus aktiv)

        let data = PDFExportService.generatePDF(
            store: store, trips: store.trips, meals: [], hotels: [],
            vehicleCosts: [], reiseSpesen: [], privateExpenses: [], zeitraum: "Test"
        )

        XCTAssertFalse(data.isEmpty)
        XCTAssertGreaterThan(data.count, 500, "PDF wirkt verdächtig klein / möglicherweise leer gerendert")
        XCTAssertFalse(store.changeLog.isEmpty)
    }
}
