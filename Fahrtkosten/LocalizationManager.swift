import Foundation
import SwiftUI
import Combine

// MARK: - AppLanguage Enum
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case german = "de"
    case english = "en"
    case polish = "pl"
    case czech = "cs"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .german:    return "Deutsch"
        case .english:   return "English"
        case .polish:    return "Polski"
        case .czech:     return "Čeština"
        }
    }

    var flag: String {
        switch self {
        case .german:    return "🇩🇪"
        case .english:   return "🇬🇧"
        case .polish:    return "🇵🇱"
        case .czech:     return "🇨🇿"
        }
    }
}

// MARK: - LocalizationManager
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: saved) {
            self.language = language
        } else {
            self.language = .german
        }
    }

    func t(_ key: String) -> String {
        return translations[language]?[key] ?? translations[.german]?[key] ?? key
    }
}

// MARK: - Global localization function
func L(_ key: String) -> String {
    return LocalizationManager.shared.t(key)
}

// MARK: - Translations Dictionary
let translations: [AppLanguage: [String: String]] = [
    .german: [
        // Actions
        "action.add": "Hinzufügen",
        "action.edit": "Bearbeiten",
        "action.delete": "Löschen",
        "action.cancel": "Abbrechen",
        "action.save": "Speichern",
        "action.done": "Fertig",
        "action.close": "Schließen",

        // Common
        "common.optional": "Optional",
        "common.note": "Notiz",
        "common.date": "Datum",
        "common.amount": "Betrag",
        "common.region": "Region",

        // Tabs
        "tab.trips": "Fahrten",
        "tab.meals": "Verpflegung",
        "tab.accommodation": "Übernachtung",
        "tab.vehicle": "Fahrzeug",
        "tab.overview": "Übersicht",

        // TravelRegion
        "region.inland": "Inland",
        "region.schweiz": "Schweiz",
        "region.ausland": "Ausland",

        // HotelMode
        "hotel.mode.flat": "Pauschale",
        "hotel.mode.actual": "Tatsächlicher Betrag",

        // VehicleCostCategory
        "vehicle.cat.werkstatt": "Werkstatt / Reparatur",
        "vehicle.cat.versicherung": "Versicherung",
        "vehicle.cat.tuev": "TÜV / HU",
        "vehicle.cat.steuer": "KFZ-Steuer",
        "vehicle.cat.reifen": "Reifen",
        "vehicle.cat.leasing":      "Leasing",
        "vehicle.cat.sonstiges": "Sonstiges",

        // Overview
        "overview.empty.title": "Keine Daten",
        "overview.empty.subtitle": "Erfasse Fahrten, Verpflegung oder\nÜbernachtungen",
        "overview.total": "Gesamterstattung",
        "overview.trips.unit": "Fahrten",
        "overview.days.unit": "Tage",
        "overview.nights.unit": "Nächte",
        "overview.accommodation.short": "Übernacht.",

        // Trips
        "trips.gps.tile": "GPS starten",
        "trips.new.tile": "Neue\nFahrt",
        "trips.empty.title": "Keine Fahrten",
        "trips.empty.subtitle": "Starte eine GPS-Aufzeichnung oder füge eine Fahrt manuell hinzu",
        "trips.all": "Alle Fahrten",
        "trips.unit": "Fahrt(en)",
        "trips.form.new": "Neue Fahrt",
        "trips.form.edit": "Fahrt bearbeiten",
        "trips.from": "Von",
        "trips.to": "Nach",
        "trips.km.label": "Kilometer",
        "trips.result": "Ergebnis",
        "trips.distance": "Strecke",
        "trips.rate": "Pauschale",
        "trips.reimbursement": "Erstattung",
        "trips.start": "Startort",
        "trips.destination": "Zielort",
        "trips.route": "Route",
        "trips.navigation.section": "Navigation",
        "trips.calculation": "Berechnung",
        "trips.maps.title": "Maps-Integration",
        "trips.maps.subtitle": "Automatische Routenberechnung · nur in Pro",
        "trips.maps.open": "Navigation öffnen mit",
        "trips.apple.maps": "Apple Karten",
        "trips.google.maps": "Google Maps",
        "trips.maps.open.btn": "In Maps öffnen",
        "trips.auto.label": "Automatisch",
        "trips.auto.hint": "Start und Ziel eingeben – km werden automatisch eingetragen",
        "trips.auto.calc": "Wird automatisch berechnet…",
        "trips.route.computing": "Route wird automatisch berechnet…",
        "trips.route.error": "Bitte Start- und Zielort prüfen",
        "trips.live.route": "Live-Route",
        "trips.gps.title": "GPS-Fahrt",
        "trips.gps.heading": "GPS-Fahrt aufzeichnen",
        "trips.gps.desc": "Die gefahrene Strecke wird per GPS gemessen\nund automatisch übertragen.",
        "trips.gps.startbtn": "Aufzeichnung starten",
        "trips.gps.running": "Aufzeichnung läuft",
        "trips.gps.stop": "Fahrt beenden & übertragen",
        "trips.gps.permission": "Standortberechtigung wird angefragt…",
        "trips.gps.permission.desc": "Bitte erlaube den Standortzugriff im Dialog.",
        "trips.gps.geocoding": "Adressen werden ermittelt…",
        "trips.gps.geocoding.wait": "Einen Moment bitte",
        "trips.gps.detected": "GPS-Fahrt erkannt",
        "trips.gps.detected.desc": "Strecke, Start und Ziel wurden automatisch ermittelt. Bitte prüfen und ggf. korrigieren.",
        "trips.gps.waiting": "Warte auf GPS…",
        "trips.nav.start": "Navigation starten",

        // Meals
        "meals.add": "Verpflegung hinzufügen",
        "meals.add.hint": "Tippe um einen Tag hinzuzufügen",
        "meals.all": "Alle Einträge",
        "meals.unit": "Tag(e)",
        "meals.form.new": "Neue Verpflegung",
        "meals.form.edit": "Eintrag bearbeiten",
        "meals.region": "Reiseregion",
        "meals.absence": "Arbeitszeit gesamt",
        "meals.begin": "Beginn",
        "meals.end": "Ende",
        "meals.result": "Ergebnis",
        "meals.absence.label": "Arbeitszeit",
        "meals.level": "Stufe",
        "meals.allowance": "Verpflegungspauschale",
        "meals.badge.none": "Keine",
        "meals.level.none": "Keine (< 1 h)",
        "meals.level.1": "Stufe 1 (1–3 h)",
        "meals.level.2": "Stufe 2 (3–6 h)",
        "meals.level.3": "Stufe 3 (ab 6 h)",

        // Accommodation
        "hotel.title": "Übernachtungen",
        "hotel.add": "Übernachtung hinzufügen",
        "hotel.add.hint": "Tippe um eine Übernachtung hinzuzufügen",
        "hotel.all": "Alle Übernachtungen",
        "hotel.unit": "Nacht/Nächte",
        "hotel.section": "Übernachtung",
        "hotel.form.new": "Neue Übernachtung",
        "hotel.form.edit": "Übernachtung bearbeiten",
        "hotel.city": "Stadt / Ort",
        "hotel.city.placeholder": "z.B. Berlin",
        "hotel.name": "Hotel",
        "hotel.billing": "Abrechnungsart",
        "hotel.type": "Art",
        "hotel.cost": "Betrag (€)",
        "hotel.reimbursement": "Erstattung",
        "hotel.flat.label": "Übernachtungspauschale",
        "hotel.actual.cost": "Tatsächliche Kosten",
        "hotel.flat.badge": "Pauschale",
        "hotel.actual.badge": "Ist-Betrag",
        "hotel.info": "Pauschale %@ / Nacht. Übersteigen die tatsächlichen Kosten die Pauschale, wird der volle Betrag erstattet.",
        "hotel.over.flat": "Über Pauschale (%@)",

        // Vehicle
        "vehicle.title": "Fahrzeugkosten",
        "vehicle.add": "Fahrzeugkosten hinzufügen",
        "vehicle.add.hint": "Werkstatt, Versicherung oder andere KFZ-Kosten",
        "vehicle.unit": "Eintrag/Einträge",
        "vehicle.form.new": "Neue Kosten",
        "vehicle.form.edit": "Kosten bearbeiten",
        "vehicle.category.section": "Kategorie",
        "vehicle.details": "Details",
        "vehicle.title.label": "Bezeichnung",
        "vehicle.mileage": "Kilometerstand (km)",
        "vehicle.summary": "Zusammenfassung",

        // Settings
        "settings.title": "Einstellungen",
        "settings.km.title": "Kilometererstattung",
        "settings.km.rate": "Km-Pauschale",
        "settings.km.footer": "Steuerlicher Höchstsatz 2026: 0,38 € / km für Pkw",
        "settings.meals.title": "Verpflegungspauschalen",
        "settings.meals.footer": "Alle Beträge frei konfigurierbar. Pauschalen unter 1 h Abwesenheit sind immer 0 €.",
        "settings.hotel.footer": "Standard Deutschland: 20,00 € / Nacht (§ 9 Abs. 1 Nr. 5a EStG). Grenzgänger mit Schweizer Arbeitgeber und Tätigkeit in Deutschland: bitte individuell prüfen. Individuelle Beträge können frei eingetragen werden.",
        "settings.hours.1to3": "1 – 3 Stunden",
        "settings.hours.3to6": "3 – 6 Stunden",
        "settings.hours.6plus": "Ab 6 Stunden",
        "settings.reset": "Auf Standardwerte zurücksetzen",
        "settings.diagnosis": "Diagnose",
        "settings.feedback": "Feedback & Support",
        "settings.log": "Fehlerprotokoll",
        "settings.info": "Info & Rechtliches",
        "settings.privacy": "Datenschutz",
        "settings.help": "App Features & Hilfe",
        "settings.imprint": "Impressum",
        "settings.language": "Sprache",
        "settings.language.section": "App-Sprache",
        "settings.log.empty": "Keine Einträge.",
        "settings.log.clear": "Protokoll löschen?",
    ],

    .english: [
        // Actions
        "action.add": "Add",
        "action.edit": "Edit",
        "action.delete": "Delete",
        "action.cancel": "Cancel",
        "action.save": "Save",
        "action.done": "Done",
        "action.close": "Close",

        // Common
        "common.optional": "Optional",
        "common.note": "Note",
        "common.date": "Date",
        "common.amount": "Amount",
        "common.region": "Region",

        // Tabs
        "tab.trips": "Trips",
        "tab.meals": "Meals",
        "tab.accommodation": "Accommodation",
        "tab.vehicle": "Vehicle",
        "tab.overview": "Overview",

        // TravelRegion
        "region.inland": "Domestic",
        "region.schweiz": "Switzerland",
        "region.ausland": "Abroad",

        // HotelMode
        "hotel.mode.flat": "Flat Rate",
        "hotel.mode.actual": "Actual Amount",

        // VehicleCostCategory
        "vehicle.cat.werkstatt": "Workshop / Repair",
        "vehicle.cat.versicherung": "Insurance",
        "vehicle.cat.tuev": "Inspection",
        "vehicle.cat.steuer": "Vehicle Tax",
        "vehicle.cat.reifen": "Tires",
        "vehicle.cat.leasing":      "Leasing",
        "vehicle.cat.sonstiges": "Miscellaneous",

        // Overview
        "overview.empty.title": "No Data",
        "overview.empty.subtitle": "Record trips, meals, or\naccommodation",
        "overview.total": "Total Reimbursement",
        "overview.trips.unit": "Trips",
        "overview.days.unit": "Days",
        "overview.nights.unit": "Nights",
        "overview.accommodation.short": "Accomm.",

        // Trips
        "trips.gps.tile": "Start\nRecording",
        "trips.new.tile": "New\nTrip",
        "trips.empty.title": "No Trips",
        "trips.empty.subtitle": "Start GPS recording or add a trip manually",
        "trips.all": "All Trips",
        "trips.unit": "Trip(s)",
        "trips.form.new": "New Trip",
        "trips.form.edit": "Edit Trip",
        "trips.from": "From",
        "trips.to": "To",
        "trips.km.label": "Kilometers",
        "trips.result": "Result",
        "trips.distance": "Distance",
        "trips.rate": "Rate",
        "trips.reimbursement": "Reimbursement",
        "trips.start": "Start Location",
        "trips.destination": "Destination",
        "trips.route": "Route",
        "trips.navigation.section": "Navigation",
        "trips.calculation": "Calculation",
        "trips.maps.title": "Maps Integration",
        "trips.maps.subtitle": "Automatic route calculation · Pro only",
        "trips.maps.open": "Open navigation with",
        "trips.apple.maps": "Apple Maps",
        "trips.google.maps": "Google Maps",
        "trips.maps.open.btn": "Open in Maps",
        "trips.auto.label": "Automatic",
        "trips.auto.hint": "Enter start and destination – km will be calculated automatically",
        "trips.auto.calc": "Calculating automatically…",
        "trips.route.computing": "Route calculating automatically…",
        "trips.route.error": "Please check start and destination",
        "trips.live.route": "Live Route",
        "trips.gps.title": "GPS Trip",
        "trips.gps.heading": "Record GPS Trip",
        "trips.gps.desc": "The traveled distance is measured via GPS\nand automatically transferred.",
        "trips.gps.startbtn": "Start Recording",
        "trips.gps.running": "Recording in progress",
        "trips.gps.stop": "End Trip & Transfer",
        "trips.gps.permission": "Requesting location permission…",
        "trips.gps.permission.desc": "Please allow location access in the dialog.",
        "trips.gps.geocoding": "Determining addresses…",
        "trips.gps.geocoding.wait": "One moment please",
        "trips.gps.detected": "GPS Trip Detected",
        "trips.gps.detected.desc": "Distance, start and destination were determined automatically. Please check and correct if necessary.",
        "trips.gps.waiting": "Waiting for GPS…",
        "trips.nav.start": "Start Navigation",

        // Meals
        "meals.add": "Add Meal",
        "meals.add.hint": "Tap to add a day",
        "meals.all": "All Entries",
        "meals.unit": "Day(s)",
        "meals.form.new": "New Meal",
        "meals.form.edit": "Edit Entry",
        "meals.region": "Travel Region",
        "meals.absence": "Absence Time",
        "meals.begin": "Start",
        "meals.end": "End",
        "meals.result": "Result",
        "meals.absence.label": "Absence",
        "meals.level": "Level",
        "meals.allowance": "Meal Allowance",
        "meals.badge.none": "None",
        "meals.level.none": "None (< 1 h)",
        "meals.level.1": "Level 1 (1–3 h)",
        "meals.level.2": "Level 2 (3–6 h)",
        "meals.level.3": "Level 3 (6+ h)",

        // Accommodation
        "hotel.title": "Accommodation",
        "hotel.add": "Add Accommodation",
        "hotel.add.hint": "Tap to add accommodation",
        "hotel.all": "All Accommodations",
        "hotel.unit": "Night(s)",
        "hotel.section": "Accommodation",
        "hotel.form.new": "New Accommodation",
        "hotel.form.edit": "Edit Accommodation",
        "hotel.city": "City / Location",
        "hotel.city.placeholder": "e.g. London",
        "hotel.name": "Hotel",
        "hotel.billing": "Billing Method",
        "hotel.type": "Type",
        "hotel.cost": "Amount (€)",
        "hotel.reimbursement": "Reimbursement",
        "hotel.flat.label": "Accommodation Allowance",
        "hotel.actual.cost": "Actual Costs",
        "hotel.flat.badge": "Flat Rate",
        "hotel.actual.badge": "Actual Amount",
        "hotel.info": "Allowance %@ / night. If actual costs exceed the allowance, the full amount is reimbursed.",
        "hotel.over.flat": "Over Allowance (%@)",

        // Vehicle
        "vehicle.title": "Vehicle Costs",
        "vehicle.add": "Add Vehicle Costs",
        "vehicle.add.hint": "Workshop, insurance, or other vehicle costs",
        "vehicle.unit": "Entry/Entries",
        "vehicle.form.new": "New Costs",
        "vehicle.form.edit": "Edit Costs",
        "vehicle.category.section": "Category",
        "vehicle.details": "Details",
        "vehicle.title.label": "Description",
        "vehicle.mileage": "Mileage (km)",
        "vehicle.summary": "Summary",

        // Settings
        "settings.title": "Settings",
        "settings.km.title": "Kilometer Reimbursement",
        "settings.km.rate": "Km Rate",
        "settings.km.footer": "Tax maximum 2026: 0.38 € / km for cars",
        "settings.meals.title": "Meal Allowances",
        "settings.meals.footer": "All amounts are freely configurable. Allowances under 1 h absence are always 0 €.",
        "settings.hotel.footer": "Germany standard: 20.00 € / night (§ 9 para. 1 no. 5a EStG). Cross-border workers with a Swiss employer working in Germany: please check individually. Custom amounts can be entered freely.",
        "settings.hours.1to3": "1 – 3 Hours",
        "settings.hours.3to6": "3 – 6 Hours",
        "settings.hours.6plus": "6+ Hours",
        "settings.reset": "Reset to Defaults",
        "settings.diagnosis": "Diagnosis",
        "settings.feedback": "Feedback & Support",
        "settings.log": "Error Log",
        "settings.info": "Info & Legal",
        "settings.privacy": "Privacy",
        "settings.help": "App Features & Help",
        "settings.imprint": "Imprint",
        "settings.language": "Language",
        "settings.language.section": "App Language",
        "settings.log.empty": "No entries.",
        "settings.log.clear": "Clear log?",
    ],

    .polish: [
        // Actions
        "action.add": "Dodaj",
        "action.edit": "Edytuj",
        "action.delete": "Usuń",
        "action.cancel": "Anuluj",
        "action.save": "Zapisz",
        "action.done": "Gotowe",
        "action.close": "Zamknij",

        // Common
        "common.optional": "Opcjonalnie",
        "common.note": "Notatka",
        "common.date": "Data",
        "common.amount": "Kwota",
        "common.region": "Region",

        // Tabs
        "tab.trips": "Podróże",
        "tab.meals": "Posiłki",
        "tab.accommodation": "Noclegi",
        "tab.vehicle": "Pojazd",
        "tab.overview": "Przegląd",

        // TravelRegion
        "region.inland": "Kraj",
        "region.schweiz": "Szwajcaria",
        "region.ausland": "Zagranica",

        // HotelMode
        "hotel.mode.flat": "Ryczałt",
        "hotel.mode.actual": "Rzeczywista kwota",

        // VehicleCostCategory
        "vehicle.cat.werkstatt": "Warsztat / Naprawa",
        "vehicle.cat.versicherung": "Ubezpieczenie",
        "vehicle.cat.tuev": "Przegląd",
        "vehicle.cat.steuer": "Podatek od pojazdu",
        "vehicle.cat.reifen": "Opony",
        "vehicle.cat.leasing":      "Leasing",
        "vehicle.cat.sonstiges": "Inne",

        // Overview
        "overview.empty.title": "Brak danych",
        "overview.empty.subtitle": "Zarejestruj podróże, posiłki lub\nnoclegi",
        "overview.total": "Całkowita zwrot",
        "overview.trips.unit": "Podróże",
        "overview.days.unit": "Dni",
        "overview.nights.unit": "Noce",
        "overview.accommodation.short": "Noclegi",

        // Trips
        "trips.gps.tile": "Rozpocznij\nnagrywanie",
        "trips.new.tile": "Nowa\npodróż",
        "trips.empty.title": "Brak podróży",
        "trips.empty.subtitle": "Rozpocznij nagrywanie GPS lub dodaj podróż ręcznie",
        "trips.all": "Wszystkie podróże",
        "trips.unit": "Podróż/e",
        "trips.form.new": "Nowa podróż",
        "trips.form.edit": "Edytuj podróż",
        "trips.from": "Z",
        "trips.to": "Do",
        "trips.km.label": "Kilometry",
        "trips.result": "Wynik",
        "trips.distance": "Odległość",
        "trips.rate": "Stawka",
        "trips.reimbursement": "Zwrot",
        "trips.start": "Lokalizacja początkowa",
        "trips.destination": "Cel podróży",
        "trips.route": "Trasa",
        "trips.navigation.section": "Nawigacja",
        "trips.calculation": "Obliczanie",
        "trips.maps.title": "Integracja map",
        "trips.maps.subtitle": "Automatyczne obliczanie trasy · tylko w wersji Pro",
        "trips.maps.open": "Otwórz nawigację za pomocą",
        "trips.apple.maps": "Apple Maps",
        "trips.google.maps": "Google Maps",
        "trips.maps.open.btn": "Otwórz w Mapach",
        "trips.auto.label": "Automatycznie",
        "trips.auto.hint": "Wprowadź start i cel – km będą obliczane automatycznie",
        "trips.auto.calc": "Obliczanie automatyczne…",
        "trips.route.computing": "Trasa obliczana automatycznie…",
        "trips.route.error": "Proszę sprawdzić punkt startu i cel",
        "trips.live.route": "Trasa na żywo",
        "trips.gps.title": "Podróż GPS",
        "trips.gps.heading": "Nagraj podróż GPS",
        "trips.gps.desc": "Przebyta odległość jest mierzona za pośrednictwem GPS\ni automatycznie przesyłana.",
        "trips.gps.startbtn": "Rozpocznij nagrywanie",
        "trips.gps.running": "Nagrywanie w toku",
        "trips.gps.stop": "Zakończ podróż i prześlij",
        "trips.gps.permission": "Żądanie uprawnień do lokalizacji…",
        "trips.gps.permission.desc": "Proszę zezwolić na dostęp do lokalizacji w oknie dialogowym.",
        "trips.gps.geocoding": "Określanie adresów…",
        "trips.gps.geocoding.wait": "Moment proszę",
        "trips.gps.detected": "Wykryta podróż GPS",
        "trips.gps.detected.desc": "Odległość, punkt początkowy i cel zostały określone automatycznie. Proszę sprawdzić i w razie potrzeby poprawić.",
        "trips.gps.waiting": "Czekaj na GPS…",
        "trips.nav.start": "Uruchom nawigację",

        // Meals
        "meals.add": "Dodaj posiłek",
        "meals.add.hint": "Dotknij, aby dodać dzień",
        "meals.all": "Wszystkie wpisy",
        "meals.unit": "Dzień/dni",
        "meals.form.new": "Nowy posiłek",
        "meals.form.edit": "Edytuj wpis",
        "meals.region": "Region podróży",
        "meals.absence": "Czas nieobecności",
        "meals.begin": "Początek",
        "meals.end": "Koniec",
        "meals.result": "Wynik",
        "meals.absence.label": "Nieobecność",
        "meals.level": "Poziom",
        "meals.allowance": "Zasiłek na posiłki",
        "meals.badge.none": "Brak",
        "meals.level.none": "Brak (< 1 h)",
        "meals.level.1": "Poziom 1 (1–3 h)",
        "meals.level.2": "Poziom 2 (3–6 h)",
        "meals.level.3": "Poziom 3 (6+ h)",

        // Accommodation
        "hotel.title": "Noclegi",
        "hotel.add": "Dodaj nocleg",
        "hotel.add.hint": "Dotknij, aby dodać nocleg",
        "hotel.all": "Wszystkie noclegi",
        "hotel.unit": "Noc/noce",
        "hotel.section": "Nocleg",
        "hotel.form.new": "Nowy nocleg",
        "hotel.form.edit": "Edytuj nocleg",
        "hotel.city": "Miasto / Lokalizacja",
        "hotel.city.placeholder": "np. Warszawa",
        "hotel.name": "Hotel",
        "hotel.billing": "Metoda rozliczenia",
        "hotel.type": "Typ",
        "hotel.cost": "Kwota (€)",
        "hotel.reimbursement": "Zwrot",
        "hotel.flat.label": "Zasiłek noclegowy",
        "hotel.actual.cost": "Koszty rzeczywiste",
        "hotel.flat.badge": "Ryczałt",
        "hotel.actual.badge": "Rzeczywista kwota",
        "hotel.info": "Zasiłek %@ / noc. Jeśli koszty rzeczywiste przekraczają zasiłek, pełna kwota jest zwracana.",
        "hotel.over.flat": "Nad zasiłkiem (%@)",

        // Vehicle
        "vehicle.title": "Koszty pojazdu",
        "vehicle.add": "Dodaj koszty pojazdu",
        "vehicle.add.hint": "Warsztat, ubezpieczenie lub inne koszty pojazdu",
        "vehicle.unit": "Wpis/Wpisy",
        "vehicle.form.new": "Nowe koszty",
        "vehicle.form.edit": "Edytuj koszty",
        "vehicle.category.section": "Kategoria",
        "vehicle.details": "Szczegóły",
        "vehicle.title.label": "Opis",
        "vehicle.mileage": "Przebieg (km)",
        "vehicle.summary": "Podsumowanie",

        // Settings
        "settings.title": "Ustawienia",
        "settings.km.title": "Zwrot za kilometry",
        "settings.km.rate": "Stawka za km",
        "settings.km.footer": "Maksimum podatkowe 2026: 0,38 € / km dla samochodów",
        "settings.meals.title": "Zasiłki na posiłki",
        "settings.meals.footer": "Wszystkie kwoty można swobodnie konfigurować. Zasiłki poniżej 1 h nieobecności zawsze wynoszą 0 €.",
        "settings.hotel.footer": "Standard Niemcy: 20,00 € / noc (§ 9 ust. 1 nr 5a EStG). Pracownicy transgraniczni ze szwajcarskim pracodawcą pracujący w Niemczech: prosimy sprawdzić indywidualnie. Kwoty niestandardowe można wprowadzać swobodnie.",
        "settings.hours.1to3": "1 – 3 godziny",
        "settings.hours.3to6": "3 – 6 godzin",
        "settings.hours.6plus": "6+ godzin",
        "settings.reset": "Przywróć ustawienia domyślne",
        "settings.diagnosis": "Diagnostyka",
        "settings.feedback": "Opinia i wsparcie",
        "settings.log": "Dziennik błędów",
        "settings.info": "Informacje i prawo",
        "settings.privacy": "Prywatność",
        "settings.help": "Funkcje aplikacji i pomoc",
        "settings.imprint": "Zastrzeżenia",
        "settings.language": "Język",
        "settings.language.section": "Język aplikacji",
        "settings.log.empty": "Brak wpisów.",
        "settings.log.clear": "Wyczyścić dziennik?",
    ],

    .czech: [
        // Actions
        "action.add": "Přidat",
        "action.edit": "Upravit",
        "action.delete": "Smazat",
        "action.cancel": "Zrušit",
        "action.save": "Uložit",
        "action.done": "Hotovo",
        "action.close": "Zavřít",

        // Common
        "common.optional": "Volitelné",
        "common.note": "Poznámka",
        "common.date": "Datum",
        "common.amount": "Částka",
        "common.region": "Oblast",

        // Tabs
        "tab.trips": "Jízdy",
        "tab.meals": "Stravné",
        "tab.accommodation": "Ubytování",
        "tab.vehicle": "Vozidlo",
        "tab.overview": "Přehled",

        // TravelRegion
        "region.inland": "Tuzemsko",
        "region.schweiz": "Švýcarsko",
        "region.ausland": "Zahraničí",

        // HotelMode
        "hotel.mode.flat": "Paušál",
        "hotel.mode.actual": "Skutečná částka",

        // VehicleCostCategory
        "vehicle.cat.werkstatt": "Dílna / Oprava",
        "vehicle.cat.versicherung": "Pojištění",
        "vehicle.cat.tuev": "STK",
        "vehicle.cat.steuer": "Silniční daň",
        "vehicle.cat.reifen": "Pneumatiky",
        "vehicle.cat.leasing": "Leasing",
        "vehicle.cat.sonstiges": "Ostatní",

        // Overview
        "overview.empty.title": "Žádná data",
        "overview.empty.subtitle": "Zaznamenejte jízdy, stravné nebo ubytování",
        "overview.total": "Celková náhrada",
        "overview.trips.unit": "Jízdy",
        "overview.days.unit": "Dny",
        "overview.nights.unit": "Noci",
        "overview.accommodation.short": "Ubytov.",

        // Trips
        "trips.gps.tile": "Spustit\nzáznam",
        "trips.new.tile": "Nová\njízda",
        "trips.empty.title": "Žádné jízdy",
        "trips.empty.subtitle": "Spusťte GPS záznam nebo přidejte jízdu ručně",
        "trips.all": "Všechny jízdy",
        "trips.unit": "jízda/jízdy",
        "trips.form.new": "Nová jízda",
        "trips.form.edit": "Upravit jízdu",
        "trips.from": "Odkud",
        "trips.to": "Kam",
        "trips.km.label": "Kilometry",
        "trips.result": "Výsledek",
        "trips.distance": "Vzdálenost",
        "trips.rate": "Sazba",
        "trips.reimbursement": "Náhrada",
        "trips.start": "Místo odjezdu",
        "trips.destination": "Cíl",
        "trips.route": "Trasa",
        "trips.navigation.section": "Navigace",
        "trips.calculation": "Výpočet",
        "trips.maps.title": "Integrace Map",
        "trips.maps.subtitle": "Automatický výpočet trasy · pouze Pro",
        "trips.maps.open": "Otevřít navigaci v",
        "trips.apple.maps": "Apple Maps",
        "trips.google.maps": "Google Maps",
        "trips.maps.open.btn": "Otevřít v Mapách",
        "trips.auto.label": "Automaticky",
        "trips.auto.hint": "Zadejte start a cíl – km se vypočítají automaticky",
        "trips.auto.calc": "Počítám automaticky…",
        "trips.route.computing": "Trasa se počítá automaticky…",
        "trips.route.error": "Zkontrolujte start a cíl",
        "trips.live.route": "Živá trasa",
        "trips.gps.title": "GPS jízda",
        "trips.gps.heading": "Zaznamenat GPS jízdu",
        "trips.gps.desc": "Ujetá vzdálenost je měřena GPS\na automaticky přenesena.",
        "trips.gps.startbtn": "Spustit záznam",
        "trips.gps.running": "Záznam probíhá",
        "trips.gps.stop": "Ukončit jízdu & přenést",
        "trips.gps.permission": "Vyžaduji povolení polohy…",
        "trips.gps.permission.desc": "Povolte přístup k poloze v dialogu.",
        "trips.gps.geocoding": "Zjišťuji adresy…",
        "trips.gps.geocoding.wait": "Moment prosím",
        "trips.gps.detected": "Detekována GPS jízda",
        "trips.gps.detected.desc": "Vzdálenost, start a cíl byly určeny automaticky. Zkontrolujte a případně opravte.",
        "trips.gps.waiting": "Čekám na GPS…",
        "trips.nav.start": "Spustit navigaci",

        // Meals
        "meals.add": "Přidat stravné",
        "meals.add.hint": "Klepněte pro přidání dne",
        "meals.all": "Všechny záznamy",
        "meals.unit": "Den/dny",
        "meals.form.new": "Nové stravné",
        "meals.form.edit": "Upravit záznam",
        "meals.region": "Oblast cestování",
        "meals.absence": "Doba nepřítomnosti",
        "meals.begin": "Začátek",
        "meals.end": "Konec",
        "meals.result": "Výsledek",
        "meals.absence.label": "Nepřítomnost",
        "meals.level": "Stupeň",
        "meals.allowance": "Stravné",
        "meals.badge.none": "Žádné",
        "meals.level.none": "Žádné (< 1 h)",
        "meals.level.1": "Stupeň 1 (1–3 h)",
        "meals.level.2": "Stupeň 2 (3–6 h)",
        "meals.level.3": "Stupeň 3 (6+ h)",

        // Accommodation
        "hotel.title": "Ubytování",
        "hotel.add": "Přidat ubytování",
        "hotel.add.hint": "Klepněte pro přidání ubytování",
        "hotel.all": "Všechna ubytování",
        "hotel.unit": "noc/nocí",
        "hotel.section": "Ubytování",
        "hotel.form.new": "Nové ubytování",
        "hotel.form.edit": "Upravit ubytování",
        "hotel.city": "Město / místo",
        "hotel.city.placeholder": "např. Praha",
        "hotel.name": "Hotel",
        "hotel.billing": "Způsob účtování",
        "hotel.type": "Typ",
        "hotel.cost": "Částka (€)",
        "hotel.reimbursement": "Náhrada",
        "hotel.flat.label": "Paušální náhrada za ubytování",
        "hotel.actual.cost": "Skutečné náklady",
        "hotel.flat.badge": "Paušál",
        "hotel.actual.badge": "Skutečná částka",
        "hotel.info": "Paušál %@ / noc. Pokud skutečné náklady překračují paušál, uhradí se plná částka.",
        "hotel.over.flat": "Nad paušálem (%@)",

        // Vehicle
        "vehicle.title": "Náklady na vozidlo",
        "vehicle.add": "Přidat náklady na vozidlo",
        "vehicle.add.hint": "Dílna, pojištění nebo jiné náklady na vozidlo",
        "vehicle.unit": "Záznam/záznamy",
        "vehicle.form.new": "Nové náklady",
        "vehicle.form.edit": "Upravit náklady",
        "vehicle.category.section": "Kategorie",
        "vehicle.details": "Detaily",
        "vehicle.title.label": "Popis",
        "vehicle.mileage": "Stav km",
        "vehicle.summary": "Souhrn",

        // Settings
        "settings.title": "Nastavení",
        "settings.km.title": "Náhrada za km",
        "settings.km.rate": "Sazba za km",
        "settings.km.footer": "Daňové maximum 2026: 0,38 € / km pro osobní automobily",
        "settings.meals.title": "Stravné",
        "settings.meals.footer": "Všechny částky jsou volně konfigurovatelné. Stravné při nepřítomnosti do 1 h je vždy 0 €.",
        "settings.hotel.footer": "Standard Německo: 20,00 € / noc (§ 9 odst. 1 č. 5a EStG). Přeshraniční pracovníci se švýcarským zaměstnavatelem pracující v Německu: prosím ověřte individuálně. Vlastní částky lze zadat volně.",
        "settings.hours.1to3": "1 – 3 hodiny",
        "settings.hours.3to6": "3 – 6 hodin",
        "settings.hours.6plus": "6+ hodin",
        "settings.reset": "Obnovit výchozí nastavení",
        "settings.diagnosis": "Diagnostika",
        "settings.feedback": "Zpětná vazba & Podpora",
        "settings.log": "Protokol chyb",
        "settings.info": "Info & Právní",
        "settings.privacy": "Ochrana osobních údajů",
        "settings.help": "Funkce aplikace & Nápověda",
        "settings.imprint": "Impresum",
        "settings.language": "Jazyk",
        "settings.language.section": "Jazyk aplikace",
        "settings.log.empty": "Žádné záznamy.",
        "settings.log.clear": "Smazat protokol?",
    ],

]
