import XCTest
@testable import Fahrtkosten

/// Regressionsschutz: Automatisch angelegte Fahrten (GPS-Autostopp, Apple Watch) müssen die
/// in den Einstellungen hinterlegten Standard-Werte für Kraftstoffpreis/-verbrauch übernehmen,
/// genau wie die manuelle Eingabe über TripFormView. Bug: WatchSessionManager und der
/// GPS-Autostopp-Pfad wendeten diese Standardwerte bisher nicht (bzw. nur teilweise) an.
final class DefaultFuelDataTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let ud = UserDefaults.standard
        ud.removeObject(forKey: "defaultFuelType")
        ud.removeObject(forKey: "defaultFuelPrice.e10")
        ud.removeObject(forKey: "defaultConsumption.e10")
        ud.removeObject(forKey: "defaultFuelPrice.diesel")
        ud.removeObject(forKey: "defaultConsumption.diesel")
    }

    func testAppliesDefaultPriceAndConsumptionForCurrentFuelType() {
        let ud = UserDefaults.standard
        ud.set("diesel", forKey: "defaultFuelType")
        ud.set("1,65", forKey: "defaultFuelPrice.diesel")
        ud.set("5,5", forKey: "defaultConsumption.diesel")

        var trip = Trip(from: "A", to: "B", km: 50)
        applyDefaultFuelData(to: &trip)

        XCTAssertEqual(trip.fuelPricePerLiter ?? 0, 1.65, accuracy: 0.001)
        XCTAssertEqual(trip.fuelConsumption ?? 0, 5.5, accuracy: 0.001)
        XCTAssertEqual(trip.fuelTypeRaw, "diesel")
    }

    func testFallsBackToE10WhenNoTypeConfigured() {
        let ud = UserDefaults.standard
        ud.set("1,80", forKey: "defaultFuelPrice.e10")
        ud.set("6,0", forKey: "defaultConsumption.e10")

        var trip = Trip(from: "A", to: "B", km: 50)
        applyDefaultFuelData(to: &trip)

        XCTAssertEqual(trip.fuelPricePerLiter ?? 0, 1.80, accuracy: 0.001)
        XCTAssertEqual(trip.fuelTypeRaw, "e10")
    }

    func testLeavesFuelDataNilWhenNoDefaultsConfigured() {
        var trip = Trip(from: "A", to: "B", km: 50)
        applyDefaultFuelData(to: &trip)

        XCTAssertNil(trip.fuelPricePerLiter)
        XCTAssertNil(trip.fuelConsumption)
    }

    func testSkipsHybridRatherThanApplyingWrongValue() {
        let ud = UserDefaults.standard
        ud.set("hybrid", forKey: "defaultFuelType")
        ud.set("1,70", forKey: "defaultFuelPrice.hybrid")

        var trip = Trip(from: "A", to: "B", km: 50)
        applyDefaultFuelData(to: &trip)

        XCTAssertNil(trip.fuelPricePerLiter)
        XCTAssertNil(trip.fuelTypeRaw)
    }
}
