import Foundation

// MARK: - Constants
struct Constants {
    static let kmRate: Double = 0.30
    static let inlandMeal1to3:  Double = 0.0
    static let inlandMeal3to6:  Double = 0.0
    static let inlandMeal6plus: Double = 0.0
    static let swissMeal1to3:   Double = 0.0
    static let swissMeal3to6:   Double = 0.0
    static let swissMeal6plus:  Double = 0.0
    static let abroadMeal1to3:  Double = 0.0
    static let abroadMeal3to6:  Double = 0.0
    static let abroadMeal6plus: Double = 0.0
    static let hotelFlat:       Double = 20.0
    static let breakfastFlat:   Double = 0.0
    static let defaultFuelConsumption: Double = 7.5
    // Monteurszulage: pauschale Zulage zusätzlich zur Verpflegungspauschale
    static let monteurszulageInland:  Double = 12.0
    static let monteurszulageAusland: Double = 50.0
    static let werkOrt: String = "Steffisburg"
}

// MARK: - Reiseregion
enum TravelRegion: String, Codable, CaseIterable {
    case inland   = "Inland"
    case schweiz  = "Schweiz"
    case ausland  = "Ausland"
    var icon: String {
        switch self {
        case .inland:  return "flag.fill"
        case .schweiz: return "cross.fill"
        case .ausland: return "globe.europe.africa.fill"
        }
    }
    var localizedName: String {
        switch self {
        case .inland:  return L("region.inland")
        case .schweiz: return L("region.schweiz")
        case .ausland: return L("region.ausland")
        }
    }
}

struct MealRates {
    let rate1to3: Double
    let rate3to6: Double
    let rate6plus: Double
}

// MARK: - Trip Model
enum TripArt: String, Codable, CaseIterable {
    case geschaeftlich = "Geschäftlich"
    case privat        = "Privat"
}

struct Trip: Identifiable, Codable {
    var id = UUID()
    var from: String
    var to: String
    var date: Date
    var km: Double
    var note: String
    var art: TripArt = .geschaeftlich
    var distanceText: String?
    var durationText: String?
    var fahrzeitText: String?
    var fuelPricePerLiter: Double?  // Spritpreis €/L zum Fahrzeitpunkt
    var fuelConsumption: Double?    // Verbrauch L/100km
    var fuelTypeRaw: String?        // Kraftstoffart (e5 / e10 / diesel)
    var startTime: Date?            // Abfahrtszeit (Uhrzeit)
    var endTime: Date?              // Ankunftszeit (Uhrzeit)

    var fuelCost: Double? {
        guard km > 0 else { return nil }
        // Hybrid: fuelTypeRaw = "hybrid|benzinPreis|benzinVerbrauch"
        if let raw = fuelTypeRaw, raw.hasPrefix("hybrid|") {
            let parts = raw.split(separator: "|", maxSplits: 3).map(String.init)
            guard parts.count >= 3,
                  let benzinPreis = Double(parts[1].replacingOccurrences(of: ",", with: ".")),
                  let benzinCons  = Double(parts[2].replacingOccurrences(of: ",", with: ".")) else { return nil }
            let benzinCost = (km / 100.0) * benzinCons * benzinPreis
            // Strom-Anteil aus fuelPricePerLiter / fuelConsumption
            let stromCost: Double
            if let p = fuelPricePerLiter, let c = fuelConsumption {
                stromCost = (km / 100.0) * c * p
            } else { stromCost = 0 }
            return benzinCost + stromCost
        }
        guard let price = fuelPricePerLiter, let cons = fuelConsumption else { return nil }
        return (km / 100.0) * cons * price
    }

    enum CodingKeys: String, CodingKey {
        case id, from, to, date, km, note, art, distanceText, durationText, fahrzeitText
        case fuelPricePerLiter, fuelConsumption, fuelTypeRaw, startTime, endTime
    }

    init(id: UUID = UUID(), from: String, to: String, date: Date = Date(),
         km: Double, note: String = "", art: TripArt = .geschaeftlich,
         distanceText: String? = nil,
         durationText: String? = nil, fahrzeitText: String? = nil,
         fuelPricePerLiter: Double? = nil, fuelConsumption: Double? = nil,
         fuelTypeRaw: String? = nil, startTime: Date? = nil, endTime: Date? = nil) {
        self.id = id; self.from = from; self.to = to; self.date = date
        self.km = km; self.note = note; self.art = art; self.distanceText = distanceText
        self.durationText = durationText; self.fahrzeitText = fahrzeitText
        self.fuelPricePerLiter = fuelPricePerLiter; self.fuelConsumption = fuelConsumption
        self.fuelTypeRaw = fuelTypeRaw; self.startTime = startTime; self.endTime = endTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        from = try c.decode(String.self, forKey: .from)
        to = try c.decode(String.self, forKey: .to)
        date = try c.decode(Date.self, forKey: .date)
        km = try c.decode(Double.self, forKey: .km)
        note = try c.decode(String.self, forKey: .note)
        art  = try c.decodeIfPresent(TripArt.self, forKey: .art) ?? .geschaeftlich
        distanceText = try c.decodeIfPresent(String.self, forKey: .distanceText)
        durationText = try c.decodeIfPresent(String.self, forKey: .durationText)
        fahrzeitText = try c.decodeIfPresent(String.self, forKey: .fahrzeitText)
        fuelPricePerLiter = try c.decodeIfPresent(Double.self, forKey: .fuelPricePerLiter)
        fuelConsumption = try c.decodeIfPresent(Double.self, forKey: .fuelConsumption)
        fuelTypeRaw = try c.decodeIfPresent(String.self, forKey: .fuelTypeRaw)
        startTime = try c.decodeIfPresent(Date.self, forKey: .startTime)
        endTime   = try c.decodeIfPresent(Date.self, forKey: .endTime)
    }
}

// MARK: - Favorit-Fahrt
struct FavoriteTrip: Identifiable, Codable {
    var id   = UUID()
    var from : String
    var to   : String
    var km   : Double
}

// MARK: - Wiederkehrende Fahrt
struct RecurringTrip: Identifiable, Codable {
    var id       = UUID()
    var from     : String
    var to       : String
    var km       : Double
    var weekdays : [Int]    // Calendar.weekday: 1=So 2=Mo 3=Di 4=Mi 5=Do 6=Fr 7=Sa
    var note     : String   = ""
    var isActive : Bool     = true

    static let weekdayNames = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

    var weekdayLabel: String {
        weekdays
            .sorted()
            .map { $0 >= 1 && $0 <= 7 ? Self.weekdayNames[$0 - 1] : "?" }
            .joined(separator: ", ")
    }

    func matchesToday() -> Bool {
        guard isActive else { return false }
        let wd = Calendar.current.component(.weekday, from: Date())
        return weekdays.contains(wd)
    }
}

// MARK: - Meal Model
struct MealEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date; var startTime: Date; var endTime: Date; var note: String
    var region: TravelRegion
    var breakfastAmount: Double = 0.0
    var ownBreakfastAmount: Double = 0.0
    var pauseMinutes: Int = 0
    var excludeTrips: Bool = false
    /// Am Werk (Heimatbetrieb) gearbeitet – auch bei Region Schweiz/Ausland gilt dann die Inlands-Zulage
    var workedAtPlant: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, date, startTime, endTime, note, region, breakfastAmount, ownBreakfastAmount, pauseMinutes, excludeTrips, workedAtPlant
    }
    init(id: UUID = UUID(), date: Date, startTime: Date, endTime: Date, note: String,
         region: TravelRegion = .inland, breakfastAmount: Double = 0.0,
         ownBreakfastAmount: Double = 0.0, pauseMinutes: Int = 0, excludeTrips: Bool = false,
         workedAtPlant: Bool = false) {
        self.id = id; self.date = date; self.startTime = startTime; self.endTime = endTime
        self.note = note; self.region = region; self.breakfastAmount = breakfastAmount
        self.ownBreakfastAmount = ownBreakfastAmount; self.pauseMinutes = pauseMinutes
        self.excludeTrips = excludeTrips; self.workedAtPlant = workedAtPlant
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try c.decode(Date.self, forKey: .endTime)
        note = try c.decode(String.self, forKey: .note)
        region = try c.decodeIfPresent(TravelRegion.self, forKey: .region) ?? .inland
        breakfastAmount = try c.decodeIfPresent(Double.self, forKey: .breakfastAmount) ?? 0.0
        ownBreakfastAmount = try c.decodeIfPresent(Double.self, forKey: .ownBreakfastAmount) ?? 0.0
        pauseMinutes = try c.decodeIfPresent(Int.self, forKey: .pauseMinutes) ?? 0
        excludeTrips = try c.decodeIfPresent(Bool.self, forKey: .excludeTrips) ?? false
        workedAtPlant = try c.decodeIfPresent(Bool.self, forKey: .workedAtPlant) ?? false
    }
    var hours: Double { max(0, endTime.timeIntervalSince(startTime) / 3600 - Double(pauseMinutes) / 60) }
    func mealAllowance(rates: MealRates) -> Double {
        switch hours { case ..<3: return rates.rate1to3; case ..<6: return rates.rate3to6; default: return rates.rate6plus }
    }
    func allowance(rates: MealRates) -> Double { max(0, mealAllowance(rates: rates) - breakfastAmount) + ownBreakfastAmount }
    func allowanceLabel(rates: MealRates) -> String {
        switch hours { case ..<3: return L("meals.level.none"); case ..<6: return L("meals.level.2"); default: return L("meals.level.3") }
    }
}

// MARK: - Hotel Model
enum HotelMode: String, Codable, CaseIterable {
    case flat   = "Pauschale"
    case actual = "Tatsächlicher Betrag"
    var localizedName: String {
        switch self { case .flat: return L("hotel.mode.flat"); case .actual: return L("hotel.mode.actual") }
    }
}

struct HotelEntry: Identifiable, Codable {
    var id             = UUID()
    var date           : Date    // Check-in
    var checkOutDate   : Date?   // Check-out (NEU)
    var city           : String
    var hotelName      : String
    var mode           : HotelMode
    var actualCost     : Double  // Gesamtbetrag inkl. MwSt (NEU: immer Gesamtbetrag)
    var numberOfNights : Int     // Anzahl Nächte (NEU)

    enum CodingKeys: String, CodingKey {
        case id, date, checkOutDate, city, hotelName, mode, actualCost, numberOfNights
    }
    init(id: UUID = UUID(), date: Date, checkOutDate: Date? = nil,
         city: String, hotelName: String, mode: HotelMode,
         actualCost: Double, numberOfNights: Int = 1) {
        self.id = id; self.date = date; self.checkOutDate = checkOutDate
        self.city = city; self.hotelName = hotelName; self.mode = mode
        self.actualCost = actualCost; self.numberOfNights = max(1, numberOfNights)
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        checkOutDate = try c.decodeIfPresent(Date.self, forKey: .checkOutDate)
        city = try c.decode(String.self, forKey: .city)
        hotelName = try c.decode(String.self, forKey: .hotelName)
        mode = try c.decode(HotelMode.self, forKey: .mode)
        actualCost = try c.decode(Double.self, forKey: .actualCost)
        numberOfNights = try c.decodeIfPresent(Int.self, forKey: .numberOfNights) ?? 1
    }
    func amount(flat: Double) -> Double {
        switch mode { case .flat: return flat * Double(numberOfNights); case .actual: return actualCost }
    }
    func amountPerNight(flat: Double) -> Double {
        switch mode { case .flat: return flat; case .actual: return actualCost / Double(max(1, numberOfNights)) }
    }
}

// MARK: - Fahrzeugkosten Model
enum VehicleCostCategory: String, Codable, CaseIterable {
    case werkstatt       = "Werkstatt / Reparatur"
    case leasing         = "Leasing"
    case versicherung    = "Versicherung"
    case tuvHu           = "TÜV / HU"
    case steuer          = "KFZ-Steuer"
    case reifen          = "Reifen"
    case strom           = "Strom / Laden"
    case fahrzeugwaesche = "Fahrzeugwäsche"
    case sonstiges       = "Sonstiges"

    var icon: String {
        switch self {
        case .werkstatt:       return "wrench.and.screwdriver.fill"
        case .leasing:         return "car.fill"
        case .versicherung:    return "shield.fill"
        case .tuvHu:           return "checkmark.seal.fill"
        case .steuer:          return "eurosign.circle.fill"
        case .reifen:          return "circle.circle.fill"
        case .strom:           return "bolt.fill"
        case .fahrzeugwaesche: return "sparkles"
        case .sonstiges:       return "car.fill"
        }
    }
    var colorName: String {
        switch self {
        case .werkstatt:       return "orange"
        case .leasing:         return "indigo"
        case .versicherung:    return "blue"
        case .tuvHu:           return "green"
        case .steuer:          return "purple"
        case .reifen:          return "teal"
        case .strom:           return "yellow"
        case .fahrzeugwaesche: return "cyan"
        case .sonstiges:       return "gray"
        }
    }
    var localizedName: String {
        switch self {
        case .werkstatt:       return L("vehicle.cat.werkstatt")
        case .leasing:         return "Leasing"
        case .versicherung:    return L("vehicle.cat.versicherung")
        case .tuvHu:           return L("vehicle.cat.tuev")
        case .steuer:          return L("vehicle.cat.steuer")
        case .reifen:          return L("vehicle.cat.reifen")
        case .strom:           return "Strom / Laden"
        case .fahrzeugwaesche: return "Fahrzeugwäsche"
        case .sonstiges:       return L("vehicle.cat.sonstiges")
        }
    }
}

struct VehicleCost: Identifiable, Codable {
    var id       = UUID()
    var date     : Date
    var category : VehicleCostCategory
    var title    : String
    var amount   : Double
    var note     : String
    var mileage  : Int?
}

// MARK: - Private Ausgaben (NEU – nicht in Gesamterstattung)
struct PrivateExpense: Identifiable, Codable {
    var id = UUID()
    var date: Date; var title: String; var amount: Double; var note: String
    enum CodingKeys: String, CodingKey { case id, date, title, amount, note }
    init(id: UUID = UUID(), date: Date, title: String = "", amount: Double, note: String = "") {
        self.id = id; self.date = date; self.title = title; self.amount = amount; self.note = note
    }
}

// MARK: - Reisespesen Model
enum ReisespesenKategorie: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case werkstatt       = "Werkstatt"
    case leasing         = "Leasing"
    case vignetteMaut    = "Vignette / Maut"
    case benzin          = "Benzin"
    case strom           = "Strom / Laden"
    case kfzSteuer       = "KFZ-Steuer"
    case kfzVersicherung = "KFZ-Versicherung"
    case verpflegung     = "Verpflegung"
    case sonstiges       = "Sonstiges"

    var icon: String {
        switch self {
        case .werkstatt:       return "wrench.and.screwdriver.fill"
        case .leasing:         return "car.fill"
        case .vignetteMaut:    return "road.lanes"
        case .benzin:          return "fuelpump.fill"
        case .strom:           return "bolt.fill"
        case .kfzSteuer:       return "eurosign.circle.fill"
        case .kfzVersicherung: return "shield.fill"
        case .verpflegung:     return "fork.knife.circle.fill"
        case .sonstiges:       return "creditcard.fill"
        }
    }
    var color: String {
        switch self {
        case .werkstatt:       return "orange"
        case .leasing:         return "indigo"
        case .vignetteMaut:    return "blue"
        case .benzin:          return "red"
        case .strom:           return "green"
        case .kfzSteuer:       return "purple"
        case .kfzVersicherung: return "teal"
        case .verpflegung:     return "brown"
        case .sonstiges:       return "gray"
        }
    }
    var localizedName: String { rawValue }

    /// true = gehört zu KFZ-Kosten, false = sonstige Reisespesen
    var isKFZ: Bool {
        switch self {
        case .werkstatt, .leasing, .vignetteMaut, .kfzSteuer, .kfzVersicherung, .strom, .sonstiges:
            return true
        case .benzin, .verpflegung:
            return false
        }
    }
}

struct ReiseSpese: Identifiable, Codable {
    var id = UUID()
    var date: Date; var kategorie: ReisespesenKategorie
    var title: String; var amount: Double; var note: String
    enum CodingKeys: String, CodingKey { case id, date, kategorie, title, amount, note }
    init(id: UUID = UUID(), date: Date, kategorie: ReisespesenKategorie = .sonstiges,
         title: String = "", amount: Double, note: String = "") {
        self.id = id; self.date = date; self.kategorie = kategorie
        self.title = title; self.amount = amount; self.note = note
    }
}
