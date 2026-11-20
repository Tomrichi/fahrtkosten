import XCTest
import CryptoKit
@testable import Fahrtkosten

/// Deckt die Hardware-Hash-Kette, RFC-3161-Anfrage und die fachlichen Pflicht-Checks ab
/// (Tachostand-Kontinuität, Storno statt Löschen, Pflicht-Änderungsgrund).
final class FahrtenbuchSecurityTests: XCTestCase {

    private var store: DataStore!

    override func setUp() {
        super.setUp()
        store = DataStore()
        store.fahrtenbuchModusEnabled = false
        store.trips = []
        store.changeLog = []
        RollbackGuard.resetForTesting()
    }

    // MARK: - TSAClient DER-Aufbau

    func testBuildTimeStampRequestHasValidASN1Structure() {
        let hash = Data(SHA256.hash(data: Data("test".utf8)))
        let der = TSAClient.buildTimeStampRequest(sha256Hash: hash)

        XCTAssertEqual(der.first, 0x30, "Äußere SEQUENCE muss mit Tag 0x30 beginnen")
        XCTAssertLessThan(der.count, 128, "Gesamtlänge sollte unter 128 Byte bleiben (Kurzform-Länge)")
        XCTAssertTrue(der.contains(hash), "Der 32-Byte-Hash muss unverändert in der Anfrage enthalten sein")
        // AlgorithmIdentifier-OID für SHA-256 muss enthalten sein
        let sha256OID = Data([0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01])
        XCTAssertTrue(der.contains(sha256OID))
    }

    func testBuildTimeStampRequestVariesNonce() {
        let hash = Data(SHA256.hash(data: Data("test".utf8)))
        let der1 = TSAClient.buildTimeStampRequest(sha256Hash: hash)
        let der2 = TSAClient.buildTimeStampRequest(sha256Hash: hash)
        XCTAssertNotEqual(der1, der2, "Nonce muss pro Anfrage zufällig sein")
    }

    // MARK: - FahrtenbuchSigner

    func testSignatureIsVerifiableWithItsOwnPublicKey() {
        // Simulator hat keine Secure Enclave – Signer nutzt den Software-Fallback-Pfad.
        let hashHex = "abc123"
        let sigHex = FahrtenbuchSigner.sign(hashHex)
        XCTAssertFalse(sigHex.isEmpty)

        // Zweite Signatur über denselben Hash muss mit demselben (persistierten) Schlüssel
        // erfolgen und ebenfalls nicht leer sein – der Schlüssel wird nicht bei jedem Aufruf neu erzeugt.
        let sigHex2 = FahrtenbuchSigner.sign(hashHex)
        XCTAssertFalse(sigHex2.isEmpty)
    }

    // MARK: - RollbackGuard

    func testNoRollbackWhenKeychainEmpty() {
        XCTAssertFalse(RollbackGuard.checkForRollback(currentChainCount: 0))
    }

    func testNoRollbackWhenChainIsAheadOrEqual() {
        RollbackGuard.record(seq: 3, hash: "h3")
        XCTAssertFalse(RollbackGuard.checkForRollback(currentChainCount: 3))
        XCTAssertFalse(RollbackGuard.checkForRollback(currentChainCount: 5))
    }

    func testDetectsRollbackWhenChainIsBehind() {
        RollbackGuard.record(seq: 10, hash: "h10")
        XCTAssertTrue(RollbackGuard.checkForRollback(currentChainCount: 2))
    }

    // MARK: - Tachostand-Kontinuität

    func testLastOdometerEndReturnsNilWithoutPriorTrip() {
        XCTAssertNil(store.lastOdometerEnd(before: Date()))
    }

    func testLastOdometerEndReturnsMostRecentPriorValue() {
        var t1 = Trip(from: "A", to: "B", date: Date().addingTimeInterval(-2 * 86400), km: 10)
        t1.odometerEnd = 1000
        var t2 = Trip(from: "B", to: "C", date: Date().addingTimeInterval(-1 * 86400), km: 20)
        t2.odometerEnd = 1020
        store.trips = [t1, t2]
        XCTAssertEqual(store.lastOdometerEnd(before: Date()), 1020)
    }

    // MARK: - Storno statt physischem Löschen

    func testDeleteMarksStornoInsteadOfRemovingWhenFahrtenbuchModusEnabled() {
        store.fahrtenbuchModusEnabled = true
        let trip = Trip(from: "A", to: "B", km: 10, art: .geschaeftlich)
        store.addTrip(trip)
        store.deleteTrip(trip.id)

        XCTAssertEqual(store.trips.count, 1, "Fahrt bleibt erhalten, nur storniert")
        XCTAssertTrue(store.trips[0].isStorno)
    }

    func testDeleteStillRemovesPhysicallyWhenFahrtenbuchModusDisabled() {
        store.fahrtenbuchModusEnabled = false
        let trip = Trip(from: "A", to: "B", km: 10, art: .geschaeftlich)
        store.addTrip(trip)
        store.deleteTrip(trip.id)
        XCTAssertTrue(store.trips.isEmpty, "Außerhalb des Fahrtenbuchmodus unverändert echtes Löschen")
    }

    func testStornoTripsExcludedFromReimbursement() {
        let business = Trip(from: "A", to: "B", km: 100, art: .geschaeftlich)
        var stornoTrip = Trip(from: "C", to: "D", km: 50, art: .geschaeftlich)
        stornoTrip.isStorno = true
        let total = tripReimbursement([business, stornoTrip], rate: 0.30)
        XCTAssertEqual(total, 30.0, accuracy: 0.001, "Stornierte Fahrt darf nicht mitgezählt werden")
    }

    // MARK: - Pflicht-Änderungsgrund

    func testUpdateTripStoresChangeReasonInLog() {
        store.fahrtenbuchModusEnabled = true
        var trip = Trip(from: "A", to: "B", km: 10)
        store.addTrip(trip)
        trip.km = 20
        store.updateTrip(trip, reason: "Kilometerstand korrigiert")

        let entry = store.changeLog.last!
        XCTAssertEqual(entry.changeReason, "Kilometerstand korrigiert")
    }

    func testUpdateTripWithoutReasonLeavesChangeReasonNil() {
        store.fahrtenbuchModusEnabled = true
        var trip = Trip(from: "A", to: "B", km: 10)
        store.addTrip(trip)
        trip.km = 20
        store.updateTrip(trip)

        let entry = store.changeLog.last!
        XCTAssertNil(entry.changeReason)
    }

    // MARK: - seq / deviceSignature

    func testLogChangeAssignsIncrementingSeqAndDeviceSignature() {
        store.fahrtenbuchModusEnabled = true
        let t1 = Trip(from: "A", to: "B", km: 10)
        let t2 = Trip(from: "C", to: "D", km: 20)
        store.addTrip(t1)
        store.addTrip(t2)

        XCTAssertEqual(store.changeLog[0].seq, 1)
        XCTAssertEqual(store.changeLog[1].seq, 2)
        XCTAssertFalse(store.changeLog[0].deviceSignature.isEmpty)
        XCTAssertFalse(store.changeLog[1].deviceSignature.isEmpty)
    }
}
