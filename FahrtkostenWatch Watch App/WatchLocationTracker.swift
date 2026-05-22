import Foundation
import CoreLocation
import Combine
import WatchKit

// Leichtgewichtiger GPS-Tracker für die Watch
final class WatchLocationTracker: NSObject, ObservableObject {

    @Published var km: Double = 0
    @Published var elapsed: Int = 0
    @Published var speed: Double = 0         // km/h (aktuell)
    @Published var averageSpeed: Double = 0  // km/h (Durchschnitt)
    @Published var isTracking = false
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String? = nil

    private let manager = CLLocationManager()
    private var locations: [CLLocation] = []
    private var startedAt: Date?
    private var timer: Timer?
    private var extendedSession: WKExtendedRuntimeSession?
    private(set) var startTime: Date?

    var startCoordinate: CLLocationCoordinate2D? { locations.first?.coordinate }
    var endCoordinate: CLLocationCoordinate2D? { locations.last?.coordinate }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        authStatus = manager.authorizationStatus
    }

    func start() {
        locations = []
        km = 0
        elapsed = 0
        speed = 0
        averageSpeed = 0
        errorMessage = nil
        startTime = Date()
        startedAt = Date()

        switch manager.authorizationStatus {
        case .notDetermined:
            isTracking = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isTracking = true
            manager.startUpdatingLocation()
            startTimer()
            startExtendedSession()
        default:
            errorMessage = "Kein GPS-Zugriff"
            isTracking = false
        }
    }

    struct GPSResult {
        let startLat: Double
        let startLon: Double
        let endLat: Double
        let endLon: Double
        let km: Double
        let startTime: Date
    }

    func stop() -> GPSResult {
        manager.stopUpdatingLocation()
        stopTimer()
        extendedSession?.invalidate()
        extendedSession = nil
        isTracking = false
        speed = 0
        averageSpeed = 0
        let start = startCoordinate
        let end = endCoordinate
        return GPSResult(
            startLat: start?.latitude ?? 0,
            startLon: start?.longitude ?? 0,
            endLat:   end?.latitude ?? 0,
            endLon:   end?.longitude ?? 0,
            km:       km,
            startTime: startTime ?? Date()
        )
    }

    // MARK: - Extended Runtime Session (Background GPS)

    private func startExtendedSession() {
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
        extendedSession?.start()
    }

    private func startTimer() {
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let s = self.startedAt else { return }
            DispatchQueue.main.async { self.elapsed = Int(Date().timeIntervalSince(s)) }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchLocationTracker: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations newLocations: [CLLocation]) {
        let valid = newLocations.filter { $0.horizontalAccuracy > 0 && $0.horizontalAccuracy < 65 }
        guard !valid.isEmpty else { return }

        // Geschwindigkeit berechnen BEVOR neue Locations hinzugefügt werden
        var speedKmh: Double = 0

        // 1. Versuch: CLLocation.speed (nativ, wenn verfügbar)
        let rawSpeed = valid.last?.speed ?? -1
        if rawSpeed >= 0 {
            speedKmh = rawSpeed * 3.6
        }
        // 2. Fallback: Geschwindigkeit aus letzten zwei Punkten berechnen
        //    (auf watchOS liefert CLLocation.speed oft -1)
        else if let prev = locations.last, let curr = valid.last {
            let timeDiff = curr.timestamp.timeIntervalSince(prev.timestamp)
            if timeDiff > 0.5 && timeDiff < 30 {
                let distance = curr.distance(from: prev)
                speedKmh = (distance / timeDiff) * 3.6
                // Unrealistische Werte filtern (> 250 km/h)
                if speedKmh > 250 { speedKmh = 0 }
            }
        }

        locations.append(contentsOf: valid)

        var dist = 0.0
        for i in 1..<locations.count { dist += locations[i].distance(from: locations[i-1]) }

        // Durchschnittsgeschwindigkeit: Gesamtstrecke / Gesamtzeit
        let distKm = dist / 1000.0
        var avgKmh: Double = 0
        if let start = startedAt {
            let totalHours = Date().timeIntervalSince(start) / 3600.0
            if totalHours > 0.001 { // mind. ~4 Sekunden
                avgKmh = distKm / totalHours
            }
        }

        DispatchQueue.main.async {
            self.km = distKm
            self.speed = speedKmh
            self.averageSpeed = avgKmh
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        guard isTracking else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            if timer == nil { startTimer() }
            if extendedSession == nil { startExtendedSession() }
        case .denied, .restricted:
            isTracking = false
            errorMessage = "GPS-Zugriff verweigert"
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let e = error as? CLError, e.code == .locationUnknown { return }
        DispatchQueue.main.async { self.errorMessage = "GPS-Fehler: \(error.localizedDescription)" }
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension WatchLocationTracker: WKExtendedRuntimeSessionDelegate {

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Kurz vor Ablauf neues Session-Objekt starten
        startExtendedSession()
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                 didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                 error: Error?) {
        // Nur wenn noch aktiv und nicht durch explizites Stop invalidiert: neue Session versuchen
        if isTracking {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startExtendedSession()
            }
        }
    }
}
