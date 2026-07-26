import Foundation
import WatchConnectivity
import CoreLocation
import MapKit
import Combine

// MARK: - WatchSessionManager (iPhone-Seite)
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    private let session = WCSession.default
    private let groupDefaults = UserDefaults(suiteName: "group.de.tommwagner.fahrtkosten") ?? .standard

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Daten an Watch senden
    func sendContextToWatch() {
        guard session.activationState == .activated,
              session.isWatchAppInstalled else { return }

        let trips = loadTrips()
        let kmRate = groupDefaults.double(forKey: "kmRate").ifZero(0.38)
        let cal = Calendar.current
        let now = Date()

        let monthTrips = trips.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
        let monthKm    = monthTrips.reduce(0.0) { $0 + $1.km }
        let monthEuro  = monthKm * kmRate
        let tripCount  = monthTrips.count

        var activeFrom = ""
        var activeTo   = ""
        var hasActive  = false
        if let data = groupDefaults.data(forKey: "activeTrip"),
           let trip = try? JSONDecoder().decode(WatchTrip.self, from: data) {
            activeFrom = trip.from
            activeTo   = trip.to
            hasActive  = true
        }

        let context: [String: Any] = [
            "monthKm":    monthKm,
            "monthEuro":  monthEuro,
            "tripCount":  tripCount,
            "kmRate":     kmRate,
            "hasActive":  hasActive,
            "activeFrom": activeFrom,
            "activeTo":   activeTo,
            "lastUpdate": Date().timeIntervalSince1970
        ]

        try? session.updateApplicationContext(context)
    }

    // MARK: - Nachricht von Watch verarbeiten
    private func handleMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let action = message["action"] as? String else { return }

        switch action {

        case "startTrip":
            let from = message["from"] as? String ?? "Aktueller Standort"
            let to   = message["to"]   as? String ?? ""
            let trip = WatchTrip(from: from, to: to, startTime: Date())
            if let data = try? JSONEncoder().encode(trip) {
                groupDefaults.set(data, forKey: "activeTrip")
                groupDefaults.synchronize()
            }
            replyHandler?(["status": "ok"])
            sendContextToWatch()

        case "stopTrip":
            let km = message["km"] as? Double ?? 0
            guard var trip = loadActiveTrip() else { replyHandler?(["status": "ok"]); return }
            trip.km      = km
            trip.endTime = Date()

            var trips = loadTrips()
            let fullTrip = Trip(
                from: trip.from, to: trip.to,
                date: trip.startTime ?? Date(),
                km: km, note: "Via Apple Watch",
                startTime: trip.startTime, endTime: trip.endTime
            )
            trips.append(fullTrip)
            saveTrips(trips)
            groupDefaults.removeObject(forKey: "activeTrip")
            groupDefaults.synchronize()
            NotificationCenter.default.post(name: .watchDidSaveTrip, object: nil)
            replyHandler?(["status": "ok"])
            sendContextToWatch()

        case "startGPSTrip":
            // GPS-Fahrt markieren (Banner auf iPhone / Watch)
            let trip = WatchTrip(from: "GPS-Fahrt", to: "läuft…", startTime: Date())
            if let data = try? JSONEncoder().encode(trip) {
                groupDefaults.set(data, forKey: "activeTrip")
                groupDefaults.synchronize()
            }
            replyHandler?(["status": "ok"])
            sendContextToWatch()

        case "stopGPSTripWithCoords":
            let startLat  = message["startLat"]  as? Double ?? 0
            let startLon  = message["startLon"]  as? Double ?? 0
            let endLat    = message["endLat"]    as? Double ?? 0
            let endLon    = message["endLon"]    as? Double ?? 0
            let km        = message["km"]        as? Double ?? 0
            let startTS   = message["startTime"] as? Double ?? Date().timeIntervalSince1970
            let startTime = Date(timeIntervalSince1970: startTS)

            // Sofort antworten – Geocoding läuft im Hintergrund
            replyHandler?(["status": "ok"])

            let startLocation = CLLocation(latitude: startLat, longitude: startLon)
            let endLocation   = (endLat != 0 || endLon != 0)
                ? CLLocation(latitude: endLat, longitude: endLon) : nil

            Task {
                let fromAddr = await reverseGeocode(startLocation)
                let toAddr   = endLocation != nil ? await reverseGeocode(endLocation!) : ""

                await MainActor.run {
                    var trips = loadTrips()
                    let trip = Trip(
                        from:      fromAddr.isEmpty ? "Startort" : fromAddr,
                        to:        toAddr.isEmpty   ? "Zielort"  : toAddr,
                        date:      startTime,
                        km:        km,
                        note:      "GPS via Apple Watch",
                        startTime: startTime,
                        endTime:   Date()
                    )
                    trips.append(trip)
                    saveTrips(trips)
                    groupDefaults.removeObject(forKey: "activeTrip")
                    groupDefaults.synchronize()
                    NotificationCenter.default.post(name: .watchDidSaveTrip, object: nil)
                    sendContextToWatch()
                }
            }

        case "requestUpdate":
            replyHandler?(["status": "ok"])
            sendContextToWatch()

        default:
            replyHandler?(["status": "ok"])
        }
    }

    // MARK: - Reverse Geocoding
    private func reverseGeocode(_ location: CLLocation) async -> String {
        if #available(iOS 26.0, *) {
            return await withCheckedContinuation { continuation in
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    continuation.resume(returning: ""); return
                }
                request.getMapItems { mapItems, _ in
                    guard let item = mapItems?.first else {
                        continuation.resume(returning: ""); return
                    }
                    var parts: [String] = []
                    if let name = item.name, !name.isEmpty {
                        parts.append(name)
                    } else if let short = item.address?.shortAddress, !short.isEmpty {
                        parts.append(short)
                    }
                    if let city = item.addressRepresentations?.cityName, !city.isEmpty {
                        parts.append(city)
                    }
                    continuation.resume(returning: parts.joined(separator: ", "))
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    guard let pm = placemarks?.first, error == nil else {
                        continuation.resume(returning: ""); return
                    }
                    var parts: [String] = []
                    if let name = pm.name, !name.isEmpty {
                        parts.append(name)
                    } else if let street = pm.thoroughfare {
                        parts.append(street)
                    }
                    if let city = pm.locality { parts.append(city) }
                    continuation.resume(returning: parts.joined(separator: ", "))
                }
            }
        }
    }

    // MARK: - Hilfsfunktionen
    private func loadTrips() -> [Trip] {
        guard let data = groupDefaults.data(forKey: "trips") else { return [] }
        return (try? JSONDecoder().decode([Trip].self, from: data)) ?? []
    }

    private func saveTrips(_ trips: [Trip]) {
        guard let data = try? JSONEncoder().encode(trips) else { return }
        groupDefaults.set(data, forKey: "trips")
        groupDefaults.synchronize()
    }

    private func loadActiveTrip() -> WatchTrip? {
        guard let data = groupDefaults.data(forKey: "activeTrip") else { return nil }
        return try? JSONDecoder().decode(WatchTrip.self, from: data)
    }
}

// MARK: - WCSessionDelegate
extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated {
            sendContextToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.handleMessage(message) }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleMessage(message, replyHandler: replyHandler)
        }
    }

    // Queued transfers (z. B. Watch-GPS-Fahrt ohne iPhone in der Nähe)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async { self.handleMessage(userInfo) }
    }
}

// MARK: - Notification
extension Notification.Name {
    static let watchDidSaveTrip = Notification.Name("watchDidSaveTrip")
}

// MARK: - Minimales Trip-Model für Watch-Kommunikation
struct WatchTrip: Codable {
    var from: String
    var to: String
    var km: Double = 0
    var startTime: Date?
    var endTime: Date?
}

// MARK: - Double Extension
private extension Double {
    func ifZero(_ fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}
