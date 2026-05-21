import Foundation
import CoreLocation

// MARK: - LocationHelper
// Einmalige Standortabfrage → Adresse als String (Straße, Stadt)
struct LocationHelper: NSObject {

    private static var oneShotManager: OneShotLocationManager?

    /// Aktuellen Standort abrufen und als lesbare Adresse zurückgeben
    static func currentAddress(completion: @escaping (String?) -> Void) {
        let manager = OneShotLocationManager(completion: completion)
        oneShotManager = manager   // stark referenzieren bis Ergebnis da
        manager.start()
    }
}

// MARK: - Einmalige CLLocationManager-Nutzung
private class OneShotLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager    = CLLocationManager()
    private let completion : (String?) -> Void
    private var didFire    = false

    init(completion: @escaping (String?) -> Void) {
        self.completion = completion
        super.init()
        manager.delegate         = self
        manager.desiredAccuracy  = kCLLocationAccuracyHundredMeters
    }

    func start() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            completion(nil)
        }
    }

    // MARK: - Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !didFire, let loc = locations.first else { return }
        didFire = true
        manager.stopUpdatingLocation()
        reverseGeocode(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !didFire else { return }
        didFire = true
        completion(nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            completion(nil)
        default:
            break
        }
    }

    // MARK: - Reverse Geocoding
    private func reverseGeocode(_ location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self = self, let place = placemarks?.first else {
                self?.completion(nil); return
            }
            // Format: "Straße Hausnummer, Stadt" oder nur "Stadt"
            var parts: [String] = []
            if let street = place.thoroughfare {
                var streetFull = street
                if let number = place.subThoroughfare { streetFull += " " + number }
                parts.append(streetFull)
            }
            if let city = place.locality { parts.append(city) }
            else if let area = place.administrativeArea { parts.append(area) }

            self.completion(parts.isEmpty ? nil : parts.joined(separator: ", "))
        }
    }
}
