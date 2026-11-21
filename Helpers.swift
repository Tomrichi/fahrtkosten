import Foundation
import SwiftUI
import UIKit
import CoreLocation

// MARK: - Formatters
extension Double {
    var euroFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.decimalSeparator = ","
        f.groupingSeparator = "."
        return (f.string(from: NSNumber(value: self)) ?? "0,00") + " €"
    }

    var chfFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.decimalSeparator = ","
        f.groupingSeparator = "."
        return (f.string(from: NSNumber(value: self)) ?? "0,00") + " CHF"
    }

    var kmFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.decimalSeparator = ","
        return (f.string(from: NSNumber(value: self)) ?? "0,0") + " km"
    }
}

extension Date {
    var shortDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }

    var shortDateShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd. MMM"
        return f.string(from: self)
    }

    var weekdayShortDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEE, dd. MMM"
        return f.string(from: self)
    }

    var timeOnly: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: self)
    }
}

// MARK: - Color helpers
extension Color {
    static let iosGreen  = Color(red: 52/255,  green: 199/255, blue: 89/255)
    static let iosOrange = Color(red: 255/255, green: 149/255, blue: 0/255)
    static let iosRed    = Color(red: 255/255, green: 59/255,  blue: 48/255)
    static let iosPurple = Color(red: 175/255, green: 82/255,  blue: 222/255)
    static let iosIndigo = Color(red: 88/255,  green: 86/255,  blue: 214/255)
    static let iosTeal   = Color(red: 90/255,  green: 200/255, blue: 250/255)
}

// MARK: - Accessibility: Reduce Motion
@discardableResult
func withOptionalAnimation<R>(_ animation: Animation? = .default, _ body: () throws -> R) rethrows -> R {
    if UIAccessibility.isReduceMotionEnabled {
        return try body()
    } else {
        return try withAnimation(animation, body)
    }
}

// MARK: - Kilometer-Eingabe (max. 1 Nachkommastelle, Komma)
extension Double {
    /// z. B. 45.5 → "45,5", 46.0 → "46"
    var kmInputString: String {
        let r = (self * 10).rounded() / 10
        if r == r.rounded() { return String(Int(r)) }
        return String(format: "%.1f", r).replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Currency input helper
func parseCurrency(_ s: String) -> Double {
    let clean = s.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }
    return Double(clean) ?? 0
}

// MARK: - Kilometerpauschale
/// Erstattung nach § 9 EStG: NUR geschäftliche Fahrten sind erstattungsfähig, private
/// Fahrten zählen nicht mit. Zentrale Stelle, damit Übersicht, Statistik, PDF- und
/// CSV-Export nicht unabhängig voneinander (und potenziell abweichend) rechnen.
func tripReimbursement(_ trips: [Trip], rate: Double) -> Double {
    trips.filter { $0.art == .geschaeftlich && !$0.isStorno }.reduce(0) { $0 + $1.km * rate }
}

// MARK: - Tagessprung (Verpflegung)
/// Endzeit liegt per DatePicker (nur Stunde/Minute) immer auf demselben Kalendertag wie der
/// Formular-Tag – reicht die Arbeit über Mitternacht (z. B. 06:00–01:00), muss ein Tag
/// addiert werden, sonst liegt das Ende rechnerisch vor dem Beginn und die Stundenzahl wird
/// auf 0 statt auf die tatsächliche (lange) Dauer berechnet.
func rolledOverIfNeeded(_ end: Date, after start: Date) -> Date {
    end < start ? (Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end) : end
}

// MARK: - GPS-Route (Fahrtenbuchmodus)
/// Kodiert die während einer GPS-Fahrt aufgezeichneten Koordinaten kompakt als
/// "lat,lon;lat,lon;...", damit die tatsächlich gefahrene Route nachweisbar bleibt (GoBD:
/// Reiseroute muss bei Umwegen nachvollziehbar sein). Dünnt lange Routen auf `maxPoints`
/// aus, damit die gespeicherte Fahrt nicht unnötig aufgebläht wird.
extension Data {
    /// Wandelt einen Hex-String (z.B. einen SHA256-Hash) zurück in Bytes – gebraucht, um den
    /// im Änderungsprotokoll gespeicherten Hex-Hash für den RFC-3161-Zeitstempel erneut als
    /// rohe 32 Byte zu übergeben.
    init?(hexString: String) {
        var data = Data(capacity: hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            guard let nextIndex = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex),
                  let byte = UInt8(hexString[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}

func encodeRoute(_ coords: [CLLocationCoordinate2D], maxPoints: Int = 200) -> String? {
    guard coords.count > 1 else { return nil }
    let step = max(1, coords.count / maxPoints)
    let sampled = stride(from: 0, to: coords.count, by: step).map { coords[$0] }
    return sampled.map { String(format: "%.5f,%.5f", $0.latitude, $0.longitude) }
                  .joined(separator: ";")
}

// MARK: - Standard-Kraftstoffdaten
/// Wendet die in den Einstellungen hinterlegten Standard-Werte für Kraftstoffpreis und
/// -verbrauch auf eine automatisch angelegte Fahrt an (GPS-Autostopp am iPhone, Fahrten
/// über die Apple Watch). Zentrale Stelle, damit diese Pfade nicht wie bisher unabhängig
/// voneinander (und teils gar nicht) die Standardwerte anwenden – im Unterschied zur
/// manuellen Eingabe/GPS-Ergebnis/Maps-Import über TripFormView, die das bereits korrekt tut.
/// Für Hybrid-Fahrzeuge wird nichts gesetzt (eigene Zwei-Preis-Kodierung, dort muss der
/// Nutzer die Werte im Formular nachtragen).
func applyDefaultFuelData(to trip: inout Trip) {
    let ud = UserDefaults.standard
    let fuelTypeKey = ud.string(forKey: "defaultFuelType") ?? "e10"
    guard fuelTypeKey != "hybrid" else { return }

    let fuelType: FuelType = {
        switch fuelTypeKey {
        case "e5":      return .e5
        case "diesel":  return .diesel
        case "elektro": return .elektro
        default:        return .e10
        }
    }()
    let priceStr = ud.string(forKey: "defaultFuelPrice.\(fuelTypeKey)") ?? ""
    let consStr  = ud.string(forKey: "defaultConsumption.\(fuelTypeKey)") ?? ""
    let price = Double(priceStr.replacingOccurrences(of: ",", with: "."))
    let cons  = Double(consStr.replacingOccurrences(of: ",", with: "."))
    if let price { trip.fuelPricePerLiter = price }
    if let cons  { trip.fuelConsumption   = cons }
    trip.fuelTypeRaw = fuelType.storageKey
}
