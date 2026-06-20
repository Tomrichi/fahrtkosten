import Foundation
import MapKit
import CoreLocation
import Combine

// MARK: - Distance Matrix result
struct RouteResult {
    let km: Double
    let distanceText: String
    let durationText: String
    let durationSeconds: TimeInterval   // neu: Fahrtdauer in Sekunden für Auto-Verpflegung
}

// MARK: - Maps Service using Apple MapKit (no API key for routing display)
//         For distance calculation we use MKDirections (free, no key needed)
//         For opening Google Maps we build a universal link

class MapsService: ObservableObject {
    @Published var routeResult: RouteResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var mkRoute: MKRoute?

    // Geocode + calculate route using Apple MapKit (free, no API key)
    func calculateRoute(from originStr: String, to destinationStr: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            routeResult = nil
            mkRoute = nil
        }

        do {
            let originItem      = try await geocodeToMapItem(originStr)
            let destinationItem = try await geocodeToMapItem(destinationStr)

            let request = MKDirections.Request()
            request.source      = originItem
            request.destination = destinationItem
            request.transportType = .automobile

            let directions = MKDirections(request: request)
            let response   = try await directions.calculate()

            guard let route = response.routes.first else {
                throw NSError(domain: "MapsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Keine Route gefunden"])
            }

            let km              = route.distance / 1000.0
            let durationSecs    = route.expectedTravelTime
            let duration        = formatDuration(durationSecs)
            let distText        = km.kmFormatted

            await MainActor.run {
                self.mkRoute     = route
                self.routeResult = RouteResult(
                    km: km,
                    distanceText: distText,
                    durationText: duration,
                    durationSeconds: durationSecs
                )
                self.isLoading   = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Route nicht gefunden. Orte prüfen."
                self.isLoading    = false
            }
        }
    }

    private func geocodeToMapItem(_ address: String) async throws -> MKMapItem {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = address
        let results = try await MKLocalSearch(request: req).start()
        guard let item = results.mapItems.first else {
            throw NSError(domain: "Geocode", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Ort nicht gefunden: \(address)"])
        }
        return item
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h) Std. \(m) Min." }
        return "\(m) Min."
    }

    // MARK: - Maps öffnen mit Auswahl
    enum MapChoice { case apple, google }

    static func openInAppleMaps(from origin: String, to destination: String) {
        let urlStr = "maps://?saddr=\(origin.urlEncoded)&daddr=\(destination.urlEncoded)&dirflg=d"
        if let url = URL(string: urlStr) {
            UIApplication.shared.open(url)
        }
    }

    static func openInGoogleMaps(from origin: String, to destination: String) {
        let appUrlStr = "comgooglemaps://?saddr=\(origin.urlEncoded)&daddr=\(destination.urlEncoded)&directionsmode=driving"
        if let appUrl = URL(string: appUrlStr), UIApplication.shared.canOpenURL(appUrl) {
            UIApplication.shared.open(appUrl)
            return
        }
        let webUrlStr = "https://maps.google.com/?saddr=\(origin.urlEncoded)&daddr=\(destination.urlEncoded)&dirflg=d"
        if let webUrl = URL(string: webUrlStr) {
            UIApplication.shared.open(webUrl)
        }
    }

    static func openInMaps(from origin: String, to destination: String) {
        openInAppleMaps(from: origin, to: destination)
    }
}

extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
