import SwiftUI
import MapKit

// MARK: - Live-Karte während GPS-Aufzeichnung

/// Zeigt die bisher gefahrene Route als Polyline auf einer MKMapView.
/// Die Karte folgt automatisch dem aktuellen Standort.
struct TrackingMapView: UIViewRepresentable {

    let routeCoordinates: [CLLocationCoordinate2D]
    let currentLocation: CLLocation?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate         = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode  = .follow
        map.isZoomEnabled     = true
        map.isScrollEnabled   = true
        map.mapType           = .standard
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Alte Overlays entfernen und neue Route zeichnen
        map.removeOverlays(map.overlays)

        guard routeCoordinates.count >= 2 else { return }

        let polyline = MKPolyline(coordinates: routeCoordinates,
                                  count: routeCoordinates.count)
        map.addOverlay(polyline, level: .aboveRoads)

        // Kartenausschnitt auf Route anpassen (folgt dem aktuellen Standort)
        if let loc = currentLocation {
            let region = MKCoordinateRegion(
                center: loc.coordinate,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            )
            map.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: Coordinator
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer        = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth   = 5
            renderer.lineCap     = .round
            renderer.lineJoin    = .round
            return renderer
        }
    }
}

// MARK: - Karten-Karte (SwiftUI-Wrapper für das GPS-Sheet)

/// Kompakte Karten-Kachel, die im GPSTripSheet eingebettet wird.
struct LiveMapCard: View {
    @ObservedObject var tracker: LocationTracker

    var body: some View {
        VStack(spacing: 0) {
            // Karten-Header
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 13, weight: .semibold))
                Text("Live-Route")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if tracker.routeCoordinates.count < 2 {
                    Text("Warte auf GPS…")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            // Karte
            TrackingMapView(
                routeCoordinates: tracker.routeCoordinates,
                currentLocation: tracker.currentLocation
            )
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 0))
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 20)
    }
}
