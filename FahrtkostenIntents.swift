import AppIntents
import Foundation

// MARK: - Shared DataStore Zugriff für Intents
@MainActor
private struct IntentDataAccess {
    // App Group – selbe Daten wie Haupt-App, Widget und Watch
    static let local = UserDefaults(suiteName: "group.de.tommwagner.fahrtkosten") ?? .standard

    static func loadTrips() -> [Trip] {
        guard let data = local.data(forKey: "trips") else { return [] }
        return (try? JSONDecoder().decode([Trip].self, from: data)) ?? []
    }

    static func saveTrips(_ trips: [Trip]) {
        guard let data = try? JSONEncoder().encode(trips) else { return }
        local.set(data, forKey: "trips")
        NSUbiquitousKeyValueStore.default.set(data, forKey: "trips")
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    static func kmRate() -> Double {
        let rate = local.double(forKey: "kmRate")
        return rate == 0 ? 0.38 : rate
    }

    static func monthlyTotal() -> (total: Double, count: Int, km: Double) {
        let trips = loadTrips()
        let rate  = kmRate()
        let cal   = Calendar.current
        let now   = Date()
        let mt    = trips.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
        let sum   = mt.reduce(0.0) { $0 + $1.km * rate }
        let km    = mt.reduce(0.0) { $0 + $1.km }
        return (sum, mt.count, km)
    }

    static func activeTrip() -> Trip? {
        guard let data = local.data(forKey: "activeTrip") else { return nil }
        return try? JSONDecoder().decode(Trip.self, from: data)
    }

    static func saveActiveTrip(_ trip: Trip?) {
        if let trip, let data = try? JSONEncoder().encode(trip) {
            local.set(data, forKey: "activeTrip")
        } else {
            local.removeObject(forKey: "activeTrip")
        }
    }

    static func appendTrip(_ trip: Trip) {
        var trips = loadTrips()
        trips.append(trip)
        saveTrips(trips)
    }

    static func makeTrip(from: String, to: String, km: Double, note: String, startTime: Date?, endTime: Date?) -> Trip {
        Trip(from: from, to: to, date: Date(), km: km, note: note,
             startTime: startTime, endTime: endTime)
    }
}

// MARK: - 1. Fahrt starten
struct StartTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Fahrt starten"
    static var description = IntentDescription("Startet eine neue Fahrt in Fahrtkosten")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Ziel", description: "Wohin fährst du?")
    var destination: String

    @Parameter(title: "Von", description: "Startort (optional)", default: "")
    var origin: String

    static var parameterSummary: some ParameterSummary {
        Summary("Fahrt nach \(\.$destination) starten") { \.$origin }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let existingDest: String? = await MainActor.run {
            IntentDataAccess.activeTrip()?.to
        }
        if let dest = existingDest {
            return .result(dialog: "Es läuft bereits eine Fahrt nach \(dest). Bitte zuerst stoppen.")
        }

        let from = origin.isEmpty ? "Aktueller Standort" : origin
        let dest = destination

        await MainActor.run {
            let trip = IntentDataAccess.makeTrip(
                from: from, to: dest, km: 0,
                note: "Via Siri gestartet",
                startTime: Date(), endTime: nil
            )
            IntentDataAccess.saveActiveTrip(trip)
        }

        return .result(dialog: "Fahrt nach \(destination) gestartet. Gute Fahrt!")
    }
}

// MARK: - 2. Fahrt stoppen
struct StopTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Fahrt stoppen"
    static var description = IntentDescription("Beendet die aktive Fahrt und speichert sie")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Kilometer", description: "Gefahrene Kilometer")
    var kilometers: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Fahrt stoppen mit \(\.$kilometers) km")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let info: (to: String, rate: Double)? = await MainActor.run {
            guard let t = IntentDataAccess.activeTrip() else { return nil }
            return (t.to, IntentDataAccess.kmRate())
        }

        guard let info else {
            return .result(dialog: "Keine aktive Fahrt gefunden. Starte zuerst eine Fahrt.")
        }

        let km  = kilometers
        let now = Date()

        await MainActor.run {
            guard var trip = IntentDataAccess.activeTrip() else { return }
            trip.km      = km
            trip.endTime = now
            IntentDataAccess.appendTrip(trip)
            IntentDataAccess.saveActiveTrip(nil)
        }

        let betragText = String(format: "%.2f", km * info.rate)
        return .result(dialog: "Fahrt nach \(info.to) gespeichert. \(String(format: "%.1f", km)) km, \(betragText) Euro.")
    }
}

// MARK: - 3. Monatssumme abfragen
struct MonthlySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Monatssumme abfragen"
    static var description = IntentDescription("Zeigt die Fahrtkosten-Summe des aktuellen Monats")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await MainActor.run { IntentDataAccess.monthlyTotal() }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        formatter.locale = Locale(identifier: "de_DE")
        let monthName = formatter.string(from: Date())

        return .result(
            dialog: "Im \(monthName) hast du \(result.count) Fahrten mit insgesamt \(String(format: "%.0f", result.km)) Kilometern. Das ergibt \(String(format: "%.2f", result.total)) Euro Erstattung."
        )
    }
}

// MARK: - 4. Neuen Eintrag diktieren
struct NewEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Neuen Fahrt-Eintrag erstellen"
    static var description = IntentDescription("Erstellt direkt einen neuen Fahrt-Eintrag")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Von") var origin: String
    @Parameter(title: "Nach") var destination: String
    @Parameter(title: "Kilometer") var kilometers: Double
    @Parameter(title: "Notiz", default: "") var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("Fahrt von \(\.$origin) nach \(\.$destination), \(\.$kilometers) km") { \.$note }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let km   = kilometers
        let from = origin
        let to   = destination
        let n    = note

        let rate = await MainActor.run { () -> Double in
            let trip = IntentDataAccess.makeTrip(
                from: from, to: to, km: km,
                note: n.isEmpty ? "Via Siri" : n,
                startTime: nil, endTime: nil
            )
            IntentDataAccess.appendTrip(trip)
            return IntentDataAccess.kmRate()
        }

        let betragText = String(format: "%.2f", km * rate)
        return .result(
            opensIntent: OpenAppIntent(),
            dialog: "Fahrt von \(origin) nach \(destination), \(String(format: "%.1f", km)) km, \(betragText) Euro wurde gespeichert."
        )
    }
}

// MARK: - App öffnen Intent
struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Fahrtkosten öffnen"
    static var openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - Shortcut-Vorschläge
// Wichtig: AppShortcut-Phrases dürfen NUR AppEntity/AppEnum-Parameter als Platzhalter enthalten,
// keine String-Parameter — daher hier nur generische Phrases ohne $destination
struct FahrtkostenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTripIntent(),
            phrases: [
                "Fahrt starten in \(.applicationName)",
                "Neue Fahrt in \(.applicationName)"
            ],
            shortTitle: "Fahrt starten",
            systemImageName: "car.fill"
        )
        AppShortcut(
            intent: StopTripIntent(),
            phrases: [
                "Fahrt stoppen in \(.applicationName)",
                "Fahrt beenden in \(.applicationName)"
            ],
            shortTitle: "Fahrt stoppen",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: MonthlySummaryIntent(),
            phrases: [
                "Fahrtkosten diesen Monat in \(.applicationName)",
                "Monatssumme in \(.applicationName)"
            ],
            shortTitle: "Monatssumme",
            systemImageName: "eurosign.circle.fill"
        )
        AppShortcut(
            intent: NewEntryIntent(),
            phrases: [
                "Neue Fahrt eingeben in \(.applicationName)",
                "Fahrt diktieren in \(.applicationName)"
            ],
            shortTitle: "Fahrt diktieren",
            systemImageName: "mic.fill"
        )
    }
}
