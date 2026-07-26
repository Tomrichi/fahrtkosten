import Foundation
import WatchConnectivity
import WatchKit
import SwiftUI
import Combine

// MARK: - Watch ViewModel
final class WatchViewModel: NSObject, ObservableObject {

    // Monatsdaten vom iPhone
    @Published var monthKm:    Double = 0
    @Published var monthEuro:  Double = 0
    @Published var tripCount:  Int    = 0
    @Published var kmRate:     Double = 0.38

    // Aktive manuelle Fahrt
    @Published var hasActiveTrip: Bool   = false
    @Published var activeFrom:    String = ""
    @Published var activeTo:      String = ""
    @Published var activeSince:   Date?  = nil

    // GPS Fahrt (Watch-lokal)
    @Published var isGPSTracking: Bool   = false
    @Published var gpsKm:         Double = 0
    @Published var gpsElapsed:    Int    = 0
    @Published var gpsSpeed:      Double = 0   // km/h

    // UI State
    @Published var isLoading:     Bool   = false
    @Published var lastUpdate:    Date?  = nil
    @Published var errorMessage:  String? = nil

    private let session    = WCSession.default
    private let gpsTracker = WatchLocationTracker()
    private var cancellables: Set<AnyCancellable> = []

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        gpsTracker.$km.receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.gpsKm = v }
            .store(in: &cancellables)
        gpsTracker.$elapsed.receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.gpsElapsed = v }
            .store(in: &cancellables)
        gpsTracker.$isTracking.receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.isGPSTracking = v }
            .store(in: &cancellables)
        gpsTracker.$speed.receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.gpsSpeed = v }
            .store(in: &cancellables)
        gpsTracker.$errorMessage.receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] msg in self?.errorMessage = msg }
            .store(in: &cancellables)
    }

    // MARK: - Manuelle Fahrt starten
    func startTrip(from: String, to: String) {
        isLoading = true
        let message: [String: Any] = [
            "action": "startTrip",
            "from":   from,
            "to":     to
        ]
        session.sendMessage(message, replyHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.isLoading      = false
                self?.hasActiveTrip  = true
                self?.activeFrom     = from
                self?.activeTo       = to
                self?.activeSince    = Date()
                WKInterfaceDevice.current().play(.success)
            }
        }, errorHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.isLoading     = false
                self?.errorMessage  = "Verbindungsfehler"
                WKInterfaceDevice.current().play(.failure)
            }
        })
    }

    // MARK: - Manuelle Fahrt stoppen
    func stopTrip(km: Double) {
        isLoading = true
        let message: [String: Any] = [
            "action": "stopTrip",
            "km":     km
        ]
        session.sendMessage(message, replyHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.isLoading     = false
                self?.hasActiveTrip = false
                self?.activeFrom    = ""
                self?.activeTo      = ""
                self?.activeSince   = nil
                WKInterfaceDevice.current().play(.success)
            }
        }, errorHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.isLoading    = false
                self?.errorMessage = "Verbindungsfehler"
                WKInterfaceDevice.current().play(.failure)
            }
        })
    }

    // MARK: - GPS Fahrt starten (Watch-lokal)
    func startGPSTrip() {
        errorMessage = nil
        gpsTracker.start()
        WKInterfaceDevice.current().play(.start)
        session.sendMessage(["action": "startGPSTrip"], replyHandler: nil, errorHandler: nil)
    }

    // MARK: - GPS Fahrt stoppen → Koordinaten ans iPhone senden
    func stopGPSTrip() {
        let result = gpsTracker.stop()
        WKInterfaceDevice.current().play(.success)
        isLoading = true

        let payload: [String: Any] = [
            "action":    "stopGPSTripWithCoords",
            "startLat":  result.startLat,
            "startLon":  result.startLon,
            "endLat":    result.endLat,
            "endLon":    result.endLon,
            "km":        result.km,
            "startTime": result.startTime.timeIntervalSince1970
        ]

        if session.isReachable {
            // iPhone erreichbar → direkt senden
            session.sendMessage(payload, replyHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isLoading     = false
                    self?.hasActiveTrip = false
                }
            }, errorHandler: { [weak self] _ in
                // sendMessage fehlgeschlagen → in Queue einreihen
                self?.session.transferUserInfo(payload)
                DispatchQueue.main.async {
                    self?.isLoading     = false
                    self?.hasActiveTrip = false
                }
            })
        } else {
            // iPhone nicht erreichbar (z. B. Watch-GPS ohne iPhone) → Queue
            // wird automatisch übermittelt, sobald iPhone wieder verbunden ist
            session.transferUserInfo(payload)
            DispatchQueue.main.async {
                self.isLoading     = false
                self.hasActiveTrip = false
            }
        }
    }

    // MARK: - Update anfordern
    func requestUpdate() {
        guard session.activationState == .activated,
              session.isReachable else {
            errorMessage = "iPhone nicht erreichbar"
            return
        }
        session.sendMessage(["action": "requestUpdate"], replyHandler: nil)
    }

    // MARK: - Context anwenden
    private func applyContext(_ context: [String: Any]) {
        monthKm     = context["monthKm"]    as? Double ?? 0
        monthEuro   = context["monthEuro"]  as? Double ?? 0
        tripCount   = context["tripCount"]  as? Int    ?? 0
        kmRate      = context["kmRate"]     as? Double ?? 0.38
        hasActiveTrip = context["hasActive"] as? Bool  ?? false
        activeFrom  = context["activeFrom"] as? String ?? ""
        activeTo    = context["activeTo"]   as? String ?? ""

        if let ts = context["lastUpdate"] as? Double {
            lastUpdate = Date(timeIntervalSince1970: ts)
        }
    }

    // MARK: - Formatter
    func euroString(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.decimalSeparator  = ","
        f.groupingSeparator = "."
        return (f.string(from: NSNumber(value: value)) ?? "0,00") + " €"
    }

    func kmString(_ value: Double) -> String {
        "\(Int(value)) km"
    }

    func elapsedString(_ secs: Int) -> String {
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

// MARK: - WCSessionDelegate
extension WatchViewModel: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        if state == .activated {
            DispatchQueue.main.async {
                self.applyContext(session.receivedApplicationContext)
            }
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext context: [String: Any]) {
        DispatchQueue.main.async {
            self.applyContext(context)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.applyContext(message)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
