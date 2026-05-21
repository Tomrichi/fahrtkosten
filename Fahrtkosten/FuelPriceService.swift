import Foundation
import CoreLocation
import Combine

// MARK: - Kraftstoffpreis
struct FuelPrice {
    let pricePerLiter: Double
    let fuelType: String
    let stationName: String?
    let isFallback: Bool
}

enum FuelType: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case e5      = "Super E5"
    case e10     = "Super E10"
    case diesel  = "Diesel"
    case elektro = "Elektro"
    case hybrid  = "Hybrid"

    var tankerkoenigKey: String {
        switch self {
        case .e5:      return "e5"
        case .e10:     return "e10"
        case .diesel:  return "diesel"
        case .elektro: return ""   // kein Tankerkönig-Abruf
        case .hybrid:  return "e10" // Hybrid nutzt Benzin-Preis
        }
    }

    /// true wenn kein Tankerkönig-Abruf sinnvoll ist
    var isElectric: Bool { self == .elektro }

    var icon: String {
        switch self {
        case .elektro: return "bolt.fill"
        case .hybrid:  return "bolt.car.fill"
        default:       return "fuelpump.fill"
        }
    }

    /// Einheit für Verbrauch/Preis-Anzeige
    var consumptionUnit: String {
        switch self {
        case .elektro: return "kWh/100 km"
        case .hybrid:  return "L/100 km"
        default:       return "L/100 km"
        }
    }

    var priceUnit: String {
        switch self {
        case .elektro: return "€/kWh"
        default:       return "€/L"
        }
    }

    var priceLabel: String {
        switch self {
        case .elektro: return "Strompreis (€/kWh)"
        default:       return "Spritpreis (€/L)"
        }
    }

    var consumptionLabel: String {
        switch self {
        case .elektro: return "Verbrauch (kWh/100 km)"
        case .hybrid:  return "Verbrauch (L/100 km)"
        default:       return "Verbrauch (L/100 km)"
        }
    }

    var consumptionPlaceholder: String {
        switch self {
        case .elektro: return "z.B. 18,0"
        default:       return "z.B. 7,5"
        }
    }

    var pricePlaceholder: String {
        switch self {
        case .elektro: return "z.B. 0,30"
        default:       return "z.B. 1,75"
        }
    }
}

// MARK: - FuelPriceService
// HINWEIS: Eigenen API-Key unter https://creativecommons.tankerkoenig.de registrieren
// und unten bei apiKey eintragen. Der Demo-Key funktioniert nur für Entwicklungstests.
@MainActor
class FuelPriceService: ObservableObject {
    @Published var currentPrice: FuelPrice?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // ⚠️ Eigenen API-Key hier eintragen:
    // https://creativecommons.tankerkoenig.de → Registrierung → API-Key kopieren
    private let apiKey = "3ab458e7-a46f-48bd-8bfa-cf79ad67b083"

    func fetchPrice(fuelType: FuelType = .e10, near location: CLLocation? = nil) async {
        isLoading = true
        errorMessage = nil

        // Elektrofahrzeuge: kein API-Abruf – Standardwert aus Einstellungen/Fallback verwenden
        if fuelType.isElectric {
            currentPrice = fallback(fuelType: fuelType)
            isLoading = false
            return
        }

        guard let loc = location else {
            AppLogger.shared.logFuel("Kein Standort – Fallback-Preis wird verwendet (\(fuelType.rawValue))")
            currentPrice = fallback(fuelType: fuelType)
            isLoading = false
            return
        }

        AppLogger.shared.logFuel("Spritpreisabfrage gestartet (\(fuelType.rawValue))")
        if let price = await fetchTankerkoenig(fuelType: fuelType, location: loc) {
            currentPrice = price
            AppLogger.shared.logFuel("Preis erhalten: \(String(format: "%.3f", price.pricePerLiter)) €/L (\(price.stationName ?? "unbekannt"))")
        } else {
            // API fehlgeschlagen → Fallback
            AppLogger.shared.logWarn("Tankerkönig-Abfrage fehlgeschlagen – Fallback-Preis (\(fuelType.rawValue))")
            currentPrice = fallback(fuelType: fuelType)
        }
        isLoading = false
    }

    private func fetchTankerkoenig(fuelType: FuelType, location: CLLocation) async -> FuelPrice? {
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude

        // API-Key als eigene Variable → kein Integer-Parsing-Fehler
        let key = apiKey
        let urlStr = "https://creativecommons.tankerkoenig.de/json/list.php?lat=\(lat)&lng=\(lng)&rad=50&sort=price&type=\(fuelType.tankerkoenigKey)&apikey=\(key)"

        guard let url = URL(string: urlStr) else {
            errorMessage = "Ungültige URL"
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Ungültige Server-Antwort"
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                errorMessage = "Server-Fehler: HTTP \(httpResponse.statusCode)"
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                errorMessage = "Ungültiges JSON"
                return nil
            }

            // API-Fehlermeldung auswerten
            if let ok = json["ok"] as? Bool, !ok {
                let msg = json["message"] as? String ?? "Unbekannter API-Fehler"
                errorMessage = "Tankerkönig: \(msg)"
                return nil
            }

            guard let stations = json["stations"] as? [[String: Any]], !stations.isEmpty else {
                errorMessage = "Keine Tankstellen in der Nähe gefunden"
                return nil
            }



            // Offene zuerst, dann geschlossene
            for pass in 0..<2 {
                for station in stations {
                    let isOpen = station["isOpen"] as? Bool ?? false
                    if pass == 0 && !isOpen { continue }
                    let price: Double? = {
                        if fuelType == .elektro { return nil }
                        // Tankerkönig liefert bei type-gefilterter Abfrage "price" als Feld
                        if let d = station["price"] as? Double { return d }
                        if let n = station["price"] as? NSNumber { return n.doubleValue }
                        if let s = station["price"] as? String { return Double(s) }
                        return nil
                    }()
                    if let p = price, p > 0 {
                        return FuelPrice(pricePerLiter: p, fuelType: fuelType.rawValue,
                                         stationName: station["name"] as? String, isFallback: false)
                    }
                }
            }
            errorMessage = "Kein gültiger Preis gefunden"
            return nil

        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                errorMessage = "Keine Internetverbindung"
            case .timedOut:
                errorMessage = "Zeitüberschreitung – bitte erneut versuchen"
            default:
                errorMessage = "Netzwerkfehler: \(urlError.localizedDescription)"
            }
            return nil
        } catch {
            errorMessage = "Fehler: \(error.localizedDescription)"
            return nil
        }
    }

    private func fallback(fuelType: FuelType) -> FuelPrice {
        let price: Double
        switch fuelType {
        case .e5:      price = 1.769
        case .e10:     price = 1.749
        case .diesel:  price = 1.689
        case .elektro: price = 0.30   // Ø Haushaltsstrompreis DE 2025 – in Einstellungen anpassbar
        case .hybrid:  price = 1.749
        }
        return FuelPrice(pricePerLiter: price, fuelType: fuelType.rawValue,
                         stationName: nil, isFallback: true)
    }
}
