import CarPlay
import UIKit

// MARK: - CarPlay Scene Delegate
// Zeigt: Monatssumme, aktive Siri-Fahrt, GPS-Status, Start/Stop-Buttons
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?

    private var refreshTimer: Timer?
    /// Bestehendes Template wird bei jedem Refresh nur noch aktualisiert (title/items/actions),
    /// statt per setRootTemplate komplett ersetzt zu werden – sonst zappelt/blinkt der Bildschirm
    /// alle 5 Sekunden sichtbar, weil CarPlay das komplette Template neu einblendet.
    private var currentTemplate: CPInformationTemplate?
    private static let appGroup = "group.de.tommwagner.fahrtkosten"

    // MARK: - Connect / Disconnect
    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController

        // Alle 5 Sekunden Dashboard aktualisieren (GPS-Status + Siri-Fahrt + Monatsdaten)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.renderDashboard()
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)

        renderDashboard()

        // GPS automatisch starten wenn Einstellung aktiv und noch keine Aufzeichnung läuft
        let autoStart = UserDefaults.standard.bool(forKey: "carPlayAutoStartGPS")
        let gps = readGPSState()
        if autoStart && !gps.recording {
            startGPSFromCarPlay()
        }
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController ic: CPInterfaceController) {
        interfaceController = nil
        currentTemplate = nil
        refreshTimer?.invalidate()
        refreshTimer = nil

        // GPS läuft noch → automatisch stoppen und an die App übergeben
        let gps = readGPSState()
        if gps.recording {
            guard let ud = UserDefaults(suiteName: Self.appGroup) else { return }
            ud.set(true, forKey: "carPlayStopGPS")
            ud.set(true, forKey: "carPlayAutoStopped") // Marker: App soll GPS-Sheet öffnen
            ud.synchronize()
            NotificationCenter.default.post(
                name: NSNotification.Name("carPlayStopGPS"), object: nil
            )
        }
    }

    // GPS-Status direkt aus App Group UserDefaults lesen (prozessübergreifend zuverlässig)
    private func readGPSState() -> (recording: Bool, km: Double, elapsed: Int, speedKmh: Double) {
        guard let ud = UserDefaults(suiteName: Self.appGroup) else {
            return (false, 0, 0, 0)
        }
        return (
            ud.bool(forKey: "gpsIsRecording"),
            ud.double(forKey: "gpsKm"),
            ud.integer(forKey: "gpsElapsed"),
            ud.double(forKey: "gpsSpeedKmh")
        )
    }

    // MARK: - Dashboard rendern
    private func renderDashboard() {
        let monthly  = CarPlayDataAccess.monthlyData()
        let active   = CarPlayDataAccess.activeTrip()
        let gps      = readGPSState()

        var items: [CPInformationItem] = []
        var actions: [CPTextButton]    = []

        // ── Aktive Siri-Fahrt ──────────────────────────────────────
        if let trip = active {
            let elapsed = Int(Date().timeIntervalSince(trip.startTime ?? Date()))
            let h = elapsed / 3600
            let m = (elapsed % 3600) / 60
            let s = elapsed % 60
            let timeStr = h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%02d:%02d", m, s)

            items.append(CPInformationItem(title: "🔴 Fahrt läuft", detail: "→ \(trip.to)"))
            items.append(CPInformationItem(title: "Fahrzeit", detail: timeStr))

            let stopBtn = CPTextButton(title: "Fahrt stoppen",
                                       textStyle: .confirm) { [weak self] _ in
                self?.stopActiveTripFromCarPlay(trip: trip)
            }
            actions.append(stopBtn)

        // ── GPS-Aufzeichnung läuft ─────────────────────────────────
        } else if gps.recording {
            let h = gps.elapsed / 3600
            let m = (gps.elapsed % 3600) / 60
            let s = gps.elapsed % 60
            let timeStr = h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%02d:%02d", m, s)

            items.append(CPInformationItem(title: "🔴 GPS läuft", detail: "\(String(format: "%.1f", gps.km)) km"))
            items.append(CPInformationItem(title: "Fahrzeit", detail: timeStr))
            items.append(CPInformationItem(title: "Tempo", detail: "\(Int(gps.speedKmh)) km/h"))
            items.append(CPInformationItem(title: "Erstattung ca.", detail: carPlayEuro(gps.km * CarPlayDataAccess.kmRate())))

            let stopGPSBtn = CPTextButton(title: "GPS stoppen",
                                          textStyle: .cancel) { [weak self] _ in
                self?.stopGPSFromCarPlay()
            }
            actions.append(stopGPSBtn)

        // ── Bereit → GPS starten anbieten ─────────────────────────
        } else {
            items.append(CPInformationItem(title: "Heute", detail: "\(Int(monthly.monthKm)) km · \(monthly.tripCount) Fahrten"))
            items.append(CPInformationItem(title: "Erstattung", detail: carPlayEuro(monthly.monthEuro)))

            let startGPSBtn = CPTextButton(title: "🛰 GPS starten",
                                           textStyle: .confirm) { [weak self] _ in
                self?.startGPSFromCarPlay()
            }
            actions.append(startGPSBtn)
        }

        // ── Monatsdaten nur anzeigen wenn GPS läuft oder Fahrt aktiv ─
        if active != nil || gps.recording {
            items.append(CPInformationItem(
                title: monthly.monthLabel,
                detail: "\(Int(monthly.monthKm)) km · \(carPlayEuro(monthly.monthEuro))"
            ))
        }

        // ── Template ───────────────────────────────────────────────
        let title = active != nil
            ? "Fahrt läuft"
            : gps.recording
                ? "GPS · Fahrt"
                : "Fahrtkosten"

        // Bestehendes Template nur aktualisieren statt komplett neu zu setzen – verhindert das
        // sichtbare Zappeln alle 5 Sekunden, das durch ein wiederholtes setRootTemplate entsteht.
        if let existing = currentTemplate {
            existing.title = title
            existing.items = items
            existing.actions = actions
        } else {
            let tpl = CPInformationTemplate(
                title: title,
                layout: .leading,
                items: items,
                actions: actions
            )
            currentTemplate = tpl
            interfaceController?.setRootTemplate(tpl, animated: false, completion: nil)
        }
    }

    // MARK: - GPS über CarPlay starten
    // Startet direkt gegen den LocationTracker-Singleton – funktioniert auch, wenn die
    // Telefon-UI nie gerendert wurde (App nur über CarPlay gestartet).
    private func startGPSFromCarPlay() {
        guard let ud = UserDefaults(suiteName: Self.appGroup) else { return }
        ud.set(true, forKey: "carPlayStartGPS")
        ud.synchronize()
        LocationTracker.shared.requestAndStart()
        // Notification für den Fall, dass die App-UI parallel offen ist (no-op dank Guard in requestAndStart)
        NotificationCenter.default.post(name: NSNotification.Name("carPlayStartGPS"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.renderDashboard()
        }
    }

    // MARK: - GPS über CarPlay stoppen
    // Stoppt und speichert direkt über den Singleton – unabhängig davon, ob je eine
    // FahrtenView existiert hat, die die Notification hätte empfangen können.
    private func stopGPSFromCarPlay() {
        guard let ud = UserDefaults(suiteName: Self.appGroup) else { return }
        ud.set(true, forKey: "carPlayStopGPS")
        ud.synchronize()
        NotificationCenter.default.post(name: NSNotification.Name("carPlayStopGPS"), object: nil)

        let startDate = LocationTracker.shared.tripStartDate
        LocationTracker.shared.stopAndGeocode { [weak self] from, to, km in
            let start = startDate ?? Date()
            let trip = Trip(
                from: from.isEmpty ? "Startort" : from,
                to:   to.isEmpty   ? "Zielort"  : to,
                date: start, km: km,
                note: "GPS via CarPlay",
                startTime: start, endTime: Date()
            )
            CarPlayDataAccess.saveTrip(trip)
            self?.renderDashboard()
        }

        let items = [
            CPInformationItem(title: "✓ GPS wird gestoppt", detail: "Fahrt wird gespeichert…"),
            CPInformationItem(title: "Hinweis", detail: "Details in der App prüfen")
        ]
        let tpl = CPInformationTemplate(title: "Fahrt beendet", layout: .leading, items: items, actions: [])
        currentTemplate = nil // Zwischenbildschirm ist jetzt aktiv – nächstes renderDashboard() muss neu setzen
        interfaceController?.setRootTemplate(tpl, animated: true, completion: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.renderDashboard()
        }
    }

    // MARK: - Siri-Fahrt über CarPlay stoppen
    // Speichert die Fahrt ohne km (0) – Nutzer kann km später in der App nachtragen
    private func stopActiveTripFromCarPlay(trip: Trip) {
        var finished = trip
        finished.endTime = Date()
        // km = 0 da wir in CarPlay keine Tastatur haben
        // Nutzer wird über Alert informiert
        CarPlayDataAccess.finishActiveTrip(finished)
        renderDashboard()

        // Kurze Bestätigung als neues Template
        let items = [
            CPInformationItem(title: "✓ Fahrt gespeichert", detail: "→ \(trip.to)"),
            CPInformationItem(title: "Hinweis", detail: "Kilometer bitte in der App nachtragen")
        ]
        let tpl = CPInformationTemplate(
            title: "Fahrt beendet",
            layout: .leading,
            items: items,
            actions: []
        )
        currentTemplate = nil // Zwischenbildschirm ist jetzt aktiv – nächstes renderDashboard() muss neu setzen
        interfaceController?.setRootTemplate(tpl, animated: true, completion: nil)

        // Nach 3 Sekunden zurück zum Dashboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.renderDashboard()
        }
    }
}

// MARK: - CarPlay Data Access
// Liest aus App Group UserDefaults (gleicher Speicher wie Intents + DataStore)
private struct CarPlayDataAccess {

    static let defaults: UserDefaults = {
        UserDefaults(suiteName: "group.de.tommwagner.fahrtkosten") ?? .standard
    }()

    static func loadTrips() -> [Trip] {
        guard let data = defaults.data(forKey: "trips") else { return [] }
        return (try? JSONDecoder().decode([Trip].self, from: data)) ?? []
    }

    static func kmRate() -> Double {
        let r = defaults.double(forKey: "kmRate")
        return r == 0 ? 0.38 : r
    }

    static func activeTrip() -> Trip? {
        guard let data = defaults.data(forKey: "activeTrip") else { return nil }
        return try? JSONDecoder().decode(Trip.self, from: data)
    }

    static func finishActiveTrip(_ trip: Trip) {
        saveTrip(trip)
        // Aktive Fahrt löschen
        defaults.removeObject(forKey: "activeTrip")
    }

    // Fahrt direkt in App Group + iCloud persistieren – unabhängig von einer
    // laufenden DataStore-Instanz (die evtl. nie erzeugt wurde, s. o.)
    static func saveTrip(_ trip: Trip) {
        var trips = loadTrips()
        trips.append(trip)
        if let data = try? JSONEncoder().encode(trips) {
            defaults.set(data, forKey: "trips")
            NSUbiquitousKeyValueStore.default.set(data, forKey: "trips")
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }

    static func monthlyData() -> (monthLabel: String, monthEuro: Double, monthKm: Double, tripCount: Int) {
        let trips = loadTrips()
        let rate  = kmRate()
        let cal   = Calendar.current
        let now   = Date()

        let monthTrips = trips.filter {
            cal.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        let euro = monthTrips.reduce(0.0) { $0 + $1.km * rate }
        let km   = monthTrips.reduce(0.0) { $0 + $1.km }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "MMMM yyyy"

        return (fmt.string(from: now), euro, km, monthTrips.count)
    }
}

// MARK: - Euro Formatter (kein Zugriff auf App-Helpers in CarPlay)
private func carPlayEuro(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    f.decimalSeparator = ","
    f.groupingSeparator = "."
    return (f.string(from: NSNumber(value: value)) ?? "0,00") + " €"
}
