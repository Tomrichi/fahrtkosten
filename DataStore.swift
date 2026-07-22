import Foundation
import Combine

/// Antwortformat der Frankfurter-API (https://api.frankfurter.dev/v2/rate/EUR/CHF),
/// liefert EZB-Referenzkurse: {"date":"...","base":"EUR","quote":"CHF","rate":0.925}
private struct FrankfurterRateResponse: Decodable {
    let rate: Double
}

class DataStore: ObservableObject {

    // MARK: - Storage
    private let icloud = NSUbiquitousKeyValueStore.default
    // App Group UserDefaults – geteilt mit Widget Extension
    private let local: UserDefaults = {
        UserDefaults(suiteName: "group.de.tommwagner.fahrtkosten") ?? .standard
    }()

    // MARK: - Data (gespeichert in iCloud + lokalem UserDefaults als Backup)
    @Published var trips:           [Trip]           = [] { didSet { save(trips,           key: "trips") } }
    @Published var meals:           [MealEntry]      = [] { didSet { save(meals,           key: "meals") } }
    @Published var hotels:          [HotelEntry]     = [] { didSet { save(hotels,          key: "hotels") } }
    @Published var vehicleCosts:    [VehicleCost]    = [] { didSet { save(vehicleCosts,    key: "vehicleCosts") } }
    @Published var reiseSpesen:     [ReiseSpese]     = [] { didSet { save(reiseSpesen,     key: "reiseSpesen") } }
    @Published var privateExpenses: [PrivateExpense] = [] { didSet { save(privateExpenses, key: "privateExpenses") } }
    @Published var favorites:       [FavoriteTrip]   = [] { didSet { saveFavorites() } }
    @Published var recurringTrips:  [RecurringTrip]  = [] { didSet { save(recurringTrips, key: "recurringTrips") } }

    // MARK: - Einstellungen (lokal in UserDefaults)
    @Published var kmRate: Double { didSet { local.set(kmRate, forKey: "kmRate") } }
    @Published var defaultFuelConsumption: Double { didSet { local.set(defaultFuelConsumption, forKey: "defaultFuelConsumption") } }

    @Published var inlandMeal1to3:  Double { didSet { local.set(inlandMeal1to3,  forKey: "inlandMeal1to3") } }
    @Published var inlandMeal3to6:  Double { didSet { local.set(inlandMeal3to6,  forKey: "inlandMeal3to6") } }
    @Published var inlandMeal6plus: Double { didSet { local.set(inlandMeal6plus, forKey: "inlandMeal6plus") } }
    @Published var swissMeal1to3:   Double { didSet { local.set(swissMeal1to3,   forKey: "swissMeal1to3") } }
    @Published var swissMeal3to6:   Double { didSet { local.set(swissMeal3to6,   forKey: "swissMeal3to6") } }
    @Published var swissMeal6plus:  Double { didSet { local.set(swissMeal6plus,  forKey: "swissMeal6plus") } }
    @Published var abroadMeal1to3:  Double { didSet { local.set(abroadMeal1to3,  forKey: "abroadMeal1to3") } }
    @Published var abroadMeal3to6:  Double { didSet { local.set(abroadMeal3to6,  forKey: "abroadMeal3to6") } }
    @Published var abroadMeal6plus: Double { didSet { local.set(abroadMeal6plus, forKey: "abroadMeal6plus") } }
    @Published var hotelFlat:       Double { didSet { local.set(hotelFlat,       forKey: "hotelFlat") } }
    @Published var breakfastFlat:   Double { didSet { local.set(breakfastFlat,   forKey: "breakfastFlat") } }
    @Published var monteurszulageInland:  Double { didSet { local.set(monteurszulageInland,  forKey: "monteurszulageInland") } }
    @Published var monteurszulageSchweiz: Double { didSet { local.set(monteurszulageSchweiz, forKey: "monteurszulageSchweiz") } }
    @Published var monteurszulageAusland: Double { didSet { local.set(monteurszulageAusland, forKey: "monteurszulageAusland") } }
    @Published var werkOrt: String { didSet { local.set(werkOrt, forKey: "werkOrt") } }
    /// Wechselkurs 1 EUR = eurChfRate CHF (offizielle Notierungsrichtung), da Verpflegung
    /// und Monteurszulage in der Schweiz in CHF ausgezahlt werden, alle Summen/Erstattungen
    /// aber in € geführt werden. Wird automatisch alle 14 Tage aktualisiert (Frankfurter-API,
    /// EZB-Referenzkurse) – siehe refreshEurChfRateIfNeeded().
    @Published var eurChfRate: Double { didSet { local.set(eurChfRate, forKey: "eurChfRate") } }
    @Published var chfRateUpdatedAt: Date? {
        didSet { local.set(chfRateUpdatedAt?.timeIntervalSince1970, forKey: "chfRateUpdatedAt") }
    }
    /// Wochenend-/Feiertagszulage pauschal pro Tag: Inland (€) + Schweiz (CHF) = "Europa"-Tarif,
    /// Ausland (€) = "Übrige Gebiete"-Tarif.
    @Published var wochenendzulageInland:  Double { didSet { local.set(wochenendzulageInland,  forKey: "wochenendzulageInland") } }
    @Published var wochenendzulageSchweiz: Double { didSet { local.set(wochenendzulageSchweiz, forKey: "wochenendzulageSchweiz") } }
    @Published var wochenendzulageAusland: Double { didSet { local.set(wochenendzulageAusland, forKey: "wochenendzulageAusland") } }

    // MARK: - Init
    init() {
        // Einstellungen laden
        kmRate                 = local.double(forKey: "kmRate").ifZero(Constants.kmRate)
        defaultFuelConsumption = local.double(forKey: "defaultFuelConsumption").ifZero(Constants.defaultFuelConsumption)
        inlandMeal1to3  = local.double(forKey: "inlandMeal1to3").ifZeroAllowed(Constants.inlandMeal1to3)
        inlandMeal3to6  = local.double(forKey: "inlandMeal3to6").ifZero(Constants.inlandMeal3to6)
        inlandMeal6plus = local.double(forKey: "inlandMeal6plus").ifZero(Constants.inlandMeal6plus)
        swissMeal1to3   = local.double(forKey: "swissMeal1to3").ifZeroAllowed(Constants.swissMeal1to3)
        swissMeal3to6   = local.double(forKey: "swissMeal3to6").ifZero(Constants.swissMeal3to6)
        swissMeal6plus  = local.double(forKey: "swissMeal6plus").ifZero(Constants.swissMeal6plus)
        abroadMeal1to3  = local.double(forKey: "abroadMeal1to3").ifZeroAllowed(Constants.abroadMeal1to3)
        abroadMeal3to6  = local.double(forKey: "abroadMeal3to6").ifZero(Constants.abroadMeal3to6)
        abroadMeal6plus = local.double(forKey: "abroadMeal6plus").ifZero(Constants.abroadMeal6plus)
        hotelFlat       = local.double(forKey: "hotelFlat").ifZero(Constants.hotelFlat)
        breakfastFlat   = local.double(forKey: "breakfastFlat").ifZero(Constants.breakfastFlat)
        monteurszulageInland  = local.double(forKey: "monteurszulageInland").ifZeroAllowed(Constants.monteurszulageInland)
        monteurszulageSchweiz = local.double(forKey: "monteurszulageSchweiz").ifZeroAllowed(Constants.monteurszulageSchweiz)
        monteurszulageAusland = local.double(forKey: "monteurszulageAusland").ifZeroAllowed(Constants.monteurszulageAusland)
        werkOrt = local.string(forKey: "werkOrt") ?? Constants.werkOrt
        eurChfRate = local.double(forKey: "eurChfRate").ifZero(Constants.eurChfRate)
        if let ts = local.object(forKey: "chfRateUpdatedAt") as? Double {
            chfRateUpdatedAt = Date(timeIntervalSince1970: ts)
        } else {
            chfRateUpdatedAt = nil
        }
        wochenendzulageInland  = local.double(forKey: "wochenendzulageInland").ifZeroAllowed(Constants.wochenendzulageInland)
        wochenendzulageSchweiz = local.double(forKey: "wochenendzulageSchweiz").ifZeroAllowed(Constants.wochenendzulageSchweiz)
        wochenendzulageAusland = local.double(forKey: "wochenendzulageAusland").ifZeroAllowed(Constants.wochenendzulageAusland)

        // SCHRITT 1: Migration einmalig ausführen (Standard → App Group)
        migrateFromStandardToAppGroup()

        // SCHRITT 2: Sofort lokale Daten laden (UserDefaults – immer verfügbar)
        loadFromLocal()
        favorites      = loadLocal(key: "favorites")      ?? []
        recurringTrips = loadLocal(key: "recurringTrips") ?? []
        
        // TEMPORÄR DEBUG
        let ag = UserDefaults(suiteName: "group.de.tommwagner.fahrtkosten")
        AppLogger.shared.logData("App Group nil: \(ag == nil)")
        AppLogger.shared.logData("App Group ID: \(ag?.description ?? "NIL")")
        // ENDE DEBUG

        // SCHRITT 3: iCloud starten
        icloud.synchronize()

        // SCHRITT 4: Observer für externe iCloud-Änderungen (anderes Gerät)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(icloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: icloud
        )

        // SCHRITT 5: iCloud-Daten verzögert zusammenführen (nach synchronize)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.mergeFromiCloud()
        }

        // SCHRITT 6: EUR/CHF-Kurs bei Bedarf aktualisieren (alle 14 Tage)
        Task { @MainActor [weak self] in
            await self?.refreshEurChfRateIfNeeded()
        }
    }

    // MARK: - EUR/CHF-Wechselkurs (automatisch alle 14 Tage, Frankfurter-API/EZB)
    private static let chfRateMaxAge: TimeInterval = 14 * 24 * 60 * 60

    /// Lädt bei Bedarf den aktuellen EUR→CHF-Referenzkurs nach – nur wenn seit dem letzten
    /// erfolgreichen Abruf mindestens 14 Tage vergangen sind (oder noch nie abgerufen wurde).
    /// Schlägt der Abruf fehl (z. B. kein Internet), bleibt der bisherige Kurs unverändert und
    /// wird beim nächsten App-Start erneut versucht.
    func refreshEurChfRateIfNeeded(force: Bool = false) async {
        if !force, let last = chfRateUpdatedAt, Date().timeIntervalSince(last) < Self.chfRateMaxAge {
            return
        }
        guard let url = URL(string: "https://api.frankfurter.dev/v2/rate/EUR/CHF") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(FrankfurterRateResponse.self, from: data)
            guard decoded.rate > 0 else { return }
            eurChfRate = decoded.rate
            chfRateUpdatedAt = Date()
            AppLogger.shared.log("EUR/CHF-Kurs aktualisiert: 1 EUR = \(decoded.rate) CHF", level: .store)
        } catch {
            AppLogger.shared.logError("EUR/CHF-Kurs konnte nicht aktualisiert werden: \(error.localizedDescription)")
        }
    }

    // MARK: - Migration: UserDefaults.standard → App Group (einmalig)
    private func migrateFromStandardToAppGroup() {
        let migrationKey = "appgroup_migration_done_v1"
        let standard = UserDefaults.standard

        // Bereits migriert?
        guard !local.bool(forKey: migrationKey) else { return }

        // Nur migrieren wenn App Group leer aber Standard noch Daten hat
        let keys = ["trips", "meals", "hotels", "vehicleCosts", "reiseSpesen", "privateExpenses"]
        var migrated = 0
        for key in keys {
            if local.data(forKey: key) == nil,
               let data = standard.data(forKey: key) {
                local.set(data, forKey: key)
                // Auch gleich in iCloud
                icloud.set(data, forKey: key)
                migrated += 1
            }
        }

        // Einstellungen migrieren
        let settingsKeys = ["kmRate", "defaultFuelConsumption", "inlandMeal1to3",
                           "inlandMeal3to6", "inlandMeal6plus", "swissMeal1to3",
                           "swissMeal3to6", "swissMeal6plus", "abroadMeal1to3",
                           "abroadMeal3to6", "abroadMeal6plus", "hotelFlat", "breakfastFlat"]
        for key in settingsKeys {
            if local.object(forKey: key) == nil,
               let val = standard.object(forKey: key) {
                local.set(val, forKey: key)
            }
        }

        if migrated > 0 {
            icloud.synchronize()
            AppLogger.shared.logData("Migration Standard→AppGroup: \(migrated) Datensätze übertragen")
        }

        local.set(true, forKey: migrationKey)
    }

    // MARK: - Watch-Fahrt übernehmen (vom WatchSessionManager aufgerufen)
    func reloadFromWatch() {
        if let fresh: [Trip] = loadLocal(key: "trips") {
            trips = fresh
        }
        AppLogger.shared.logData("Watch-Fahrt importiert: \(trips.count) Fahrten gesamt")
    }

    // MARK: - Lokale UserDefaults laden (sofort, kein Warten)
    private func loadFromLocal() {
        trips           = loadLocal(key: "trips")           ?? []
        hotels          = loadLocal(key: "hotels")          ?? []
        vehicleCosts    = loadLocal(key: "vehicleCosts")    ?? []
        reiseSpesen     = loadLocal(key: "reiseSpesen")     ?? []
        privateExpenses = loadLocal(key: "privateExpenses") ?? []

        let rawMeals: [MealEntry] = loadLocal(key: "meals") ?? []
        if rawMeals.contains(where: { $0.breakfastAmount < 0 }) {
            meals = rawMeals.map { var e = $0; if e.breakfastAmount < 0 { e.breakfastAmount = 0 }; return e }
        } else {
            meals = rawMeals
        }
        AppLogger.shared.logData("Lokale Daten geladen: \(trips.count) Fahrten")
    }

    // MARK: - iCloud-Daten zusammenführen (nach 2 Sek. beim Start)
    private func mergeFromiCloud() {
        // Lokale Daten zu iCloud hochladen falls iCloud leer
        let keys = ["trips", "meals", "hotels", "vehicleCosts", "reiseSpesen", "privateExpenses"]
        for key in keys {
            if icloud.data(forKey: key) == nil, let localData = local.data(forKey: key) {
                icloud.set(localData, forKey: key)
                AppLogger.shared.logData("Upload zu iCloud: \(key)")
            }
        }
        icloud.synchronize()

        // iCloud-Daten mit lokalen zusammenführen (alle eindeutigen IDs behalten)
        if let remote: [Trip]           = loadiCloud(key: "trips"),           !remote.isEmpty { trips           = merge(local: trips,           remote: remote) }
        if let remote: [MealEntry]      = loadiCloud(key: "meals"),           !remote.isEmpty { meals           = merge(local: meals,           remote: remote) }
        if let remote: [HotelEntry]     = loadiCloud(key: "hotels"),          !remote.isEmpty { hotels          = merge(local: hotels,          remote: remote) }
        if let remote: [VehicleCost]    = loadiCloud(key: "vehicleCosts"),    !remote.isEmpty { vehicleCosts    = merge(local: vehicleCosts,    remote: remote) }
        if let remote: [ReiseSpese]     = loadiCloud(key: "reiseSpesen"),     !remote.isEmpty { reiseSpesen     = merge(local: reiseSpesen,     remote: remote) }
        if let remote: [PrivateExpense] = loadiCloud(key: "privateExpenses"), !remote.isEmpty { privateExpenses = merge(local: privateExpenses, remote: remote) }

        AppLogger.shared.logData("iCloud-Merge abgeschlossen: \(trips.count) Fahrten")
    }

    /// Zusammenführen: alle eindeutigen IDs aus beiden Listen behalten
    private func merge<T: Identifiable & Codable>(local: [T], remote: [T]) -> [T] {
        var seen = Set<String>()
        var result: [T] = []
        for item in (local + remote) {
            if seen.insert("\(item.id)").inserted {
                result.append(item)
            }
        }
        return result
    }

    // MARK: - iCloud Observer (andere Geräte haben etwas geändert)
    @objc private func icloudDidChange(_ notification: Notification) {
        guard let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        DispatchQueue.main.async {
            if keys.contains("trips"),           let r: [Trip]           = self.loadiCloud(key: "trips")           { self.trips           = self.merge(local: self.trips,           remote: r) }
            if keys.contains("meals"),           let r: [MealEntry]      = self.loadiCloud(key: "meals")           { self.meals           = self.merge(local: self.meals,           remote: r) }
            if keys.contains("hotels"),          let r: [HotelEntry]     = self.loadiCloud(key: "hotels")          { self.hotels          = self.merge(local: self.hotels,          remote: r) }
            if keys.contains("vehicleCosts"),    let r: [VehicleCost]    = self.loadiCloud(key: "vehicleCosts")    { self.vehicleCosts    = self.merge(local: self.vehicleCosts,    remote: r) }
            if keys.contains("reiseSpesen"),     let r: [ReiseSpese]     = self.loadiCloud(key: "reiseSpesen")     { self.reiseSpesen     = self.merge(local: self.reiseSpesen,     remote: r) }
            if keys.contains("privateExpenses"), let r: [PrivateExpense] = self.loadiCloud(key: "privateExpenses") { self.privateExpenses = self.merge(local: self.privateExpenses, remote: r) }
        }
    }

    // MARK: - Speichern (iCloud + lokales UserDefaults als Backup)
    private func save<T: Codable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        local.set(data, forKey: key)          // lokales Backup immer aktuell
        icloud.set(data, forKey: key)         // iCloud sync
        icloud.synchronize()
    }

    private func loadiCloud<T: Codable>(key: String) -> T? {
        guard let data = icloud.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func loadLocal<T: Codable>(key: String) -> T? {
        guard let data = local.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Meal Rates
    // Schweiz-Sätze sind in CHF hinterlegt und werden hier in € umgerechnet, damit alle
    // nachgelagerten Summen (Erstattung, Export) einheitlich in € rechnen können.
    func mealRates(for region: TravelRegion) -> MealRates {
        switch region {
        case .inland:  return MealRates(rate1to3: inlandMeal1to3,  rate3to6: inlandMeal3to6,  rate6plus: inlandMeal6plus)
        case .schweiz: return MealRates(rate1to3: swissMeal1to3 / eurChfRate, rate3to6: swissMeal3to6 / eurChfRate, rate6plus: swissMeal6plus / eurChfRate)
        case .ausland: return MealRates(rate1to3: abroadMeal1to3,  rate3to6: abroadMeal3to6,  rate6plus: abroadMeal6plus)
        }
    }

    // MARK: - Monteurszulage
    /// Pauschale Zulage: 12 € Inland, 18 CHF Schweiz (umgerechnet via eurChfRate), 50 € Ausland.
    /// Das Werk (Steffisburg) liegt selbst in der Schweiz: Bei Region Schweiz gilt daher immer
    /// die Schweiz-Zulage. Bei Region Ausland mit „Am Werk gearbeitet" (man war faktisch am
    /// Schweizer Werksstandort) gilt ebenfalls die Schweiz-Zulage statt der Auslands-Zulage.
    /// Die Inlands-Zulage gilt ausschließlich, wenn Region Inland direkt gewählt ist.
    /// WICHTIG: Die Monteurszulage wird üblicherweise über den Lohn ausbezahlt (steuer- und
    /// sozialversicherungspflichtiger Arbeitslohn) – NICHT über die steuerfreie Reisekosten-
    /// erstattung nach § 9 EStG. Sie darf deshalb nicht in die Verpflegungspauschale/
    /// Gesamterstattung eingerechnet werden, sondern wird separat ausgewiesen.
    func monteurszulage(for meal: MealEntry) -> Double {
        guard !meal.weekendAwayOnly else { return 0 } // "Wochenende": nicht gearbeitet, keine Zulage
        let h = totalWorkHours(for: meal)
        guard h >= 3 else { return 0 }           // < 3 h: keine Zulage
        let rate: Double
        switch meal.region {
        case .inland:  rate = monteurszulageInland
        case .schweiz: rate = monteurszulageSchweiz / eurChfRate
        case .ausland: rate = meal.workedAtPlant ? (monteurszulageSchweiz / eurChfRate) : monteurszulageAusland
        }
        return h < 6 ? rate * 0.5 : rate         // 3–6 h: 50 %, ab 6 h: voll
    }

    /// Summe der Monteurszulage (Lohnbestandteil) über die übergebenen Einträge – getrennt
    /// von der Spesen-Erstattung, z. B. zum Abgleich mit der Lohnabrechnung.
    func totalMonteurszulage(_ entries: [MealEntry]) -> Double {
        entries.reduce(0) { $0 + monteurszulage(for: $1) }
    }

    // MARK: - Wochenend-/Feiertagszulage
    /// Pauschale Tageszulage: 60 € Inland, 90 CHF Schweiz (umgerechnet via eurChfRate) = "Europa"-
    /// Tarif, 72 € Ausland = "Übrige Gebiete"-Tarif. Gleiche Werk-Logik wie Monteurszulage: bei
    /// Region Ausland mit „Am Werk gearbeitet" gilt die Schweiz-Zulage statt der Auslands-Zulage.
    /// Gilt an Samstagen/Sonntagen oder manuell markierten Feiertagen – NICHT bei Weiterbildung/
    /// Schulung. Kein Stunden-Mindestmaß (Pauschale pro Tag, nicht gestaffelt).
    /// WICHTIG: Wird wie die Monteurszulage über den Lohn ausbezahlt – NICHT Teil der
    /// steuerfreien Verpflegungspauschale/Gesamterstattung, sondern separat ausgewiesen.
    func wochenendzulage(for meal: MealEntry) -> Double {
        guard !meal.isTraining, !meal.weekendAwayOnly else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: meal.date) // 1 = Sonntag, 7 = Samstag
        let isWeekend = weekday == 1 || weekday == 7
        guard isWeekend || meal.isHoliday else { return 0 }
        switch meal.region {
        case .inland:  return wochenendzulageInland
        case .schweiz: return wochenendzulageSchweiz / eurChfRate
        case .ausland: return meal.workedAtPlant ? (wochenendzulageSchweiz / eurChfRate) : wochenendzulageAusland
        }
    }

    /// Summe der Wochenend-/Feiertagszulage (Lohnbestandteil) über die übergebenen Einträge.
    func totalWochenendzulage(_ entries: [MealEntry]) -> Double {
        entries.reduce(0) { $0 + wochenendzulage(for: $1) }
    }

    // MARK: - Totals
    var totalKmAmount:    Double { trips.filter { $0.art == .geschaeftlich }.reduce(0) { $0 + $1.km * kmRate } }
    var totalKm:          Double { trips.filter { $0.art == .geschaeftlich }.reduce(0) { $0 + $1.km } }
    var totalMeal:        Double { meals.reduce(0)           { $0 + $1.allowance(rates: mealRates(for: $1.region)) } }
    var totalHotel:       Double { hotels.reduce(0)          { $0 + $1.amount(flat: hotelFlat) } }
    var totalVehicle:     Double { vehicleCosts.reduce(0)    { $0 + $1.amount } }
    var totalReiseSpesen: Double { reiseSpesen.reduce(0)     { $0 + $1.amount } }
    var totalPrivate:     Double { privateExpenses.reduce(0) { $0 + $1.amount } }

    /// Gesamterstattung = Fahrten + Verpflegung + Hotel
    /// Reisespesen, Fahrzeugkosten und Private Ausgaben sind NICHT enthalten
    var grandTotal: Double { totalKmAmount + totalMeal + totalHotel }

    // MARK: - CRUD
    func addTrip(_ t: Trip)    { trips.append(t); trips.sort { $0.date < $1.date }; AppLogger.shared.logData("Fahrt hinzugefügt: \(t.from) → \(t.to), \(String(format: "%.1f", t.km)) km") }
    func updateTrip(_ t: Trip) { if let i = trips.firstIndex(where: { $0.id == t.id }) { trips[i] = t; trips.sort { $0.date < $1.date }; AppLogger.shared.logData("Fahrt aktualisiert: \(t.from) → \(t.to)") } }
    func deleteTrip(_ id: UUID){ trips.removeAll { $0.id == id }; AppLogger.shared.logData("Fahrt gelöscht") }
    func duplicateTrip(_ trip: Trip) {
        var copy = trip
        copy.id = UUID()
        trips.append(copy)
        trips.sort { $0.date < $1.date }
        AppLogger.shared.logData("Fahrt dupliziert: \(trip.from) → \(trip.to)")
    }

    func addMeal(_ m: MealEntry)    { meals.append(m); meals.sort { $0.date < $1.date }; AppLogger.shared.logData("Speseneintrag hinzugefügt: \(m.region.rawValue), \(String(format: "%.1f", m.hours))h") }
    func updateMeal(_ m: MealEntry) { if let i = meals.firstIndex(where: { $0.id == m.id }) { meals[i] = m; meals.sort { $0.date < $1.date }; AppLogger.shared.logData("Speseneintrag aktualisiert") } }
    func deleteMeal(_ id: UUID)     { meals.removeAll { $0.id == id }; AppLogger.shared.logData("Speseneintrag gelöscht") }
    func duplicateMeal(_ meal: MealEntry) {
        var copy = meal
        copy.id = UUID()
        meals.append(copy)
        meals.sort { $0.date < $1.date }
        AppLogger.shared.logData("Arbeitszeit dupliziert: \(meal.date.shortDate)")
    }

    func addHotel(_ h: HotelEntry)    { hotels.append(h); hotels.sort { $0.date < $1.date }; AppLogger.shared.logData("Übernachtung hinzugefügt: \(h.city), \(h.numberOfNights) Nacht/Nächte") }
    func updateHotel(_ h: HotelEntry) { if let i = hotels.firstIndex(where: { $0.id == h.id }) { hotels[i] = h; hotels.sort { $0.date < $1.date }; AppLogger.shared.logData("Übernachtung aktualisiert") } }
    func deleteHotel(_ id: UUID)      { hotels.removeAll { $0.id == id }; AppLogger.shared.logData("Übernachtung gelöscht") }
    func duplicateHotel(_ hotel: HotelEntry) {
        var copy = hotel
        copy.id = UUID()
        hotels.append(copy)
        hotels.sort { $0.date < $1.date }
        AppLogger.shared.logData("Übernachtung dupliziert: \(hotel.city)")
    }

    func addVehicleCost(_ v: VehicleCost)    { vehicleCosts.append(v); vehicleCosts.sort { $0.date < $1.date }; AppLogger.shared.logData("KFZ-Kosten hinzugefügt: \(v.category.rawValue), \(String(format: "%.2f", v.amount)) €") }
    func updateVehicleCost(_ v: VehicleCost) { if let i = vehicleCosts.firstIndex(where: { $0.id == v.id }) { vehicleCosts[i] = v; vehicleCosts.sort { $0.date < $1.date }; AppLogger.shared.logData("KFZ-Kosten aktualisiert") } }
    func deleteVehicleCost(_ id: UUID)       { vehicleCosts.removeAll { $0.id == id }; AppLogger.shared.logData("KFZ-Kosten gelöscht") }

    func addReiseSpese(_ r: ReiseSpese)    { reiseSpesen.append(r); reiseSpesen.sort { $0.date < $1.date }; AppLogger.shared.logData("Reisespese hinzugefügt: \(r.kategorie.rawValue), \(String(format: "%.2f", r.amount)) €") }
    func updateReiseSpese(_ r: ReiseSpese) { if let i = reiseSpesen.firstIndex(where: { $0.id == r.id }) { reiseSpesen[i] = r; reiseSpesen.sort { $0.date < $1.date }; AppLogger.shared.logData("Reisespese aktualisiert") } }
    func deleteReiseSpese(_ id: UUID)      { reiseSpesen.removeAll { $0.id == id }; AppLogger.shared.logData("Reisespese gelöscht") }

    func addPrivateExpense(_ p: PrivateExpense)    { privateExpenses.append(p); privateExpenses.sort { $0.date < $1.date }; AppLogger.shared.logData("Private Ausgabe hinzugefügt: \(String(format: "%.2f", p.amount)) €") }
    func updatePrivateExpense(_ p: PrivateExpense) { if let i = privateExpenses.firstIndex(where: { $0.id == p.id }) { privateExpenses[i] = p; privateExpenses.sort { $0.date < $1.date }; AppLogger.shared.logData("Private Ausgabe aktualisiert") } }
    func deletePrivateExpense(_ id: UUID)          { privateExpenses.removeAll { $0.id == id }; AppLogger.shared.logData("Private Ausgabe gelöscht") }

    func addFavorite(from trip: Trip) {
        guard !favorites.contains(where: { $0.from == trip.from && $0.to == trip.to }) else { return }
        favorites.append(FavoriteTrip(from: trip.from, to: trip.to, km: trip.km))
        AppLogger.shared.logData("Favorit gespeichert: \(trip.from) → \(trip.to)")
    }
    func deleteFavorite(_ id: UUID) {
        favorites.removeAll { $0.id == id }
        AppLogger.shared.logData("Favorit gelöscht")
    }
    private func saveFavorites() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        local.set(data, forKey: "favorites")
    }

    // MARK: - Wiederkehrende Fahrten
    func addRecurringTrip(_ trip: RecurringTrip) {
        recurringTrips.append(trip)
        AppLogger.shared.logData("Wiederkehrende Fahrt hinzugefügt: \(trip.from) → \(trip.to)")
    }
    func updateRecurringTrip(_ trip: RecurringTrip) {
        if let i = recurringTrips.firstIndex(where: { $0.id == trip.id }) {
            recurringTrips[i] = trip
        }
    }
    func deleteRecurringTrip(_ id: UUID) {
        recurringTrips.removeAll { $0.id == id }
    }
    func toggleRecurringTrip(_ id: UUID) {
        if let i = recurringTrips.firstIndex(where: { $0.id == id }) {
            recurringTrips[i].isActive.toggle()
        }
    }
    /// Gibt alle aktiven Fahrten zurück, die auf den heutigen Wochentag passen
    func todaysRecurringTrips() -> [RecurringTrip] {
        recurringTrips.filter { $0.matchesToday() }
    }

    func resetMealRatesToDefaults() {
        inlandMeal1to3  = Constants.inlandMeal1to3;  inlandMeal3to6  = Constants.inlandMeal3to6;  inlandMeal6plus = Constants.inlandMeal6plus
        swissMeal1to3   = Constants.swissMeal1to3;   swissMeal3to6   = Constants.swissMeal3to6;   swissMeal6plus  = Constants.swissMeal6plus
        abroadMeal1to3  = Constants.abroadMeal1to3;  abroadMeal3to6  = Constants.abroadMeal3to6;  abroadMeal6plus = Constants.abroadMeal6plus
        breakfastFlat   = Constants.breakfastFlat
        AppLogger.shared.logData("Pauschalsätze auf Standardwerte zurückgesetzt")
    }
}

private extension Double {
    func ifZero(_ fallback: Double) -> Double { self == 0 ? fallback : self }
    func ifZeroAllowed(_ fallback: Double) -> Double { self == 0 ? fallback : self }
}

// MARK: - Verpflegungsberechnung mit Fahrzeit
extension DataStore {

    /// Verpflegungspauschale für Tage mit nur Fahrten (kein MealEntry).
    func mealAllowanceForTripsOnly(_ dayTrips: [Trip]) -> Double {
        guard let refDate = dayTrips.first?.date else { return 0 }
        let cal = Calendar.current
        // Alle Trips des Tages frisch aus dem Store – identisch zu adjustedMealAllowance
        let allDayTrips = trips.filter { cal.isDate($0.date, inSameDayAs: refDate) && $0.art == .geschaeftlich }
        let totalH = totalWorkHoursForTripsOnly(allDayTrips)
        guard totalH > 0 else { return 0 }
        let rates = mealRates(for: .inland)
        let homeAddress = local.string(forKey: "homeAddress")
            ?? UserDefaults.standard.string(forKey: "homeAddress") ?? ""
        let returnsHome = !homeAddress.isEmpty &&
            allDayTrips.contains { $0.to.localizedCaseInsensitiveContains(homeAddress) }
        let endsLate = allDayTrips.compactMap { $0.endTime }.contains { d in
            let h = cal.component(.hour, from: d); let m = cal.component(.minute, from: d)
            return h > 19 || (h == 19 && m >= 30)
        }
        switch totalH {
        case ..<3:  return rates.rate1to3
        case ..<6:  return rates.rate3to6
        default:    return (returnsHome && !endsLate) ? rates.rate3to6 : rates.rate6plus
        }
    }

    func totalWorkHoursForTripsOnly(_ dayTrips: [Trip]) -> Double {
        let timed = dayTrips.filter { $0.startTime != nil && $0.endTime != nil }
        if !timed.isEmpty {
            let cal = Calendar.current
            func toSec(_ d: Date) -> Double {
                Double(cal.component(.hour, from: d) * 3600 + cal.component(.minute, from: d) * 60)
            }
            let earliest = timed.compactMap { $0.startTime }.map(toSec).min() ?? 0
            let latest   = timed.compactMap { $0.endTime   }.map(toSec).max() ?? 0
            return max(0, (latest - earliest) / 3600.0)
        }
        // Fallback: nur fahrzeitText summieren
        return dayTrips.reduce(0.0) { acc, trip in
            guard let text = trip.fahrzeitText ?? trip.durationText, !text.isEmpty else { return acc }
            return acc + parseFahrzeitText(text)
        }
    }

    func adjustedMealAllowance(for meal: MealEntry) -> Double {
        let totalH = totalWorkHours(for: meal)
        let rates = mealRates(for: meal.region)

        // Wenn Zielort einer Fahrt des gleichen Tages = Heimatort:
        // Kein Abendessen abzugsfähig → nur 50 % Pauschale (rate3to6), auch bei ≥ 6 h.
        let homeAddress = local.string(forKey: "homeAddress")
            ?? UserDefaults.standard.string(forKey: "homeAddress")
            ?? ""
        let cal = Calendar.current
        let dayTrips = trips.filter { cal.isDate($0.date, inSameDayAs: meal.date) && $0.art == .geschaeftlich }

        let returnsHome: Bool = !homeAddress.isEmpty &&
            dayTrips.contains { $0.to.localizedCaseInsensitiveContains(homeAddress) }

        // Volle Pauschale gilt wieder, wenn Reiseende ≥ 19:30 Uhr
        let endsLate: Bool = {
            var endCandidates: [Date] = dayTrips.compactMap { $0.endTime }
            endCandidates.append(meal.endTime)
            return endCandidates.contains { date in
                let h = cal.component(.hour,   from: date)
                let m = cal.component(.minute, from: date)
                return h > 19 || (h == 19 && m >= 30)
            }
        }()

        let raw: Double
        if meal.weekendAwayOnly {
            // "Wochenende" (unterwegs/nicht zuhause, nicht gearbeitet): immer volle Tagespauschale
            raw = rates.rate6plus
        } else {
            switch totalH {
            case ..<3:  raw = rates.rate1to3
            case ..<6:  raw = rates.rate3to6
            default:    raw = (returnsHome && !endsLate) ? rates.rate3to6 : rates.rate6plus
            }
        }
        return max(0, raw - meal.breakfastAmount) + meal.ownBreakfastAmount
    }

    func totalWorkHours(for meal: MealEntry) -> Double {
        // Wenn Fahrten explizit ausgeschlossen: nur eigene Arbeitszeit
        if meal.excludeTrips { return meal.hours }

        let cal = Calendar.current
        let dayTrips = trips.filter { cal.isDate($0.date, inSameDayAs: meal.date) && $0.art == .geschaeftlich }
        // Alle MealEntries des gleichen Tages einbeziehen – nicht nur den aktuellen
        let dayMeals = meals.filter { cal.isDate($0.date, inSameDayAs: meal.date) && !$0.excludeTrips }

        let tripsWithTimes = dayTrips.filter { $0.startTime != nil && $0.endTime != nil }
        if !tripsWithTimes.isEmpty {
            // Span über alle Meals + Fahrten des Tages aufspannen
            var allStarts: [Date] = dayMeals.map { $0.startTime }
            var allEnds:   [Date] = dayMeals.map { $0.endTime }
            allStarts += tripsWithTimes.compactMap { $0.startTime }
            allEnds   += tripsWithTimes.compactMap { $0.endTime }

            func toSeconds(_ d: Date) -> Double {
                let h = cal.component(.hour,   from: d)
                let m = cal.component(.minute, from: d)
                let s = cal.component(.second, from: d)
                return Double(h * 3600 + m * 60 + s)
            }
            let earliest = allStarts.map(toSeconds).min() ?? 0
            let latest   = allEnds.map(toSeconds).max()   ?? 0
            let spanH = max(0, (latest - earliest) / 3600.0)

            // Fahrten ohne Zeitstempel aber mit expliziter Fahrzeit separat addieren
            let tripsWithoutTimes = dayTrips.filter { $0.startTime == nil || $0.endTime == nil }
            let extraH = tripsWithoutTimes.reduce(0.0) { acc, trip in
                guard let text = trip.fahrzeitText, !text.isEmpty else { return acc }
                return acc + parseFahrzeitText(text)
            }
            return spanH + extraH
        }

        // Fallback: Keine Fahrt hat Zeitstempel.
        // Alle Arbeitszeiten des Tages + explizit eingetragene Fahrzeiten summieren.
        let workH = dayMeals.reduce(0.0) { $0 + $1.hours }
        let driveH = dayTrips.reduce(0.0) { acc, trip in
            guard let text = trip.fahrzeitText, !text.isEmpty else { return acc }
            return acc + parseFahrzeitText(text)
        }
        return workH + driveH
    }

    private func parseFahrzeitText(_ text: String) -> Double {
        var h = 0.0
        if let r = text.range(of: "([0-9]+)h", options: .regularExpression) {
            h += Double(String(text[r]).filter { $0.isNumber }) ?? 0
        }
        if let r = text.range(of: "([0-9]+)\\s*min", options: .regularExpression) {
            h += (Double(String(text[r]).filter { $0.isNumber }) ?? 0) / 60.0
        }
        return h
    }
}
