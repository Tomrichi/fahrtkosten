import SwiftUI
import Combine
import MapKit
import CoreLocation

// MARK: - Maps Route Section
struct MapsRouteSection: View {
    @EnvironmentObject var lm: LocalizationManager

    let from: String
    let to: String
    @ObservedObject var mapsService: MapsService
    let onOpenMaps: () -> Void

    var canCalculate: Bool { !from.isEmpty && !to.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            if let route = mapsService.mkRoute {
                MapRouteView(route: route, origin: from, destination: to)
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.vertical, 8)
            }

            if let result = mapsService.routeResult {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.iosGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(from) → \(to)").font(.subheadline).lineLimit(1)
                        Text("🛣 \(result.distanceText)  ·  🕐 \(result.durationText)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Label(lm.t("trips.auto.label"), systemImage: "wand.and.stars")
                        .font(.caption).foregroundColor(.blue)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1)).clipShape(Capsule())
                }
                .padding(.vertical, 4)
                Button {
                    onOpenMaps()
                } label: {
                    Label(lm.t("trips.maps.open.btn"), systemImage: "arrow.up.right.square").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(.blue).padding(.vertical, 4)

            } else if mapsService.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(lm.t("trips.route.computing")).foregroundColor(.secondary).font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8)

            } else if let err = mapsService.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(err).font(.subheadline).foregroundColor(.secondary)
                        Text(lm.t("trips.route.error")).font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)

            } else if canCalculate {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary)
                    Text(lm.t("trips.auto.calc")).font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8)

            } else {
                HStack(spacing: 6) {
                    Image(systemName: "map").foregroundColor(.secondary)
                    Text(lm.t("trips.auto.hint"))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8)
            }
        }
    }
}

// MARK: - MapKit Route View
struct MapRouteView: UIViewRepresentable {
    let route: MKRoute
    let origin: String
    let destination: String

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isZoomEnabled    = true
        mapView.isScrollEnabled  = true
        mapView.showsUserLocation = false
        mapView.addOverlay(route.polyline, level: .aboveRoads)
        let pts = route.polyline.points()
        for coord in [pts[0].coordinate, pts[route.polyline.pointCount - 1].coordinate] {
            let pin = MKPointAnnotation(); pin.coordinate = coord
            mapView.addAnnotation(pin)
        }
        let rect   = route.polyline.boundingMapRect
        let padded = rect.insetBy(dx: -rect.size.width * 0.2, dy: -rect.size.height * 0.2)
        mapView.setVisibleMapRect(padded, animated: false)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: poly)
                r.strokeColor = UIColor.systemBlue; r.lineWidth = 5; return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let pin = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            pin.glyphImage = UIImage(systemName: "circle.fill"); return pin
        }
    }
}

// MARK: - Live-Karte während GPS-Aufzeichnung

struct TrackingMapView: UIViewRepresentable {
    let routeCoordinates: [CLLocationCoordinate2D]
    let currentLocation: CLLocation?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate          = context.coordinator
        map.showsUserLocation = true
        map.isZoomEnabled     = true
        map.isScrollEnabled   = true
        map.mapType           = .standard
        // Fahrtrichtung: Karte dreht sich mit dem Kurs des Geräts
        map.setUserTrackingMode(.followWithHeading, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Nur die Polyline aktualisieren – KEIN setRegion(),
        // da setRegion() den Tracking-Modus auf .none zurücksetzt
        map.removeOverlays(map.overlays)
        guard routeCoordinates.count >= 2 else { return }
        let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
        map.addOverlay(polyline, level: .aboveRoads)

        // Tracking-Modus wiederherstellen falls Nutzer manuell gescrollt hat
        if map.userTrackingMode != .followWithHeading {
            map.setUserTrackingMode(.followWithHeading, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: poly)
            r.strokeColor = UIColor.systemBlue
            r.lineWidth   = 5
            r.lineCap     = .round
            r.lineJoin    = .round
            return r
        }
    }
}

// MARK: - Live-Karten-Kachel
struct LiveMapCard: View {
    @EnvironmentObject var lm: LocalizationManager
    @ObservedObject var tracker: LocationTracker

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 13, weight: .regular))
                Text(lm.t("trips.live.route"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if tracker.routeCoordinates.count < 2 {
                    Text(lm.t("trips.gps.waiting"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            TrackingMapView(
                routeCoordinates: tracker.routeCoordinates,
                currentLocation: tracker.currentLocation
            )
            .frame(height: 400)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 20)
    }
}


// MARK: - Favorit bearbeiten
struct FavoriteEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    let favorite: FavoriteTrip

    @State private var from: String
    @State private var to: String
    @State private var kmString: String

    init(favorite: FavoriteTrip) {
        self.favorite = favorite
        _from     = State(initialValue: favorite.from)
        _to       = State(initialValue: favorite.to)
        _kmString = State(initialValue: favorite.km.kmInputString)
    }

    private var kmValue: Double { (parseCurrency(kmString) * 10).rounded() / 10 }
    private var isValid: Bool {
        !from.trimmingCharacters(in: .whitespaces).isEmpty
            && !to.trimmingCharacters(in: .whitespaces).isEmpty
            && kmValue > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("Von", systemImage: "location.fill").foregroundColor(.green)
                        TextField("Start", text: $from).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Nach", systemImage: "flag.fill").foregroundColor(.blue)
                        TextField("Ziel", text: $to).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Kilometer", systemImage: "road.lanes")
                        Spacer()
                        TextField("0,0", text: $kmString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            .navigationTitle("Favorit bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var updated = favorite
                        updated.from = from.trimmingCharacters(in: .whitespaces)
                        updated.to   = to.trimmingCharacters(in: .whitespaces)
                        updated.km   = kmValue
                        store.updateFavorite(updated)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
