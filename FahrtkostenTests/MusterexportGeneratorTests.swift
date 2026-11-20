import XCTest
@testable import Fahrtkosten

/// Erzeugt einen echten PDF-Musterexport mit Fahrtenbuch-Demodaten für Kundenanfragen
/// (Kilometerstände, Geschäftlich/Privat, Änderungsprotokoll-Anhang). Kein Teil der
/// regulären Testsuite – schreibt die PDF-Datei in den temporären Ordner und gibt den Pfad
/// über XCTAttachment aus, damit er aus dem xcresult-Bundle extrahiert werden kann.
final class MusterexportGeneratorTests: XCTestCase {

    func testGenerateMusterexport() {
        let store = DataStore()
        store.trips = []
        store.meals = []
        store.changeLog = []
        store.fahrtenbuchModusEnabled = true
        store.kmRate = 0.38
        RollbackGuard.resetForTesting()

        let cal = Calendar(identifier: .gregorian)
        func d(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
        }

        var odo = 45000.0
        func trip(_ from: String, _ to: String, _ km: Double, art: TripArt,
                   date day: Date, start: Date, end: Date, purpose: String) {
            let t = Trip(from: from, to: to, date: day, km: km, art: art,
                         startTime: start, endTime: end, purpose: purpose,
                         odometerStart: odo, odometerEnd: odo + km)
            odo += km
            store.addTrip(t)
        }

        trip("Rathausplatz 1, 70173 Stuttgart", "Industriestraße 22, 73033 Göppingen", 48.0, art: .geschaeftlich,
             date: d(2026, 9, 15, 8), start: d(2026, 9, 15, 8), end: d(2026, 9, 15, 8, 55), purpose: "Kundentermin")
        trip("Industriestraße 22, 73033 Göppingen", "Rathausplatz 1, 70173 Stuttgart", 48.0, art: .geschaeftlich,
             date: d(2026, 9, 15, 16), start: d(2026, 9, 15, 16), end: d(2026, 9, 15, 16, 50), purpose: "Kundentermin")
        trip("Rathausplatz 1, 70173 Stuttgart", "Globus Markthalle, 70173 Stuttgart", 12.0, art: .privat,
             date: d(2026, 9, 28, 10), start: d(2026, 9, 28, 10), end: d(2026, 9, 28, 10, 20), purpose: "")
        trip("Rathausplatz 1, 70173 Stuttgart", "Hauptstraße 5, 86150 Augsburg", 112.0, art: .geschaeftlich,
             date: d(2026, 10, 5, 7), start: d(2026, 10, 5, 7), end: d(2026, 10, 5, 8, 35), purpose: "Montageeinsatz")
        trip("Hauptstraße 5, 86150 Augsburg", "Rathausplatz 1, 70173 Stuttgart", 112.0, art: .geschaeftlich,
             date: d(2026, 10, 5, 17), start: d(2026, 10, 5, 17), end: d(2026, 10, 5, 18, 30), purpose: "Montageeinsatz")
        trip("Rathausplatz 1, 70173 Stuttgart", "Werksgelände, 71332 Waiblingen", 22.0, art: .geschaeftlich,
             date: d(2026, 10, 20, 9), start: d(2026, 10, 20, 9), end: d(2026, 10, 20, 9, 25), purpose: "Abnahme")
        trip("Rathausplatz 1, 70173 Stuttgart", "Messe, 70629 Stuttgart", 18.0, art: .geschaeftlich,
             date: d(2026, 11, 3, 8), start: d(2026, 11, 3, 8), end: d(2026, 11, 3, 8, 30), purpose: "Fachmesse")
        trip("Messe, 70629 Stuttgart", "Rathausplatz 1, 70173 Stuttgart", 18.0, art: .geschaeftlich,
             date: d(2026, 11, 3, 17), start: d(2026, 11, 3, 17), end: d(2026, 11, 3, 17, 30), purpose: "Fachmesse")
        trip("Rathausplatz 1, 70173 Stuttgart", "Flughafen Stuttgart, 70629 Stuttgart", 15.0, art: .privat,
             date: d(2026, 11, 12, 6), start: d(2026, 11, 12, 6), end: d(2026, 11, 12, 6, 20), purpose: "")

        store.addMeal(MealEntry(date: d(2026, 9, 15, 8), startTime: d(2026, 9, 15, 8), endTime: d(2026, 9, 15, 16, 50),
                                 note: "Kundentermin Göppingen", region: .inland))
        store.addMeal(MealEntry(date: d(2026, 10, 5, 7), startTime: d(2026, 10, 5, 7), endTime: d(2026, 10, 5, 18, 30),
                                 note: "Montageeinsatz Augsburg", region: .inland))

        // Eine nachträgliche Änderung (Korrektur) + eine Löschung, damit der Anhang
        // auch "Geändert"/"Gelöscht"-Einträge zeigt, nicht nur "Angelegt".
        if var waiblingen = store.trips.first(where: { $0.to.contains("Waiblingen") }) {
            waiblingen.km = 24.0
            waiblingen.odometerEnd = (waiblingen.odometerStart ?? 0) + 24.0
            store.updateTrip(waiblingen)
        }
        if let globus = store.trips.first(where: { $0.to.contains("Globus") }) {
            store.deleteTrip(globus.id)
        }

        let data = PDFExportService.generatePDF(
            store: store, trips: store.trips, meals: store.meals, hotels: [],
            vehicleCosts: [], reiseSpesen: [], privateExpenses: [],
            zeitraum: "September bis November 2026"
        )
        XCTAssertFalse(data.isEmpty)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Fahrtkosten_Musterexport_Fahrtenbuchmodus.pdf")
        try? data.write(to: url)

        let attachment = XCTAttachment(contentsOfFile: url)
        attachment.name = "Fahrtkosten_Musterexport_Fahrtenbuchmodus.pdf"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
