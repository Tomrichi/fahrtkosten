import Foundation
import CoreLocation
import Combine
import MapKit
import UIKit
import ActivityKit

// MARK: - Live Activity Attributes
// activityType-String muss mit FahrtkostenWidgetLiveActivity.swift übereinstimmen
nonisolated struct FahrtkostenGPSAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var km: Double
        var elapsedSeconds: Int
        var speedKmh: Double
    }
    var startedAt: Date
    static var activityType: String { "de.tommwagner.fahrtkosten.gpstrip" }
}

// MARK: - Live Activity Manager
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}
    private var currentActivity: Activity<FahrtkostenGPSAttributes>?

    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard currentActivity == nil else { return }
        let attrs   = FahrtkostenGPSAttributes(startedAt: Date())
        let state   = FahrtkostenGPSAttributes.ContentState(km: 0, elapsedSeconds: 0, speedKmh: 0)
        let content = ActivityContent(state: state, staleDate: nil)
        currentActivity = try? Activity.request(attributes: attrs, content: content, pushType: nil)
    }

    func update(km: Double, elapsedSeconds: Int, speedKmh: Double) {
        guard let activity = currentActivity else { return }
        let state   = FahrtkostenGPSAttributes.ContentState(km: km, elapsedSeconds: elapsedSeconds, speedKmh: speedKmh)
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity.update(content) }
    }

    func stop() {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}

// MARK: - LocationTracker

// Kein Equatable → kein MainActor-Isolations-Konflikt in Swift 6
enum LocationTrackerPhase {
    case idle, waitingForPermission, tracking, paused, geocoding
}

final class LocationTracker: NSObject, ObservableObject {

    /// Prozessweiter Singleton: GPS-Aufzeichnung darf nicht an die Lebensdauer einer
    /// SwiftUI-View gebunden sein, da CarPlay die App starten kann, ohne dass je die
    /// Telefon-UI (WindowGroup/ContentView/FahrtenView) gerendert wird.
    static let shared = LocationTracker()

    @Published var phase: LocationTrackerPhase = .idle
    @Published var totalKm: Double             = 0
    @Published var elapsedSeconds: Int         = 0
    @Published var currentSpeedKmh: Double     = 0
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var currentLocation: CLLocation?
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []

    private let manager        = CLLocationManager()
    private var locations      : [CLLocation] = []
    private var startedAt      : Date?
    /// Tatsächlicher Startzeitpunkt der laufenden/letzten Aufzeichnung
    /// (für die gespeicherte Fahrt – damit die echte Uhrzeit übernommen wird)
    var tripStartDate: Date? { startedAt }
    private var timer          : Timer?
    private var carPlayTimer   : Timer?          // eigene Referenz, damit der Timer nicht freigegeben wird
    private var geocodeTask    : Task<Void, Never>?
    private var bgTaskID       : UIBackgroundTaskIdentifier = .invalid
    private var stationaryTimer   : Timer?
    private let pauseAfterSeconds = 300              // 5 Min Stillstand → Pause
    private var lastMovedAt       : Date?
    private var pausedSeconds     : Int = 0          // aufgelaufene Pausenzeit (wird nicht gezählt)
    private var pausedAt          : Date?            // Zeitpunkt des Pausierens

    private override init() {
        super.init()
        manager.delegate                           = self
        manager.desiredAccuracy                    = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter                     = 10
        manager.activityType                       = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        authStatus = manager.authorizationStatus
    }

    // Computed helpers – kein == nötig
    var isTracking:  Bool { if case .tracking  = phase { return true }; return false }
    var isPaused:    Bool { if case .paused    = phase { return true }; return false }
    var isGeocoding: Bool { if case .geocoding = phase { return true }; return false }
    var isIdle:      Bool { if case .idle       = phase { return true }; return false }
    var isActive:    Bool { isTracking || isPaused }

    func requestAndStart() {
        // Läuft bereits eine Aufzeichnung (z. B. über CarPlay gestartet) → nicht zurücksetzen,
        // sonst gehen bisherige Strecke/Pause verloren, wenn das Sheet erneut erscheint.
        guard !isActive else { return }
        errorMessage = nil
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Bereits berechtigt → sofort starten
            startInternal()
        case .notDetermined:
            // Noch keine Entscheidung → Dialog anzeigen
            phase = .waitingForPermission
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "Standortzugriff verweigert.\nBitte in Einstellungen → Datenschutz → Ortungsdienste aktivieren."
        @unknown default:
            break
        }
    }

    func stopAndGeocode(completion: @escaping (String, String, Double) -> Void) {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        stopTimer()
        stopCarPlayUpdates()
        stationaryTimer?.invalidate()
        stationaryTimer = nil
        pausedAt = nil
        UIApplication.shared.isIdleTimerDisabled = false
        geocodeTask?.cancel()

        let km       = totalKm
        let startLoc = locations.first
        let endLoc   = locations.last
        phase        = .geocoding

        LiveActivityManager.shared.stop()

        bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "Geocoding") { [weak self] in
            guard let self else { return }
            UIApplication.shared.endBackgroundTask(self.bgTaskID)
            self.bgTaskID = .invalid
        }

        geocodeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let (fromAddr, toAddr) = await self.geocodeSequential(start: startLoc, end: endLoc)
            self.phase = .idle
            UIApplication.shared.endBackgroundTask(self.bgTaskID)
            self.bgTaskID = .invalid
            completion(fromAddr, toAddr, km)
        }
    }

    private func startInternal() {
        locations        = []
        routeCoordinates = []
        currentLocation  = nil
        totalKm          = 0
        elapsedSeconds   = 0
        pausedSeconds    = 0
        pausedAt         = nil
        startedAt        = Date()
        errorMessage     = nil
        lastMovedAt      = Date()
        phase            = .tracking

        UIApplication.shared.isIdleTimerDisabled = true
        manager.allowsBackgroundLocationUpdates  = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        startTimer()
        startCarPlayUpdates()
        Task { @MainActor in LiveActivityManager.shared.start() }
        AppLogger.shared.log("GPS-Aufzeichnung gestartet")
    }

    private func startTimer() {
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startedAt else { return }
            DispatchQueue.main.async {
                // Pausierte Zeit nicht mitzählen
                guard !self.isPaused else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start)) - self.pausedSeconds
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func geocodeSequential(start: CLLocation?, end: CLLocation?) async -> (String, String) {
        guard let startLoc = start else { return ("", "") }
        let fromAddr = await reverseGeocode(location: startLoc)
        guard let endLoc = end,
              abs(endLoc.coordinate.latitude  - startLoc.coordinate.latitude)  > 0.0001 ||
              abs(endLoc.coordinate.longitude - startLoc.coordinate.longitude) > 0.0001
        else { return (fromAddr, "") }
        return (fromAddr, await reverseGeocode(location: endLoc))
    }

    private func reverseGeocode(location: CLLocation) async -> String {
        guard let request = MKReverseGeocodingRequest(location: location) else { return "" }
        do {
            let mapItems = try await request.mapItems
            return Self.formatMapItem(mapItems.first)
        } catch {
            AppLogger.shared.logError("Geocoding: \(error.localizedDescription)")
            return ""
        }
    }

    private static func formatMapItem(_ item: MKMapItem?) -> String {
        guard let item else { return "" }
        return item.address?.fullAddress ?? ""
    }

    private static let appGroup = "group.de.tommwagner.fahrtkosten"

    func startCarPlayUpdates() {
        writeGPSStateToAppGroup(recording: true)

        carPlayTimer?.invalidate()
        carPlayTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] t in
            guard let self, self.isTracking else { t.invalidate(); return }
            self.writeGPSStateToAppGroup(recording: true)
        }
        RunLoop.main.add(carPlayTimer!, forMode: .common)
    }

    private func stopCarPlayUpdates() {
        carPlayTimer?.invalidate()
        carPlayTimer = nil
        writeGPSStateToAppGroup(recording: false)
    }

    private func writeGPSStateToAppGroup(recording: Bool) {
        guard let ud = UserDefaults(suiteName: Self.appGroup) else { return }
        ud.set(recording,      forKey: "gpsIsRecording")
        ud.set(totalKm,        forKey: "gpsKm")
        ud.set(elapsedSeconds, forKey: "gpsElapsed")
        // Live Activity aktualisieren
        if recording {
            Task { @MainActor in LiveActivityManager.shared.update(
                km: self.totalKm, elapsedSeconds: self.elapsedSeconds, speedKmh: self.currentSpeedKmh) }
        }
    }
}

extension LocationTracker: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations newLocations: [CLLocation]) {
        guard isTracking else { return }
        let valid = newLocations.filter { $0.horizontalAccuracy > 0 && $0.horizontalAccuracy < 65 }
        guard !valid.isEmpty else { return }
        locations.append(contentsOf: valid)
        currentLocation  = valid.last
        routeCoordinates = locations.map { $0.coordinate }
        var dist = 0.0
        for i in 1 ..< locations.count { dist += locations[i].distance(from: locations[i-1]) }
        DispatchQueue.main.async { self.totalKm = dist / 1000.0 }

        // Pause-Logik: Stillstand > 5 Min → pausieren, Bewegung → weiterfahren
        if let lastLocation = valid.last {
            let speedKmh = max(0, lastLocation.speed) * 3.6
            DispatchQueue.main.async { self.currentSpeedKmh = speedKmh }

            if speedKmh > 2.0 {
                // Bewegung erkannt
                lastMovedAt = Date()
                stationaryTimer?.invalidate()
                stationaryTimer = nil

                if isPaused {
                    // Automatisch fortsetzen
                    DispatchQueue.main.async { self.resumeTracking() }
                }
            } else if isTracking, stationaryTimer == nil {
                // Stillstand – Pause-Timer starten
                stationaryTimer = Timer.scheduledTimer(
                    withTimeInterval: TimeInterval(pauseAfterSeconds),
                    repeats: false
                ) { [weak self] _ in
                    guard let self, self.isTracking else { return }
                    DispatchQueue.main.async { self.pauseTracking() }
                }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if case .waitingForPermission = phase {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: startInternal()
            case .denied, .restricted:
                phase = .idle
                errorMessage = "Standortzugriff verweigert."
            default: break
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clErr = error as? CLError, clErr.code == .locationUnknown { return }
        let msg = "GPS-Fehler: \(error.localizedDescription)"
        AppLogger.shared.logError(msg)
        DispatchQueue.main.async { self.errorMessage = msg }
    }

    // MARK: - Pause / Resume

    private func pauseTracking() {
        guard isTracking else { return }
        phase    = .paused
        pausedAt = Date()
        // Auto-Stop nach 15 Minuten Pause (Fahrt vermutlich beendet)
        DispatchQueue.main.asyncAfter(deadline: .now() + 900) { [weak self] in
            guard let self, self.isPaused else { return }
            self.stopAndGeocode { _, _, _ in }
        }
        stationaryTimer?.invalidate()
        stationaryTimer = nil

        // UI informieren
        NotificationCenter.default.post(name: .gpsTrackingPaused, object: nil)
        AppLogger.shared.log("GPS-Aufzeichnung pausiert (Stillstand > \(pauseAfterSeconds / 60) Min)")

    }

    func resumeTracking() {
        guard isPaused else { return }
        // Pausierte Sekunden aufaddieren
        if let p = pausedAt {
            pausedSeconds += Int(Date().timeIntervalSince(p))
        }
        pausedAt = nil
        phase = .tracking
        lastMovedAt = Date()

        NotificationCenter.default.post(name: .gpsTrackingResumed, object: nil)
        AppLogger.shared.log("GPS-Aufzeichnung fortgesetzt")
    }
}

extension Notification.Name {
    static let gpsTrackingStatusChanged = Notification.Name("gpsTrackingStatusChanged")
    static let gpsTrackingPaused        = Notification.Name("gpsTrackingPaused")
    static let gpsTrackingResumed       = Notification.Name("gpsTrackingResumed")
}
