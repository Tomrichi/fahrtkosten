import Foundation
import Combine

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

        // SCHRITT 1: Migration einmalig ausführen (Standard → App Group)
        migrateFromStandardToAppGroup()

        // SCHRITT 2: Sofort lokale Daten laden (UserDefaults – immer verfügbar)
        loadFromLocal()
        favorites = loadLocal(key: "favorites") ?? []
        
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
    func mealRates(for region: TravelRegion) -> MealRates {
        switch region {
        case .inland:  return MealRates(rate1to3: inlandMeal1to3,  rate3to6: inlandMeal3to6,  rate6plus: inlandMeal6plus)
        case .schweiz: return MealRates(rate1to3: swissMeal1to3,   rate3to6: swissMeal3to6,   rate6plus: swissMeal6plus)
        case .ausland: return MealRates(rate1to3: abroadMeal1to3,  rate3to6: abroadMeal3to6,  rate6plus: abroadMeal6plus)
        }
    }

    // MARK: - Totals
    var totalKmAmount:    Double { trips.reduce(0)           { $0 + $1.km * kmRate } }
    var totalKm:          Double { trips.reduce(0)           { $0 + $1.km } }
    var totalMeal:        Double { meals.reduce(0)           { $0 + $1.allowance(rates: mealRates(for: $1.region)) } }
    var totalHotel:       Double { hotels.reduce(0)          { $0 + $1.amount(flat: hotelFlat) } }
    var totalVehicle:     Double { vehicleCosts.reduce(0)    { $0 + $1.amount } }
    var totalReiseSpesen: Double { reiseSpesen.reduce(0)     { $0 + $1.amount } }
    var totalPrivate:     Double { privateExpenses.reduce(0) { $0 + $1.amount } }

    /// Gesamterstattung = Fahrten + Verpflegung + Hotel
    /// Reisespesen, Fahrzeugkosten und Private Ausgaben sind NICHT enthalten
    var grandTotal: Double { totalKmAmount + totalMeal + totalHotel }

    // MARK: - CRUD
    func addTrip(_ t: Trip)    { trips.append(t); AppLogger.shared.logData("Fahrt hinzugefügt: \(t.from) → \(t.to), \(String(format: "%.1f", t.km)) km") }
    func updateTrip(_ t: Trip) { if let i = trips.firstIndex(where: { $0.id == t.id }) { trips[i] = t; AppLogger.shared.logData("Fahrt aktualisiert: \(t.from) → \(t.to)") } }
    func deleteTrip(_ id: UUID){ trips.removeAll { $0.id == id }; AppLogger.shared.logData("Fahrt gelöscht") }
    func duplicateTrip(_ trip: Trip) {
        var copy = trip
        copy.id = UUID()
        trips.append(copy)
        AppLogger.shared.logData("Fahrt dupliziert: \(trip.from) → \(trip.to)")
    }

    func addMeal(_ m: MealEntry)    { meals.append(m); AppLogger.shared.logData("Speseneintrag hinzugefügt: \(m.region.rawValue), \(String(format: "%.1f", m.hours))h") }
    func updateMeal(_ m: MealEntry) { if let i = meals.firstIndex(where: { $0.id == m.id }) { meals[i] = m; AppLogger.shared.logData("Speseneintrag aktualisiert") } }
    func deleteMeal(_ id: UUID)     { meals.removeAll { $0.id == id }; AppLogger.shared.logData("Speseneintrag gelöscht") }
    func duplicateMeal(_ meal: MealEntry) {
        var copy = meal
        copy.id = UUID()
        meals.append(copy)
        AppLogger.shared.logData("Arbeitszeit dupliziert: \(meal.date.shortDate)")
    }

    func addHotel(_ h: HotelEntry)    { hotels.append(h); AppLogger.shared.logData("Übernachtung hinzugefügt: \(h.city), \(h.numberOfNights) Nacht/Nächte") }
    func updateHotel(_ h: HotelEntry) { if let i = hotels.firstIndex(where: { $0.id == h.id }) { hotels[i] = h; AppLogger.shared.logData("Übernachtung aktualisiert") } }
    func deleteHotel(_ id: UUID)      { hotels.removeAll { $0.id == id }; AppLogger.shared.logData("Übernachtung gelöscht") }
    func duplicateHotel(_ hotel: HotelEntry) {
        var copy = hotel
        copy.id = UUID()
        hotels.append(copy)
        AppLogger.shared.logData("Übernachtung dupliziert: \(hotel.city)")
    }

    func addVehicleCost(_ v: VehicleCost)    { vehicleCosts.append(v); AppLogger.shared.logData("KFZ-Kosten hinzugefügt: \(v.category.rawValue), \(String(format: "%.2f", v.amount)) €") }
    func updateVehicleCost(_ v: VehicleCost) { if let i = vehicleCosts.firstIndex(where: { $0.id == v.id }) { vehicleCosts[i] = v; AppLogger.shared.logData("KFZ-Kosten aktualisiert") } }
    func deleteVehicleCost(_ id: UUID)       { vehicleCosts.removeAll { $0.id == id }; AppLogger.shared.logData("KFZ-Kosten gelöscht") }

    func addReiseSpese(_ r: ReiseSpese)    { reiseSpesen.append(r); AppLogger.shared.logData("Reisespese hinzugefügt: \(r.kategorie.rawValue), \(String(format: "%.2f", r.amount)) €") }
    func updateReiseSpese(_ r: ReiseSpese) { if let i = reiseSpesen.firstIndex(where: { $0.id == r.id }) { reiseSpesen[i] = r; AppLogger.shared.logData("Reisespese aktualisiert") } }
    func deleteReiseSpese(_ id: UUID)      { reiseSpesen.removeAll { $0.id == id }; AppLogger.shared.logData("Reisespese gelöscht") }

    func addPrivateExpense(_ p: PrivateExpense)    { privateExpenses.append(p); AppLogger.shared.logData("Private Ausgabe hinzugefügt: \(String(format: "%.2f", p.amount)) €") }
    func updatePrivateExpense(_ p: PrivateExpense) { if let i = privateExpenses.firstIndex(where: { $0.id == p.id }) { privateExpenses[i] = p; AppLogger.shared.logData("Private Ausgabe aktualisiert") } }
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

    func adjustedMealAllowance(for meal: MealEntry) -> Double {
        let totalH = totalWorkHours(for: meal)
        let rates = mealRates(for: meal.region)
        let raw: Double
        switch totalH {
        case ..<3:  raw = rates.rate1to3
        case ..<6:  raw = rates.rate3to6
        default:    raw = rates.rate6plus
        }
        return max(0, raw - meal.breakfastAmount) + meal.ownBreakfastAmount
    }

    func totalWorkHours(for meal: MealEntry) -> Double {
        // Wenn Fahrten explizit ausgeschlossen: nur eigene Arbeitszeit
        if meal.excludeTrips { return meal.hours }

        let cal = Calendar.current
        let dayTrips = trips.filter { cal.isDate($0.date, inSameDayAs: meal.date) }
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
