import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup-Datenstruktur
struct AppBackup: Codable {
    let version: Int
    let exportedAt: Date
    let trips: [Trip]
    let meals: [MealEntry]
    let hotels: [HotelEntry]
    let vehicleCosts: [VehicleCost]
    let reiseSpesen: [ReiseSpese]
    let privateExpenses: [PrivateExpense]
    let kmRate: Double
    let defaultFuelConsumption: Double
    let inlandMeal1to3: Double
    let inlandMeal3to6: Double
    let inlandMeal6plus: Double
    let swissMeal1to3: Double
    let swissMeal3to6: Double
    let swissMeal6plus: Double
    let abroadMeal1to3: Double
    let abroadMeal3to6: Double
    let abroadMeal6plus: Double
    let hotelFlat: Double
    let breakfastFlat: Double
    // Version 3: Einstellungen
    let homeAddress: String?
    let defaultFuelType: String?
    let defaultFuelPriceE5: String?
    let defaultFuelPriceE10: String?
    let defaultFuelPriceDiesel: String?
    let defaultFuelPriceElektro: String?
    let defaultFuelPriceHybrid: String?
    let defaultConsumptionE5: String?
    let defaultConsumptionE10: String?
    let defaultConsumptionDiesel: String?
    let defaultConsumptionElektro: String?
    let defaultConsumptionHybrid: String?
    // Version 4: Gesetzlicher Modus
    let mealMode: String?
    let legalInlandDay: Double?
    let legalInlandFullDay: Double?
    let legalSwissDay: Double?
    let legalSwissFullDay: Double?
    let legalAbroadDay: Double?
    let legalAbroadFullDay: Double?
    // Version 5: Favoriten & Wiederkehrende Fahrten
    let favorites: [FavoriteTrip]?
    let recurringTrips: [RecurringTrip]?

    static let currentVersion = 5

    var totalEntries: Int {
        trips.count + meals.count + hotels.count + vehicleCosts.count + reiseSpesen.count + privateExpenses.count
    }
}

// MARK: - Android-Backup → iOS-Format
/// Wandelt eine Sicherung der Android-App (snake_case, Zeitstempel in ms) in das iOS-Backup-Format
/// um, damit sie sich beim Gerätewechsel (Android → iPhone) einspielen lässt.
enum AndroidBackupConverter {

    /// Android-Sicherungen haben `settings` als Unterobjekt und kein `kmRate` auf oberster Ebene.
    static func isAndroidBackup(_ root: [String: Any]) -> Bool {
        guard root["kmRate"] == nil, root["settings"] is [String: Any] else { return false }
        return root["vehicle_costs"] != nil || root["travel_expenses"] != nil || root["exported_at"] != nil
    }

    // ── Hilfen ──────────────────────────────────────────────────────────────
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func double(_ v: Any?, _ fallback: Double = 0) -> Double {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String, let d = Double(s.replacingOccurrences(of: ",", with: ".")) { return d }
        return fallback
    }
    private static func int(_ v: Any?, _ fallback: Int = 0) -> Int {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String, let i = Int(s) { return i }
        return fallback
    }
    private static func bool(_ v: Any?) -> Bool {
        if let n = v as? NSNumber { return n.intValue != 0 }
        if let s = v as? String { return s == "1" || s.lowercased() == "true" }
        return false
    }
    private static func string(_ v: Any?) -> String { (v as? String) ?? "" }

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    /// Dart schreibt z. B. „2026-10-10T13:00:00.123456“ (ohne Zeitzone) – für iOS in ein lesbares Format bringen.
    private static func isoString(from text: String) -> String? {
        if let d = isoFormatter.date(from: text) ?? isoFractionalFormatter.date(from: text) {
            return isoFormatter.string(from: d)
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for pattern in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            f.dateFormat = pattern
            if let d = f.date(from: text) { return isoFormatter.string(from: d) }
        }
        return nil
    }

    /// ms seit 1970 (Android) → ISO-8601-Text; Text-Daten werden ins iOS-Format gebracht.
    private static func iso(_ v: Any?) -> String? {
        if let s = v as? String { return s.isEmpty ? nil : isoString(from: s) }
        guard let n = v as? NSNumber else { return nil }
        let raw = n.doubleValue
        // Werte unter 10 Mrd. sind Sekunden, sonst Millisekunden
        let seconds = raw < 10_000_000_000 ? raw : raw / 1000
        return isoFormatter.string(from: Date(timeIntervalSince1970: seconds))
    }
    private static func isoOrNow(_ v: Any?) -> String { iso(v) ?? isoFormatter.string(from: Date()) }

    /// Gültige UUIDs bleiben erhalten, alles andere bekommt eine neue ID (sonst scheitert das Einlesen).
    private static func uuid(_ v: Any?) -> String {
        if let s = v as? String, UUID(uuidString: s) != nil { return s }
        return UUID().uuidString
    }

    private static func objects(_ v: Any?) -> [[String: Any]] { (v as? [[String: Any]]) ?? [] }

    // ── Zuordnungen ─────────────────────────────────────────────────────────
    private static let regionMap = ["inland": "Inland", "schweiz": "Schweiz", "ausland": "Ausland"]
    private static let dayTypeMap = [
        "automatisch": "Automatisch", "eintaegig": "Eintägig", "anreisetag": "Anreisetag",
        "abreisetag": "Abreisetag", "vollerTag": "Voller Tag",
    ]
    /// Android-Fahrzeugkosten-Kategorie → iOS-Fahrzeugkosten
    private static let vehicleMap = [
        "werkstatt": "Werkstatt / Reparatur", "leasing": "Leasing", "versicherung": "Versicherung",
        "tuvHu": "TÜV / HU", "steuer": "KFZ-Steuer", "reifen": "Reifen", "strom": "Strom / Laden",
        "fahrzeugwaesche": "Fahrzeugwäsche", "sonstiges": "Sonstiges",
    ]
    /// Android-Fahrzeugkosten-Kategorien, die es auf iOS nur als Reisespesen gibt
    private static let vehicleAsSpesenMap = [
        "vignetteUndMaut": "Vignette / Maut", "benzin": "Benzin", "verpflegung": "Verpflegung",
    ]
    private static let travelMap = [
        "werkstatt": "Werkstatt", "leasing": "Leasing", "vignetteMaut": "Vignette / Maut",
        "benzin": "Benzin", "strom": "Strom / Laden", "kfzSteuer": "KFZ-Steuer",
        "kfzVersicherung": "KFZ-Versicherung", "verpflegung": "Verpflegung", "sonstiges": "Sonstiges",
    ]
    /// Android: 1 = Mo … 7 = So  →  iOS: 1 = So, 2 = Mo … 7 = Sa
    static func iosWeekday(fromAndroid d: Int) -> Int { (d % 7) + 1 }

    // ── Umwandlung ──────────────────────────────────────────────────────────
    static func convert(_ a: [String: Any]) -> [String: Any] {
        let s = (a["settings"] as? [String: Any]) ?? [:]

        let trips: [[String: Any]] = objects(a["trips"]).map { t in
            var o: [String: Any] = [
                "id": uuid(t["id"]),
                "from": string(t["from_location"]),
                "to": string(t["to_location"]),
                "date": isoOrNow(t["date"]),
                "km": double(t["km"]),
                "note": string(t["note"]),
                "art": string(t["art"]) == "privat" ? "Privat" : "Geschäftlich",
                "purpose": string(t["purpose"]),
            ]
            if t["fuel_price_per_liter"] is NSNumber { o["fuelPricePerLiter"] = double(t["fuel_price_per_liter"]) }
            if t["fuel_consumption"] is NSNumber { o["fuelConsumption"] = double(t["fuel_consumption"]) }
            if let raw = t["fuel_type_raw"] as? String { o["fuelTypeRaw"] = raw }
            if let st = iso(t["start_time"]) { o["startTime"] = st }
            if let en = iso(t["end_time"]) { o["endTime"] = en }
            return o
        }

        let meals: [[String: Any]] = objects(a["meals"]).map { m in
            [
                "id": uuid(m["id"]),
                "date": isoOrNow(m["date"]),
                "startTime": isoOrNow(m["start_time"]),
                "endTime": isoOrNow(m["end_time"]),
                "note": string(m["note"]),
                "region": regionMap[string(m["region"])] ?? "Inland",
                "breakfastAmount": double(m["breakfast_amount"]),
                "ownBreakfastAmount": double(m["own_breakfast_amount"]),
                "pauseMinutes": int(m["pause_minutes"]),
                "workedAtPlant": bool(m["worked_at_plant"]),
                "isHoliday": bool(m["is_holiday"]),
                "isTraining": bool(m["is_training"]),
                "weekendAwayOnly": bool(m["weekend_away_only"]),
                "dayType": dayTypeMap[string(m["day_type"])] ?? "Automatisch",
                "providedBreakfast": bool(m["provided_breakfast"]),
                "providedLunch": bool(m["provided_lunch"]),
                "providedDinner": bool(m["provided_dinner"]),
            ]
        }

        let hotels: [[String: Any]] = objects(a["hotels"]).map { h in
            var o: [String: Any] = [
                "id": uuid(h["id"]),
                "date": isoOrNow(h["date"]),
                "city": string(h["city"]),
                "hotelName": string(h["hotel_name"]),
                "mode": string(h["mode"]) == "actual" ? "Tatsächlicher Betrag" : "Pauschale",
                "actualCost": double(h["actual_cost"]),
                "numberOfNights": max(1, int(h["number_of_nights"], 1)),
                "breakfastIncluded": bool(h["breakfast_included"]),
            ]
            if let out = iso(h["check_out_date"]) { o["checkOutDate"] = out }
            return o
        }

        // Fahrzeugkosten: Kategorien ohne iOS-Pendant wandern in die Reisespesen
        var vehicleCosts: [[String: Any]] = []
        var reiseSpesen: [[String: Any]] = []
        for v in objects(a["vehicle_costs"]) {
            let cat = string(v["category"])
            var o: [String: Any] = [
                "id": uuid(v["id"]),
                "date": isoOrNow(v["date"]),
                "title": string(v["title"]),
                "amount": double(v["amount"]),
                "note": string(v["note"]),
            ]
            if let spese = vehicleAsSpesenMap[cat] {
                o["kategorie"] = spese
                reiseSpesen.append(o)
            } else {
                o["category"] = vehicleMap[cat] ?? "Sonstiges"
                if v["mileage"] is NSNumber { o["mileage"] = int(v["mileage"]) }
                vehicleCosts.append(o)
            }
        }
        for t in objects(a["travel_expenses"]) {
            reiseSpesen.append([
                "id": uuid(t["id"]),
                "date": isoOrNow(t["date"]),
                "kategorie": travelMap[string(t["category"])] ?? "Sonstiges",
                "title": string(t["title"]),
                "amount": double(t["amount"]),
                "note": string(t["note"]),
            ])
        }

        let privateExpenses: [[String: Any]] = objects(a["private_expenses"]).map { p in
            [
                "id": uuid(p["id"]),
                "date": isoOrNow(p["date"]),
                "title": string(p["title"]),
                "amount": double(p["amount"]),
                "note": string(p["note"]),
            ]
        }

        let favorites: [[String: Any]] = objects(a["favorites"]).map { f in
            [
                "id": uuid(f["id"]),
                "from": string(f["from_location"]),
                "to": string(f["to_location"]),
                "km": double(f["km"]),
            ]
        }

        let recurring: [[String: Any]] = objects(a["recurring_trips"]).map { r in
            let days = string(r["weekdays"]).split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            return [
                "id": uuid(r["id"]),
                "from": string(r["from_location"]),
                "to": string(r["to_location"]),
                "km": double(r["km"]),
                "weekdays": days.filter { (1...7).contains($0) }.map(iosWeekday(fromAndroid:)),
                "note": string(r["note"]),
                "isActive": r["is_active"] == nil ? true : bool(r["is_active"]),
            ]
        }

        // ── Einstellungen ───────────────────────────────────────────────────
        let fuelType = string(s["defaultFuelType"]).isEmpty ? "e10" : string(s["defaultFuelType"])
        func price(_ k: String) -> String? {
            guard s[k] is NSNumber else { return nil }
            return String(format: "%.2f", double(s[k])).replacingOccurrences(of: ".", with: ",")
        }
        func cons(_ k: String) -> String? {
            guard s[k] is NSNumber else { return nil }
            return String(format: "%.1f", double(s[k])).replacingOccurrences(of: ".", with: ",")
        }
        let consumptionKey: [String: String] = [
            "e5": "consumptionE5", "e10": "consumptionE10", "diesel": "consumptionDiesel",
            "elektro": "consumptionElektro", "hybrid": "consumptionHybrid",
        ]
        let mealMode = string(s["mealMode"]) == "eigeneStufen" ? "Eigene Stufen" : "Gesetzlich"

        var out: [String: Any] = [
            "version": AppBackup.currentVersion,
            "exportedAt": isoOrNow(a["exported_at"]),
            "trips": trips,
            "meals": meals,
            "hotels": hotels,
            "vehicleCosts": vehicleCosts,
            "reiseSpesen": reiseSpesen,
            "privateExpenses": privateExpenses,
            "favorites": favorites,
            "recurringTrips": recurring,
            "kmRate": double(s["kmRate"], Constants.kmRate),
            "defaultFuelConsumption": double(s[consumptionKey[fuelType] ?? "consumptionE10"], Constants.defaultFuelConsumption),
            "inlandMeal1to3": double(s["inlandMeal1to3"]),
            "inlandMeal3to6": double(s["inlandMeal3to6"]),
            "inlandMeal6plus": double(s["inlandMeal6plus"]),
            "swissMeal1to3": double(s["swissMeal1to3"]),
            "swissMeal3to6": double(s["swissMeal3to6"]),
            "swissMeal6plus": double(s["swissMeal6plus"]),
            "abroadMeal1to3": double(s["abroadMeal1to3"]),
            "abroadMeal3to6": double(s["abroadMeal3to6"]),
            "abroadMeal6plus": double(s["abroadMeal6plus"]),
            "hotelFlat": double(s["hotelFlat"], Constants.hotelFlat),
            "breakfastFlat": double(s["breakfastFlat"], Constants.breakfastFlat),
            "defaultFuelType": fuelType,
            "mealMode": mealMode,
        ]
        if let h = s["homeAddress"] as? String { out["homeAddress"] = h }
        if let v = price("fuelPriceE5") { out["defaultFuelPriceE5"] = v }
        if let v = price("fuelPriceE10") { out["defaultFuelPriceE10"] = v }
        if let v = price("fuelPriceDiesel") { out["defaultFuelPriceDiesel"] = v }
        if let v = price("fuelPriceElektro") { out["defaultFuelPriceElektro"] = v }
        if let v = price("fuelPriceHybrid") { out["defaultFuelPriceHybrid"] = v }
        if let v = cons("consumptionE5") { out["defaultConsumptionE5"] = v }
        if let v = cons("consumptionE10") { out["defaultConsumptionE10"] = v }
        if let v = cons("consumptionDiesel") { out["defaultConsumptionDiesel"] = v }
        if let v = cons("consumptionElektro") { out["defaultConsumptionElektro"] = v }
        if let v = cons("consumptionHybrid") { out["defaultConsumptionHybrid"] = v }
        for k in ["legalInlandDay", "legalInlandFullDay", "legalSwissDay", "legalSwissFullDay", "legalAbroadDay", "legalAbroadFullDay"]
        where s[k] is NSNumber {
            out[k] = double(s[k])
        }
        return out
    }
}

// MARK: - Gespeichertes Backup (lokal)
struct SavedBackupInfo: Identifiable {
    let id = UUID()
    let url: URL
    let filename: String
    let date: Date
    let fileSize: Int64

    var formattedSize: String {
        let kb = Double(fileSize) / 1024
        if kb >= 1024 { return String(format: "%.1f MB", kb / 1024) }
        return String(format: "%.0f KB", kb)
    }
}

// MARK: - BackupManager
@MainActor
class BackupManager: ObservableObject {
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastError: String?
    @Published var lastSuccess: String?
    @Published var savedBackups: [SavedBackupInfo] = []
    @Published var isLoadingBackups = false

    // App-eigener Dokumente-Ordner (in Dateien-App sichtbar unter "Auf meinem iPhone")
    private var backupDirectory: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Backup JSON erstellen
    func createBackupData(from store: DataStore) -> Data? {
        let ud = UserDefaults.standard
        let backup = AppBackup(
            version: AppBackup.currentVersion,
            exportedAt: Date(),
            trips: store.trips,
            meals: store.meals,
            hotels: store.hotels,
            vehicleCosts: store.vehicleCosts,
            reiseSpesen: store.reiseSpesen,
            privateExpenses: store.privateExpenses,
            kmRate: store.kmRate,
            defaultFuelConsumption: store.defaultFuelConsumption,
            inlandMeal1to3: store.inlandMeal1to3,
            inlandMeal3to6: store.inlandMeal3to6,
            inlandMeal6plus: store.inlandMeal6plus,
            swissMeal1to3: store.swissMeal1to3,
            swissMeal3to6: store.swissMeal3to6,
            swissMeal6plus: store.swissMeal6plus,
            abroadMeal1to3: store.abroadMeal1to3,
            abroadMeal3to6: store.abroadMeal3to6,
            abroadMeal6plus: store.abroadMeal6plus,
            hotelFlat: store.hotelFlat,
            breakfastFlat: store.breakfastFlat,
            homeAddress: ud.string(forKey: "homeAddress"),
            defaultFuelType: ud.string(forKey: "defaultFuelType"),
            defaultFuelPriceE5: ud.string(forKey: "defaultFuelPrice.e5"),
            defaultFuelPriceE10: ud.string(forKey: "defaultFuelPrice.e10"),
            defaultFuelPriceDiesel: ud.string(forKey: "defaultFuelPrice.diesel"),
            defaultFuelPriceElektro: ud.string(forKey: "defaultFuelPrice.elektro"),
            defaultFuelPriceHybrid: ud.string(forKey: "defaultFuelPrice.hybrid"),
            defaultConsumptionE5: ud.string(forKey: "defaultConsumption.e5"),
            defaultConsumptionE10: ud.string(forKey: "defaultConsumption.e10"),
            defaultConsumptionDiesel: ud.string(forKey: "defaultConsumption.diesel"),
            defaultConsumptionElektro: ud.string(forKey: "defaultConsumption.elektro"),
            defaultConsumptionHybrid: ud.string(forKey: "defaultConsumption.hybrid"),
            mealMode: store.mealMode.rawValue,
            legalInlandDay: store.legalInlandDay,
            legalInlandFullDay: store.legalInlandFullDay,
            legalSwissDay: store.legalSwissDay,
            legalSwissFullDay: store.legalSwissFullDay,
            legalAbroadDay: store.legalAbroadDay,
            legalAbroadFullDay: store.legalAbroadFullDay,
            favorites: store.favorites,
            recurringTrips: store.recurringTrips
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }

    private func backupFilename() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm"
        return "Fahrtkosten_Backup_\(f.string(from: Date())).json"
    }

    // MARK: - Lokal speichern (Dateien-App)
    func saveLocally(from store: DataStore) {
        guard let dir = backupDirectory,
              let data = createBackupData(from: store) else {
            lastError = "Backup konnte nicht erstellt werden"
            return
        }
        let url = dir.appendingPathComponent(backupFilename())
        do {
            try data.write(to: url, options: .atomic)
            lastSuccess = "Backup gespeichert - abrufbar in der Dateien-App unter: Auf meinem iPhone → Fahrtkosten → Backups"
            loadSavedBackups()
            // Alte aufräumen
            cleanupOldBackups(in: dir, keepCount: 10)
        } catch {
            lastError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Share Sheet (AirDrop, iCloud Drive, Google Drive, etc.)
    func backupFileURL(from store: DataStore) -> URL? {
        guard let data = createBackupData(from: store) else {
            lastError = "Backup konnte nicht erstellt werden"
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(backupFilename())
        do {
            try data.write(to: url)
            return url
        } catch {
            lastError = "Datei konnte nicht erstellt werden"
            return nil
        }
    }

    // MARK: - Gespeicherte Backups laden
    func loadSavedBackups() {
        guard let dir = backupDirectory else { return }
        isLoadingBackups = true
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            savedBackups = files
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> SavedBackupInfo? in
                    let v = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                    return SavedBackupInfo(
                        url: url,
                        filename: url.lastPathComponent,
                        date: v?.creationDate ?? Date(),
                        fileSize: Int64(v?.fileSize ?? 0)
                    )
                }
                .sorted { $0.date > $1.date }
        } catch {
            savedBackups = []
        }
        isLoadingBackups = false
    }

    // MARK: - Backup löschen
    func deleteBackup(_ info: SavedBackupInfo) {
        try? FileManager.default.removeItem(at: info.url)
        loadSavedBackups()
    }

    // MARK: - Wiederherstellen
    func restore(from url: URL, into store: DataStore) -> Bool {
        do {
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            var data = try Data(contentsOf: url)
            // Sicherung aus der Android-App (Gerätewechsel) → iOS-Format umwandeln
            var fromAndroid = false
            if let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               AndroidBackupConverter.isAndroidBackup(root),
               let converted = try? JSONSerialization.data(withJSONObject: AndroidBackupConverter.convert(root)) {
                data = converted
                fromAndroid = true
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(AppBackup.self, from: data)
            // Früher gelöschte Einträge bekommen neue IDs, damit der iCloud-Abgleich sie nicht
            // wieder als „gelöscht“ entfernt.
            store.trips = backup.trips.map { var e = $0; if store.isDeleted(e.id, key: "trips") { e.id = UUID() }; return e }
            store.meals = backup.meals.map { var e = $0; if store.isDeleted(e.id, key: "meals") { e.id = UUID() }; return e }
            store.hotels = backup.hotels.map { var e = $0; if store.isDeleted(e.id, key: "hotels") { e.id = UUID() }; return e }
            store.vehicleCosts = backup.vehicleCosts.map { var e = $0; if store.isDeleted(e.id, key: "vehicleCosts") { e.id = UUID() }; return e }
            store.reiseSpesen = backup.reiseSpesen.map { var e = $0; if store.isDeleted(e.id, key: "reiseSpesen") { e.id = UUID() }; return e }
            store.privateExpenses = backup.privateExpenses.map { var e = $0; if store.isDeleted(e.id, key: "privateExpenses") { e.id = UUID() }; return e }
            store.kmRate = backup.kmRate
            store.defaultFuelConsumption = backup.defaultFuelConsumption
            store.inlandMeal1to3 = backup.inlandMeal1to3
            store.inlandMeal3to6 = backup.inlandMeal3to6
            store.inlandMeal6plus = backup.inlandMeal6plus
            store.swissMeal1to3 = backup.swissMeal1to3
            store.swissMeal3to6 = backup.swissMeal3to6
            store.swissMeal6plus = backup.swissMeal6plus
            store.abroadMeal1to3 = backup.abroadMeal1to3
            store.abroadMeal3to6 = backup.abroadMeal3to6
            store.abroadMeal6plus = backup.abroadMeal6plus
            store.hotelFlat = backup.hotelFlat
            store.breakfastFlat = backup.breakfastFlat
            // Version 3: Einstellungen wiederherstellen
            let ud = UserDefaults.standard
            if let v = backup.homeAddress        { ud.set(v, forKey: "homeAddress") }
            if let v = backup.defaultFuelType    { ud.set(v, forKey: "defaultFuelType") }
            if let v = backup.defaultFuelPriceE5       { ud.set(v, forKey: "defaultFuelPrice.e5") }
            if let v = backup.defaultFuelPriceE10      { ud.set(v, forKey: "defaultFuelPrice.e10") }
            if let v = backup.defaultFuelPriceDiesel   { ud.set(v, forKey: "defaultFuelPrice.diesel") }
            if let v = backup.defaultFuelPriceElektro  { ud.set(v, forKey: "defaultFuelPrice.elektro") }
            if let v = backup.defaultFuelPriceHybrid   { ud.set(v, forKey: "defaultFuelPrice.hybrid") }
            if let v = backup.defaultConsumptionE5     { ud.set(v, forKey: "defaultConsumption.e5") }
            if let v = backup.defaultConsumptionE10    { ud.set(v, forKey: "defaultConsumption.e10") }
            if let v = backup.defaultConsumptionDiesel { ud.set(v, forKey: "defaultConsumption.diesel") }
            if let v = backup.defaultConsumptionElektro{ ud.set(v, forKey: "defaultConsumption.elektro") }
            if let v = backup.defaultConsumptionHybrid { ud.set(v, forKey: "defaultConsumption.hybrid") }
            // Version 4: Gesetzlicher Modus
            if let m = backup.mealMode.flatMap({ MealMode(rawValue: $0) }) { store.mealMode = m }
            if let v = backup.legalInlandDay     { store.legalInlandDay = v }
            if let v = backup.legalInlandFullDay { store.legalInlandFullDay = v }
            if let v = backup.legalSwissDay      { store.legalSwissDay = v }
            if let v = backup.legalSwissFullDay  { store.legalSwissFullDay = v }
            if let v = backup.legalAbroadDay     { store.legalAbroadDay = v }
            if let v = backup.legalAbroadFullDay { store.legalAbroadFullDay = v }
            // Version 5: Favoriten & Wiederkehrende Fahrten (ältere Backups enthalten sie nicht → bestehende bleiben)
            if let v = backup.favorites      { store.favorites = v }
            if let v = backup.recurringTrips { store.recurringTrips = v }
            let dateStr = backup.exportedAt.formatted(date: .abbreviated, time: .shortened)
            lastSuccess = "Backup vom \(dateStr) wiederhergestellt (\(backup.totalEntries) Einträge)"
                + (fromAndroid ? " – aus der Android-App übernommen" : "")
            return true
        } catch DecodingError.dataCorrupted(_) {
            lastError = "Ungültige Backup-Datei"
        } catch DecodingError.keyNotFound(let key, _) {
            lastError = "Backup unvollständig: '\(key.stringValue)' fehlt"
        } catch {
            lastError = "Fehler: \(error.localizedDescription)"
        }
        return false
    }

    // MARK: - Alte Backups aufräumen
    private func cleanupOldBackups(in dir: URL, keepCount: Int) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles
        ) else { return }
        let sorted = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> (URL, Date)? in
                let d = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                return d.map { (url, $0) }
            }
            .sorted { $0.1 > $1.1 }
        for (url, _) in sorted.dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Alle Einträge löschen
    func deleteAllEntries(in store: DataStore) {
        store.trips = []; store.meals = []; store.hotels = []
        store.vehicleCosts = []; store.reiseSpesen = []; store.privateExpenses = []
    }
}

// MARK: - Datei-Import Picker
struct BackupImportPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

extension UTType {
    static let fahrtkostenBackup = UTType(importedAs: "de.fahrtkosten.backup")
}
