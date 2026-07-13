import SwiftUI
import Combine
import MapKit
import CoreLocation


// MARK: - LocationHelper (eingebettet)
enum LocationHelper {
    private static var oneShotManager: OneShotLocationManager?
    static func currentAddress(completion: @escaping (String?) -> Void) {
        let manager = OneShotLocationManager(completion: completion)
        oneShotManager = manager
        manager.start()
    }
}


// MARK: - Geocoding: Stadt aus CLLocation
private func cityFromLocation(_ location: CLLocation, completion: @escaping (String?) -> Void) {
    if #available(iOS 26.0, *) {
        Task {
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    completion(nil); return
                }
                let mapItems = try await request.mapItems
                if let item = mapItems.first {
                    // fullAddress ist die korrekte MKAddress-Property in iOS 26
                    // Nur den Stadtnamen extrahieren (erster Teil vor dem Komma)
                    let full = item.address?.fullAddress ?? ""
                    let city = full.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces)
                    completion(city?.isEmpty == false ? city : full.isEmpty ? nil : full)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }
    } else {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            let place = placemarks?.first
            let city = place?.locality
                ?? place?.subLocality
                ?? place?.administrativeArea
                ?? place?.country
            completion(city)
        }
    }
}

private class OneShotLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager    = CLLocationManager()
    private let completion : (String?) -> Void
    private var didFire    = false

    init(completion: @escaping (String?) -> Void) {
        self.completion = completion
        super.init()
        manager.delegate        = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: completion(nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !didFire, let loc = locations.first else { return }
        didFire = true
        manager.stopUpdatingLocation()
        cityFromLocation(loc) { [weak self] city in
            self?.completion(city)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !didFire else { return }
        didFire = true; completion(nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted: completion(nil)
        default: break
        }
    }
}

// MARK: - Einmaliger Standort-Provider für Spritpreis
private class CurrentLocationProvider: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published var location: CLLocation?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestOnce() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

// MARK: - Hilfs-Struct für GPS-Ergebnis (Identifiable für .sheet(item:))
struct GPSResult: Identifiable {
    let id              = UUID()
    let from            : String
    let to              : String
    let km              : Double
    let durationSeconds : Int
}

// MARK: - Fahrten List View
struct FahrtenView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager
    @EnvironmentObject var settingsCtrl: SettingsController

    @State private var showAdd           = false
    @State private var editTrip: Trip?
    @State private var showGPSSheet      = false
    @State private var importMode: TripFormMode? = nil
    

    // ── Zeitraum-Filter ──
    enum TripFilter: String, CaseIterable {
        case tag    = "Tag"
        case woche  = "Woche"
        case monat  = "Monat"
        case alle   = "Alle"
    }
    @AppStorage("fahrten.selectedFilter") private var selectedFilter: TripFilter = .alle
    @State private var selectedDate: Date = Date()

    private var filteredTrips: [Trip] {
        let cal = Calendar.current
        let ref = selectedDate
        switch selectedFilter {
        case .alle:
            return store.trips.sorted(by: { $0.date > $1.date })
        case .tag:
            return store.trips
                .filter { cal.isDate($0.date, inSameDayAs: ref) }
                .sorted(by: { $0.date > $1.date })
        case .woche:
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: ref)?.start else {
                return store.trips.sorted(by: { $0.date > $1.date })
            }
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
            return store.trips
                .filter { $0.date >= weekStart && $0.date < weekEnd }
                .sorted(by: { $0.date > $1.date })
        case .monat:
            return store.trips
                .filter { cal.isDate($0.date, equalTo: ref, toGranularity: .month) }
                .sorted(by: { $0.date > $1.date })
        }
    }

    private var filterLabel: String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        switch selectedFilter {
        case .alle:   return "Alle Fahrten"
        case .tag:
            if cal.isDateInToday(selectedDate) { return "Heute" }
            fmt.dateStyle = .medium; fmt.timeStyle = .none
            return fmt.string(from: selectedDate)
        case .woche:
            guard let interval = cal.dateInterval(of: .weekOfYear, for: selectedDate) else { return "Diese Woche" }
            let start = interval.start
            let end   = cal.date(byAdding: .day, value: 6, to: start)!
            fmt.dateFormat = "d. MMM"
            return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
        case .monat:
            fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: selectedDate)
        }
    }

    // Geteilter Singleton statt eigener Instanz: die Aufzeichnung läuft prozessweit
    // weiter (z. B. über CarPlay gestartet), auch wenn diese View neu erzeugt wird.
    @ObservedObject private var locationTracker = LocationTracker.shared

    private func handleCarPlayStopGPS() {
        let ud = UserDefaults(suiteName: "group.de.tommwagner.fahrtkosten")
        let autoStopped = ud?.bool(forKey: "carPlayAutoStopped") ?? false
        ud?.removeObject(forKey: "carPlayAutoStopped")
        if autoStopped {
            // CarPlay getrennt → Sheet öffnen, User prüft Daten selbst
            showGPSSheet = true
        }
        // Manueller Stop per CarPlay-Button: CarPlaySceneDelegate stoppt und speichert
        // die Fahrt bereits direkt über LocationTracker.shared/CarPlayDataAccess –
        // das funktioniert auch, wenn diese View nie existiert hat. Hier ist nichts mehr zu tun
        // (sonst würde die Fahrt doppelt gespeichert).
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Schnellzugriff-Kacheln ──
                Section {
                    HStack(spacing: 12) {
                        // Kachel 1: GPS-Aufzeichnung
                        Button {
                            AppLogger.shared.logTap("GPS-Aufzeichnung starten")
                            showGPSSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "location.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.iosGreen)
                                    .accessibilityHidden(true)
                                Text(lm.t("trips.gps.tile").replacingOccurrences(of: "\n", with: " "))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.iosGreen.opacity(0.35), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("GPS-Aufzeichnung starten")
                        .accessibilityHint("Startet die automatische Kilometererfassung per GPS")

                        // Kachel 2: Neue Fahrt (immer sichtbar und nutzbar)
                        Button {
                            AppLogger.shared.logTap("Neue Fahrt (Kachel)")
                            showAdd = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
                                Text(lm.t("trips.new.tile").replacingOccurrences(of: "\n", with: " "))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.blue.opacity(0.35), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Neue Fahrt manuell eingeben")
                        .accessibilityHint("Öffnet das Formular zur manuellen Eingabe einer Fahrt")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }

                if store.trips.isEmpty {
                    EmptyStateRow(icon: "car.fill", color: .blue,
                                  title: lm.t("trips.empty.title"),
                                  subtitle: lm.t("trips.empty.subtitle"))
                } else {
                    // ── Zeitraum-Filter ──
                    Section {
                        VStack(spacing: 10) {
                            // Filter Chips
                            FilterChipBar(selection: $selectedFilter)
                                .padding(.vertical, 2)

                            // Datumswähler – nur sichtbar wenn nicht "Alle"
                            if selectedFilter != .alle {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 15, weight: .regular))

                                    DatePicker(
                                        "",
                                        selection: $selectedDate,
                                        displayedComponents: .date
                                    )
                                    .labelsHidden()
                                    .datePickerStyle(.compact)

                                    Spacer()

                                    // Heute-Button
                                    Button {
                                        withOptionalAnimation(.easeInOut(duration: 0.2)) {
                                            selectedDate = Date()
                                        }
                                    } label: {
                                        Text("Heute")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }

                    // ── Header-Karte ──
                    Section {
                        ListHeaderCard(
                            icon: "car.fill",
                            color: .blue,
                            title: filterLabel,
                            countLabel: "\(filteredTrips.count) \(lm.t("trips.unit"))  ·  \(filteredTrips.reduce(0) { $0 + $1.km }.kmFormatted)",
                            total: filteredTrips.reduce(0) { $0 + $1.km } * store.kmRate
                        )
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }

                    // ── Fahrten-Liste (gefiltert) ──
                    if filteredTrips.isEmpty {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("Keine Fahrten im gewählten Zeitraum")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 20)
                                Spacer()
                            }
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                        }
                    } else {
                        Section(filterLabel) {
                            ForEach(filteredTrips) { trip in
                                TripRow(trip: trip, kmRate: store.kmRate)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        AppLogger.shared.logTap("Fahrt bearbeiten: \(trip.from) → \(trip.to)")
                                        editTrip = trip
                                    }
                                    .dynamicSwipeActions(
                                        onDelete: {
                                            AppLogger.shared.logTap("Fahrt gelöscht: \(trip.from) → \(trip.to)")
                                            store.deleteTrip(trip.id)
                                        },
                                        onEdit: { editTrip = trip },
                                        onDuplicate: {
                                            AppLogger.shared.logTap("Fahrt dupliziert: \(trip.from) → \(trip.to)")
                                            store.duplicateTrip(trip)
                                        }
                                    )
                                    .contextMenu {
                                        Button { editTrip = trip } label: {
                                            Label(lm.t("action.edit"), systemImage: "pencil")
                                        }
                                        Button {
                                            store.duplicateTrip(trip)
                                        } label: {
                                            Label("Eintrag duplizieren", systemImage: "doc.on.doc")
                                        }
                                        let isFav = store.favorites.contains { $0.from == trip.from && $0.to == trip.to }
                                        Button {
                                            if isFav {
                                                if let fav = store.favorites.first(where: { $0.from == trip.from && $0.to == trip.to }) {
                                                    store.deleteFavorite(fav.id)
                                                }
                                            } else {
                                                store.addFavorite(from: trip)
                                            }
                                        } label: {
                                            Label(isFav ? "Favorit entfernen" : "Als Favorit speichern",
                                                  systemImage: isFav ? "star.slash" : "star")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            store.deleteTrip(trip.id)
                                        } label: {
                                            Label(lm.t("action.delete"), systemImage: "trash")
                                        }.tint(.red)
                                    }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(lm.t("tab.trips"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            AppLogger.shared.logTap("Neue Fahrt (Menü)")
                            showAdd = true
                        } label: {
                            Label("Neue Fahrt", systemImage: "plus")
                        }
                        Button {
                            AppLogger.shared.logTap("GPS-Aufzeichnung (Menü)")
                            showGPSSheet = true
                        } label: {
                            Label("GPS-Aufzeichnung", systemImage: "location.circle.fill")
                        }
                        Divider()
                        Button {
                            AppLogger.shared.logTap("Einstellungen (Menü)")
                            settingsCtrl.showSettings = true
                        } label: {
                            Label("Einstellungen", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(.blue)
                    }
                    .accessibilityLabel("Aktionen")
                    .accessibilityHint("Öffnet Menü für neue Fahrt, GPS-Aufzeichnung und Einstellungen")
                }
            }
            // Manuell hinzufügen
            .sheet(isPresented: $showAdd) {
                TripFormView(mode: .add)
            }
            // Bearbeiten
            .sheet(item: $editTrip) { trip in
                TripFormView(mode: .edit(trip))
            }
            // GPS-Aufzeichnungs-Sheet
            // Nach Stop: Fahrt wird DIREKT gespeichert – kein extra Formular nötig
            .sheet(isPresented: $showGPSSheet) {
                GPSTripSheet(tracker: locationTracker) { from, to, km, duration, startDate, endDate in
                    // Fahrzeit formatieren
                    let h = duration / 3600
                    let m = (duration % 3600) / 60
                    let fahrzeitText: String
                    if h > 0 { fahrzeitText = String(format: "%dh %02dmin", h, m) }
                    else if m > 0 { fahrzeitText = String(format: "%dmin", m) }
                    else { fahrzeitText = "" }

                    // Tatsächliche Start-/Endzeit übernehmen (statt 08:00-Fallback)
                    let start = startDate ?? endDate
                    var trip = Trip(
                        from: from,
                        to: to.isEmpty ? from : to,
                        date: start,
                        km: km,
                        note: "GPS-Fahrt",
                        startTime: start,
                        endTime: endDate
                    )
                    trip.fahrzeitText = fahrzeitText.isEmpty ? nil : fahrzeitText
                    store.addTrip(trip)
                    AppLogger.shared.log("GPS-Fahrt gespeichert: \(from) → \(to.isEmpty ? from : to), \(String(format: "%.1f", km)) km", level: .gps)
                    showGPSSheet = false
                }
                .onAppear { locationTracker.requestAndStart() }
            }
            // Maps-Import
            .sheet(item: $importMode) { mode in
                TripFormView(mode: mode)
            }
            .onReceive(NotificationCenter.default.publisher(for: .importFromMaps)) { note in
                guard let from = note.userInfo?["from"] as? String,
                      let to   = note.userInfo?["to"]   as? String else { return }
                let travelTime = note.userInfo?["travelTime"] as? Int ?? 0
                let km         = note.userInfo?["km"] as? Double ?? 0
                importMode = .importFromMaps(from: from, to: to, travelTime: travelTime, km: km)
            }
            // ── CarPlay GPS-Signale ────────────────────────────────
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("carPlayStartGPS"))) { _ in
                locationTracker.requestAndStart()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("carPlayStopGPS"))) { _ in
                handleCarPlayStopGPS()
            }
        }
    }
}

// MARK: - GPS-Aufzeichnungs-Sheet
struct GPSTripSheet: View {
    @ObservedObject var tracker: LocationTracker
    @EnvironmentObject var lm: LocalizationManager

    let onResult: (String, String, Double, Int, Date?, Date) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                switch tracker.phase {
                case .idle:
                    idleView
                case .waitingForPermission:
                    waitingView
                case .tracking:
                    trackingView
                case .paused:
                    pausedView
                case .geocoding:
                    geocodingView
                }
            }
            .navigationTitle(lm.t("trips.gps.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.t("action.cancel")) {
                        if tracker.isTracking {
                            tracker.stopAndGeocode { _, _, _ in }
                        }
                        dismiss()
                    }
                    .disabled(tracker.isGeocoding)
                }
            }
        }
        // Kein versehentliches Wischen während Aufzeichnung
        .interactiveDismissDisabled(tracker.isTracking || tracker.isGeocoding)
    }

    // ── Startbildschirm (wird beim Erscheinen sofort übersprungen, da onAppear startet) ──
    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.iosGreen)
            Text(lm.t("trips.gps.heading"))
                .font(.title2)
            Text(lm.t("trips.gps.desc"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let err = tracker.errorMessage {
                errorBanner(err)
            }
            Spacer()
            Button {
                tracker.requestAndStart()
            } label: {
                Label(lm.t("trips.gps.startbtn"), systemImage: "record.circle")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.iosGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding()
    }

    // ── Warte auf Standorterlaubnis ──
    private var waitingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityLabel("Warte auf Standortfreigabe")
            Text(lm.t("trips.gps.permission"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Text(lm.t("trips.gps.permission.desc"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // ── Live-Aufzeichnung ──
    private var trackingView: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Anzeige-Panel: Status + km + Zeit (kompakt) ──
                HStack(spacing: 16) {
                    // Aufnahme-Indikator
                    HStack(spacing: 5) {
                        PulsingDot(color: .blue)
                        Text("REC")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .kerning(1.0)
                    }
                    Spacer()
                    // Live-km-Anzeige
                    Text(tracker.totalKm.kmFormatted)
                        .font(.system(size: 28, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.spring(response: 0.35), value: tracker.totalKm)
                    Spacer()
                    // Vergangene Zeit
                    Text(formatElapsed(tracker.elapsedSeconds))
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                        .animation(.default, value: tracker.elapsedSeconds)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 3)
                .padding(.horizontal, 20)

                // ── Live-Karte ──
                LiveMapCard(tracker: tracker)

                if let err = tracker.errorMessage {
                    errorBanner(err)
                        .padding(.horizontal, 20)
                }

                // ── Stop-Button ──
                Button {
                    let elapsed = tracker.elapsedSeconds
                    let startDate = tracker.tripStartDate
                    let endDate = Date()
                    tracker.stopAndGeocode { from, to, km in
                        onResult(from, to, km, elapsed, startDate, endDate)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 22))
                        Text(lm.t("trips.gps.stop"))
                            .fontWeight(.regular)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // ── Pausiert (Stillstand > 5 Min) ──
    private var pausedView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status-Badge
                HStack(spacing: 8) {
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 22))
                    Text("PAUSIERT")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.orange)
                        .kerning(1.2)
                    Spacer()
                    Text(formatElapsed(tracker.elapsedSeconds))
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)

                // Kilometer-Anzeige
                VStack(spacing: 4) {
                    Text(tracker.totalKm.kmFormatted)
                        .font(.system(size: 42, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("aufgezeichnet bisher")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)

                Text("Automatisch pausiert – kein Fahrzeugbewegung erkannt.\nDie Aufzeichnung wird automatisch fortgesetzt, sobald du wieder fährst.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                // Manuell fortsetzen
                Button {
                    tracker.resumeTracking()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                        Text("Jetzt fortsetzen")
                            .fontWeight(.regular)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.iosGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)

                // Fahrt beenden
                Button {
                    let elapsed = tracker.elapsedSeconds
                    let startDate = tracker.tripStartDate
                    let endDate = Date()
                    tracker.stopAndGeocode { from, to, km in
                        onResult(from, to, km, elapsed, startDate, endDate)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 20))
                        Text("Fahrt beenden")
                            .fontWeight(.regular)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .padding(.top, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // ── Geocoding läuft ──
    private var geocodingView: some View {
        VStack(spacing: 22) {
            ProgressView()
                .scaleEffect(1.8)
                .accessibilityLabel("Adressen werden ermittelt")
            Text(lm.t("trips.gps.geocoding"))
                .font(.title3)
            Text(lm.t("trips.gps.geocoding.wait"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // ── Fehler-Banner ──
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // Sekunden → "00:00" oder "1:23:45"
    private func formatElapsed(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Aufnahme-Punkt (ohne Pulsieren)
struct PulsingDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }
}

// MARK: - Trip Row
struct TripRow: View {
    @EnvironmentObject var lm: LocalizationManager
    @AppStorage("homeAddress") private var homeAddress: String = ""

    let trip: Trip
    let kmRate: Double

    private var fuelInfo: String? {
        guard let price = trip.fuelPricePerLiter,
              let cons = trip.fuelConsumption,
              price > 0, cons > 0 else { return nil }
        let liter = (trip.km / 100.0) * cons
        return String(format: "%.1fL · %.3f€/L", liter, price)
            .replacingOccurrences(of: ".", with: ",")
    }

    private var accessibilityDescription: String {
        let dateStr = trip.date.formatted(.dateTime.day().month(.wide))
        var parts = ["Fahrt am \(dateStr), von \(trip.from) nach \(trip.to)"]
        parts.append(trip.km.kmFormatted)
        if let dur = trip.fahrzeitText ?? trip.durationText { parts.append(dur) }
        parts.append("Erstattung \((trip.km * kmRate).euroFormatted)")
        if let fuelCost = trip.fuelCost {
            parts.append("Spritkosten \(String(format: "%.2f €", fuelCost))")
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 10) {
            // Datum
            VStack(spacing: 1) {
                Text(trip.date.formatted(.dateTime.day()))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                Text(trip.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 30)
            .accessibilityHidden(true)

            // Hauptinhalt
            VStack(alignment: .leading, spacing: 4) {
                // Zeile 1: Von → Nach  (+  Art-Badge)
                HStack(spacing: 5) {
                    Image(systemName: trip.art == .privat ? "person.fill" : "briefcase.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(trip.art == .privat ? Color.orange : Color.blue)
                        .accessibilityHidden(true)
                    if !homeAddress.isEmpty && trip.from.localizedCaseInsensitiveContains(homeAddress) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }
                    Text(trip.from)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .accessibilityHidden(true)
                    Text(trip.to)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    if !homeAddress.isEmpty && trip.to.localizedCaseInsensitiveContains(homeAddress) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }
                }

                // Zeile 2: km · Dauer · Uhrzeiten
                HStack(spacing: 0) {
                    Text(trip.km.kmFormatted)
                        .foregroundStyle(.primary)
                    if let dur = trip.fahrzeitText ?? trip.durationText {
                        Text("  ·  " + dur)
                            .foregroundStyle(.primary)
                    }
                    if let st = trip.startTime, let et = trip.endTime {
                        Text("  ·  \(st.timeOnly)–\(et.timeOnly)")
                            .foregroundStyle(.primary)
                    }
                }
                .font(.system(size: 11))
                .lineLimit(1)

                // Zeile 3: Spritinfo (nur wenn vorhanden)
                if let fuel = fuelInfo {
                    Text(fuel)
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Betrag rechts
            VStack(alignment: .trailing, spacing: 2) {
                Text((trip.km * kmRate).euroFormatted)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.iosGreen)
                    .fixedSize()
                if let fuelCost = trip.fuelCost {
                    Text(String(format: "+%.2f€", fuelCost)
                        .replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .fixedSize()
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Tippen zum Bearbeiten, wischen für weitere Optionen")
    }
}

// MARK: - Trip Form Mode
enum TripFormMode: Identifiable {
    case add
    case edit(Trip)
    case gpsResult(from: String, to: String, km: Double, durationSeconds: Int)
    case importFromMaps(from: String, to: String, travelTime: Int = 0, km: Double = 0)

    var id: String {
        switch self {
        case .add:                                    return "add"
        case .edit(let t):                            return "edit-\(t.id)"
        case .gpsResult(let f, let t, _, _):          return "gps-\(f)-\(t)"
        case .importFromMaps(let f, let t, _, _):      return "import-\(f)-\(t)"
        }
    }
}

extension Notification.Name {
    static let importFromMaps = Notification.Name("fahrtkosten.importFromMaps")
}

// MARK: - Trip Form View
struct TripFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager

    let mode: TripFormMode

    @State private var from              = ""
    @State private var to                = ""
    @State private var date              = Date()
    @State private var kmString          = ""
    @State private var note              = ""
    @State private var tripArt: TripArt  = .geschaeftlich
    @State private var fahrzeitText      = ""
    @State private var fahrzeitStart     : Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var fahrzeitEnd       : Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var useFahrzeitPicker = false
    @State private var showMapsSheet     = false
    @State private var isLocatingStart   = false
    @State private var isLocatingEnd     = false
    @State private var showFuelSheet     = false
    @State private var showLocationConfirm   = false
    @State private var showRecurringManager = false
    @AppStorage("homeAddress")            private var homeAddress: String = ""
    @AppStorage("defaultFuelType")       private var defaultFuelTypeKey: String = "e10"
    @AppStorage("defaultFuelPrice.e5")      private var defaultPriceE5: String = ""
    @AppStorage("defaultFuelPrice.e10")     private var defaultPriceE10: String = ""
    @AppStorage("defaultFuelPrice.diesel")  private var defaultPriceDiesel: String = ""
    @AppStorage("defaultFuelPrice.elektro") private var defaultPriceElektro: String = ""
    @AppStorage("defaultFuelPrice.hybrid")  private var defaultPriceHybrid: String = ""
    @AppStorage("defaultConsumption.e5")      private var defaultConsE5: String = ""
    @AppStorage("defaultConsumption.e10")     private var defaultConsE10: String = ""
    @AppStorage("defaultConsumption.diesel")  private var defaultConsDiesel: String = ""
    @AppStorage("defaultConsumption.elektro") private var defaultConsElektro: String = ""
    @AppStorage("defaultConsumption.hybrid")  private var defaultConsHybrid: String = ""

    private var defaultPriceForCurrentFuel: String {
        switch defaultFuelTypeKey {
        case "e5":      return defaultPriceE5
        case "diesel":  return defaultPriceDiesel
        case "elektro": return defaultPriceElektro
        case "hybrid":  return defaultPriceHybrid
        default:        return defaultPriceE10
        }
    }
    private var defaultConsumptionForCurrentFuel: String {
        switch defaultFuelTypeKey {
        case "e5":      return defaultConsE5
        case "diesel":  return defaultConsDiesel
        case "elektro": return defaultConsElektro
        case "hybrid":  return defaultConsHybrid
        default:        return defaultConsE10
        }
    }

    // Direkt aus AppStorage initialisieren – nicht auf onAppear warten
    private var defaultFuelTypeFromKey: FuelType {
        switch defaultFuelTypeKey {
        case "e5":      return .e5
        case "diesel":  return .diesel
        case "elektro": return .elektro
        case "hybrid":  return .hybrid
        default:        return .e10
        }
    }

    @State private var selectedFuelType  : FuelType = .e10
    @State private var fuelPriceStr      = ""
    @State private var fuelConsumptionStr = ""
    // Hybrid: zusätzliche Benzin-Felder
    @State private var hybridFuelPriceStr      = ""
    @State private var hybridFuelConsumptionStr = ""
    @State private var routeTask: Task<Void, Never>? = nil

    @StateObject private var mapsService      = MapsService()
    @StateObject private var fuelService      = FuelPriceService()
    @StateObject private var locationProvider = CurrentLocationProvider()

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }
    private var isGPS: Bool {
        if case .gpsResult = mode { return true }
        return false
    }
    private var gpsDurationSeconds: Int {
        if case .gpsResult(_, _, _, let d) = mode { return d }
        return 0
    }
    private var editingTrip: Trip? {
        if case .edit(let t) = mode { return t }
        return nil
    }
    private var kmValue: Double { parseCurrency(kmString) }
    private var isValid: Bool { !from.isEmpty && !to.isEmpty && kmValue > 0 }

    var body: some View {
        NavigationStack {
            Form {
                // ── GPS-Hinweis-Banner ──
                if isGPS {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.iosGreen)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lm.t("trips.gps.detected"))
                                    .font(.subheadline)
                                Text(lm.t("trips.gps.detected.desc"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.iosGreen.opacity(0.08))
                    }
                }

                // ── Favoriten ──
                if !isEdit && !isGPS && !store.favorites.isEmpty {
                    Section("Favoriten") {
                        ForEach(store.favorites) { fav in
                            Button {
                                from     = fav.from
                                to       = fav.to
                                kmString = String(Int(fav.km.rounded()))
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.caption)
                                    Text(fav.from)
                                        .lineLimit(1)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(fav.to)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(fav.km.kmFormatted)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .foregroundStyle(.primary)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deleteFavorite(fav.id)
                                } label: {
                                    Label("Entfernen", systemImage: "star.slash")
                                }
                            }
                        }
                    }
                }

                // ── Wiederkehrende Fahrten (Vorschläge für heute) ──
                if !isEdit && !isGPS {
                    let suggestions = store.todaysRecurringTrips()
                    if !suggestions.isEmpty {
                        Section {
                            ForEach(suggestions) { rec in
                                Button {
                                    from     = rec.from
                                    to       = rec.to
                                    kmString = String(Int(rec.km.rounded()))
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.purple.opacity(0.12))
                                                .frame(width: 34, height: 34)
                                            Image(systemName: "repeat.circle.fill")
                                                .foregroundColor(.purple)
                                                .font(.system(size: 16))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(rec.from) → \(rec.to)")
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                            HStack(spacing: 6) {
                                                Text(rec.km.kmFormatted)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text("·")
                                                    .foregroundStyle(.secondary)
                                                    .font(.caption)
                                                Text(rec.weekdayLabel)
                                                    .font(.caption)
                                                    .foregroundStyle(.purple)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundColor(.purple.opacity(0.4))
                                            .font(.system(size: 18))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack {
                                Label("Heute üblich", systemImage: "repeat.circle.fill")
                                    .foregroundColor(.purple)
                                Spacer()
                                Button {
                                    showRecurringManager = true
                                } label: {
                                    Text("Verwalten")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                        .listRowBackground(Color.purple.opacity(0.04))
                    }
                }

                // ── Route ──
                Section(lm.t("trips.route")) {
                    locationRow(
                        label: lm.t("trips.from"),
                        placeholder: lm.t("trips.start"),
                        text: $from,
                        color: .green,
                        isLocating: $isLocatingStart
                    )
                    locationRow(
                        label: lm.t("trips.to"),
                        placeholder: lm.t("trips.destination"),
                        text: $to,
                        color: .blue,
                        isLocating: $isLocatingEnd
                    )
                    DatePicker(lm.t("common.date"), selection: $date, displayedComponents: .date)
                    HStack {
                        Label(lm.t("trips.km.label"), systemImage: "road.lanes")
                        Spacer()
                        TextField("0,0", text: $kmString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Label(lm.t("common.note"), systemImage: "note.text")
                        Spacer()
                        TextField(lm.t("common.optional"), text: $note)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack(spacing: 0) {
                        Button {
                            tripArt = .geschaeftlich
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "briefcase.fill")
                                Text("Geschäftlich")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(tripArt == .geschaeftlich ? Color.blue : Color(.systemGray5))
                            .foregroundColor(tripArt == .geschaeftlich ? .white : Color(.label))
                        }
                        .buttonStyle(.plain)

                        Button {
                            tripArt = .privat
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "house.fill")
                                Text("Privat")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(tripArt == .privat ? Color.orange : Color(.systemGray5))
                            .foregroundColor(tripArt == .privat ? .white : Color(.label))
                        }
                        .buttonStyle(.plain)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .listRowInsets(EdgeInsets())
                    // Abfahrtszeit
                    DatePicker("Abfahrt", selection: $fahrzeitStart, displayedComponents: .hourAndMinute)
                        .foregroundColor(.purple)
                        .onChange(of: fahrzeitStart) { _, _ in updateFahrzeitFromPicker() }
                    // Ankunftszeit
                    DatePicker("Ankunft", selection: $fahrzeitEnd, displayedComponents: .hourAndMinute)
                        .foregroundColor(.purple)
                        .onChange(of: fahrzeitEnd) { _, _ in updateFahrzeitFromPicker() }
                }

                // ── Maps-Integration (nur wenn NICHT GPS-Modus) ──
                if !isGPS {
                    Section {
                        MapsRouteSection(
                            from: from,
                            to: to,
                            mapsService: mapsService,
                            onOpenMaps: { showMapsSheet = true }
                        )
                    } header: {
                        Text("Google Maps / Apple Maps")
                    }
                }

                // ── Navigation starten ──
                if !from.isEmpty && !to.isEmpty {
                    Section(lm.t("trips.navigation.section")) {
                        Button {
                            showMapsSheet = true
                        } label: {
                            Label(lm.t("trips.nav.start"), systemImage: "location.fill")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.regular)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }


                // ── Kraftstoffkosten (aus Einstellungen) ──
                Section {
                    // Antriebsart
                    HStack {
                        Label("Antrieb / Kraftstoff", systemImage: selectedFuelType.icon)
                            .foregroundColor(.orange)
                        Spacer()
                        Picker("", selection: $selectedFuelType) {
                            ForEach(FuelType.allCases) { ft in
                                Label(ft.rawValue, systemImage: ft.icon).tag(ft)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // ── Elektro-Block ──
                    if selectedFuelType == .elektro {
                        fuelRow(label: "Strompreis (€/kWh)", icon: "bolt.fill",
                                placeholder: "z.B. 0,30", unit: "€/kWh",
                                priceStr: $fuelPriceStr, showRefresh: false)
                        if fuelPriceStr.isEmpty, let fp = fuelService.currentPrice {
                            Button {
                                fuelPriceStr = String(format: "%.2f", fp.pricePerLiter)
                                    .replacingOccurrences(of: ".", with: ",")
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .font(.caption).foregroundColor(.secondary)
                                    Text("Ø Standardwert übernehmen (0,30 €/kWh)")
                                        .font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        consumptionRow(label: "Verbrauch (kWh/100 km)",
                                       placeholder: "z.B. 18,0", unit: "kWh/100 km",
                                       consumptionStr: $fuelConsumptionStr)
                        costSummaryRow(label: "Stromkosten",
                                       priceStr: fuelPriceStr, consumptionStr: fuelConsumptionStr)

                    // ── Hybrid-Block: Strom + Benzin ──
                    } else if selectedFuelType == .hybrid {

                        // Strom-Teil
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.iosGreen)
                                .font(.caption)
                                .frame(width: 16)
                            Text("Strom").font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(.top, 2)

                        fuelRow(label: "Strompreis (€/kWh)", icon: "eurosign.circle",
                                placeholder: "z.B. 0,30", unit: "€/kWh",
                                priceStr: $fuelPriceStr, showRefresh: false)
                        if fuelPriceStr.isEmpty, let fp = fuelService.currentPrice {
                            Button {
                                fuelPriceStr = String(format: "%.2f", fp.pricePerLiter)
                                    .replacingOccurrences(of: ".", with: ",")
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .font(.caption).foregroundColor(.secondary)
                                    Text("Ø Standardwert übernehmen (0,30 €/kWh)")
                                        .font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        consumptionRow(label: "Verbrauch (kWh/100 km)",
                                       placeholder: "z.B. 15,0", unit: "kWh/100 km",
                                       consumptionStr: $fuelConsumptionStr)
                        costSummaryRow(label: "Stromkosten",
                                       priceStr: fuelPriceStr, consumptionStr: fuelConsumptionStr)

                        Divider()

                        // Benzin-Teil
                        HStack {
                            Image(systemName: "fuelpump.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                                .frame(width: 16)
                            Text("Benzin").font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(.top, 2)

                        hybridFuelRow()
                        consumptionRow(label: "Verbrauch (L/100 km)",
                                       placeholder: "z.B. 4,0", unit: "L/100 km",
                                       consumptionStr: $hybridFuelConsumptionStr)
                        costSummaryRow(label: "Benzinkosten",
                                       priceStr: hybridFuelPriceStr, consumptionStr: hybridFuelConsumptionStr)

                        // Hybrid-Gesamtkosten
                        if let ep = parseFuelInput(fuelPriceStr), let ec = parseFuelInput(fuelConsumptionStr),
                           let fp = parseFuelInput(hybridFuelPriceStr), let fc = parseFuelInput(hybridFuelConsumptionStr),
                           kmValue > 0 {
                            Divider()
                            HStack {
                                Text("Gesamtkosten (Hybrid)")
                                    .fontWeight(.semibold)
                                Spacer()
                                let total = (kmValue / 100.0) * (ec * ep + fc * fp)
                                Text(total.euroFormatted)
                                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                        }

                    // ── Standard Benzin/Diesel ──
                    } else {
                        fuelRow(label: selectedFuelType.priceLabel, icon: "eurosign.circle",
                                placeholder: selectedFuelType.pricePlaceholder, unit: selectedFuelType.priceUnit,
                                priceStr: $fuelPriceStr, showRefresh: true)
                        if let fp = fuelService.currentPrice, fuelPriceStr.isEmpty {
                            Button {
                                fuelPriceStr = String(format: "%.3f", fp.pricePerLiter)
                                    .replacingOccurrences(of: ".", with: ",")
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: fp.isFallback ? "info.circle" : "location.fill")
                                        .font(.caption)
                                        .foregroundColor(fp.isFallback ? .secondary : .iosGreen)
                                    Text(fp.isFallback ? "Ø Preis übernehmen" : "Preis von Tankstelle übernehmen")
                                        .font(.caption)
                                        .foregroundColor(fp.isFallback ? .secondary : .iosGreen)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        consumptionRow(label: selectedFuelType.consumptionLabel,
                                       placeholder: selectedFuelType.consumptionPlaceholder,
                                       unit: selectedFuelType.consumptionUnit,
                                       consumptionStr: $fuelConsumptionStr)
                        costSummaryRow(label: "Kraftstoffkosten",
                                       priceStr: fuelPriceStr, consumptionStr: fuelConsumptionStr)
                    }

                } header: {
                    Text(selectedFuelType == .elektro ? "Stromkosten" :
                         selectedFuelType == .hybrid  ? "Antriebskosten (Hybrid)" : "Kraftstoffkosten")
                } footer: {
                    Text("Antrieb & Verbrauch können in den Einstellungen dauerhaft gespeichert werden.")
                        .font(.caption)
                }

                // ── Berechnung ──
                if kmValue > 0 {
                    Section(lm.t("trips.calculation")) {
                        LabeledRow(label: lm.t("trips.distance"),   value: kmValue.kmFormatted)
                        LabeledRow(label: lm.t("trips.rate"), value: "\(String(format: "%.2f", store.kmRate).replacingOccurrences(of: ".", with: ",")) € / km")
                        HStack {
                            Text(lm.t("trips.reimbursement")).fontWeight(.regular)
                            Spacer()
                            Text((kmValue * store.kmRate).euroFormatted)
                                .font(.system(size: 18, weight: .regular, design: .monospaced))
                                .foregroundColor(.iosGreen)
                        }
                    }
                }
            }
            .navigationTitle(isEdit ? lm.t("trips.form.edit") : lm.t("trips.form.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.t("action.cancel")) {
                        routeTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? lm.t("action.save") : lm.t("action.add")) {
                        save()
                    }
                    .disabled(!isValid)
                    .fontWeight(.regular)
                }
            }
            .sheet(isPresented: $showRecurringManager) {
                RecurringTripManagerView()
                    .environmentObject(store)
                    .environmentObject(lm)
            }
            .onAppear { prefill() }
            .task {
                switch mode {
                case .add, .gpsResult:
                    if selectedFuelType.isElectric {
                        // Elektro: fetchPrice gibt sofort Standardwert zurück, kein Netzwerk
                        await fuelService.fetchPrice(fuelType: selectedFuelType, near: nil)
                    } else {
                        locationProvider.requestOnce()
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        await fuelService.fetchPrice(fuelType: selectedFuelType, near: locationProvider.location)
                    }
                default: break
                }
            }
            .onChange(of: locationProvider.location) { _, loc in
                guard loc != nil, fuelPriceStr.isEmpty else { return }
                // Bei Elektro nur erneut abrufen wenn noch kein Preis da (für DE/AT-Präzisierung)
                guard fuelService.currentPrice == nil || selectedFuelType.isElectric else { return }
                Task {
                    await fuelService.fetchPrice(
                        fuelType: selectedFuelType,
                        near: loc
                    )
                }
            }
            .onChange(of: selectedFuelType) { _, newType in
                // Gespeicherte Werte für neue Kraftstoffart laden
                let savedPrice: String
                let savedCons: String
                switch newType {
                case .e5:      savedPrice = defaultPriceE5;      savedCons = defaultConsE5
                case .e10:     savedPrice = defaultPriceE10;     savedCons = defaultConsE10
                case .diesel:  savedPrice = defaultPriceDiesel;  savedCons = defaultConsDiesel
                case .elektro: savedPrice = defaultPriceElektro; savedCons = defaultConsElektro
                case .hybrid:  savedPrice = defaultPriceHybrid;  savedCons = defaultConsHybrid
                }
                fuelPriceStr      = savedPrice
                fuelConsumptionStr = savedCons
                // Tankerkönig abrufen wenn kein gespeicherter Preis und kein Elektro
                if savedPrice.isEmpty && !newType.isElectric {
                    locationProvider.requestOnce()
                    Task { await fuelService.fetchPrice(fuelType: newType, near: locationProvider.location) }
                }
            }
            // Auto-Berechnung: nur im Add-Modus (nicht bei GPS, nicht beim Bearbeiten)
            .onChange(of: from) { _, _ in
                if !isGPS && !isEdit { scheduleAutoCalculate() }
            }
            .onChange(of: to) { _, _ in
                if !isGPS && !isEdit { scheduleAutoCalculate() }
            }
            // Einstellungsänderung live übernehmen (nur im Add-Modus)
            .onChange(of: defaultFuelTypeKey) { _, _ in
                guard case .add = mode else { return }
                selectedFuelType = defaultFuelTypeFromKey
            }
            .onChange(of: mapsService.routeResult?.km) { _, newKm in
                guard let km = newKm, !isGPS, !isEdit else { return }
                kmString = String(Int(km.rounded()))
            }
            .confirmationDialog(lm.t("trips.maps.open"), isPresented: $showMapsSheet, titleVisibility: .visible) {
                Button(lm.t("trips.apple.maps")) { MapsService.openInAppleMaps(from: from, to: to) }
                Button(lm.t("trips.google.maps"))  { MapsService.openInGoogleMaps(from: from, to: to) }
                Button(lm.t("action.cancel"), role: .cancel) {}
            }
        }
    }

    // MARK: - Helpers

    // MARK: - Fuel Helper Views

    @ViewBuilder
    private func fuelRow(label: String, icon: String, placeholder: String, unit: String,
                         priceStr: Binding<String>, showRefresh: Bool) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            if fuelService.isLoading && showRefresh { ProgressView().scaleEffect(0.7) }
            TextField(placeholder, text: priceStr)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            if showRefresh {
                Button {
                    showLocationConfirm = true
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(selectedFuelType.isElectric ? .iosGreen : .orange)
                }
                .buttonStyle(.plain)
                .confirmationDialog("Aktuellen Standort verwenden?",
                                    isPresented: $showLocationConfirm,
                                    titleVisibility: .visible) {
                    Button("Ja, Preis abrufen") {
                        locationProvider.requestOnce()
                        Task {
                            for _ in 0..<30 {
                                if locationProvider.location != nil { break }
                                try? await Task.sleep(nanoseconds: 100_000_000)
                            }
                            await fuelService.fetchPrice(fuelType: selectedFuelType, near: locationProvider.location)
                            if let fp = fuelService.currentPrice, !fp.isFallback {
                                fuelPriceStr = String(format: "%.3f", fp.pricePerLiter)
                                    .replacingOccurrences(of: ".", with: ",")
                            }
                        }
                    }
                    Button("Abbrechen", role: .cancel) {}
                } message: {
                    Text("Der aktuelle Standort wird genutzt, um den Spritpreis in deiner Nähe abzurufen.")
                }
            }
        }
    }

    @ViewBuilder
    private func hybridFuelRow() -> some View {
        HStack {
            Label("Benzinpreis (€/L)", systemImage: "eurosign.circle")
            Spacer()
            if fuelService.isLoading { ProgressView().scaleEffect(0.7) }
            TextField("z.B. 1,75", text: $hybridFuelPriceStr)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Button {
                locationProvider.requestOnce()
                Task {
                    for _ in 0..<30 {
                        if locationProvider.location != nil { break }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    await fuelService.fetchPrice(fuelType: .e10, near: locationProvider.location)
                }
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill").foregroundColor(.orange)
            }
            .buttonStyle(.plain)
        }
        if let fp = fuelService.currentPrice, hybridFuelPriceStr.isEmpty {
            Button {
                hybridFuelPriceStr = String(format: "%.3f", fp.pricePerLiter)
                    .replacingOccurrences(of: ".", with: ",")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: fp.isFallback ? "info.circle" : "location.fill")
                        .font(.caption)
                        .foregroundColor(fp.isFallback ? .secondary : .iosGreen)
                    Text(fp.isFallback ? "Ø Preis übernehmen" : "Preis von Tankstelle übernehmen")
                        .font(.caption)
                        .foregroundColor(fp.isFallback ? .secondary : .iosGreen)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func consumptionRow(label: String, placeholder: String, unit: String,
                                consumptionStr: Binding<String>) -> some View {
        HStack {
            Label(label, systemImage: "gauge.medium")
            Spacer()
            TextField(placeholder, text: consumptionStr)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    @ViewBuilder
    private func costSummaryRow(label: String, priceStr: String, consumptionStr: String) -> some View {
        if let price = parseFuelInput(priceStr), let cons = parseFuelInput(consumptionStr), kmValue > 0 {
            HStack {
                Text(label).fontWeight(.regular)
                Spacer()
                Text(((kmValue / 100.0) * cons * price).euroFormatted)
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
    }

    private func scheduleAutoCalculate() {
        routeTask?.cancel()
        guard !from.isEmpty, !to.isEmpty else { return }
        routeTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await mapsService.calculateRoute(from: from, to: to)
        }
    }

    // MARK: - Standort-Zeile
    @ViewBuilder
    private func locationRow(label: String, placeholder: String,
                              text: Binding<String>, color: Color,
                              isLocating: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Label(label, systemImage: "mappin.circle.fill")
                .foregroundColor(color)
            Spacer()
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
            if !homeAddress.isEmpty && text.wrappedValue.localizedCaseInsensitiveContains(homeAddress) {
                Image(systemName: "house.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 13))
            }
            locationButton(color: color, isLocating: isLocating) {
                isLocating.wrappedValue = true
                LocationHelper.currentAddress { addr in
                    isLocating.wrappedValue = false
                    if let a = addr { text.wrappedValue = a }
                }
            }
        }
    }

    @ViewBuilder
    private func locationButton(color: Color, isLocating: Binding<Bool>,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isLocating.wrappedValue {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "location.fill")
                        .foregroundColor(color)
                        .font(.system(size: 16))
                }
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(isLocating.wrappedValue)
    }

    private func parseFuelInput(_ s: String) -> Double? {
        let v = s.replacingOccurrences(of: ",", with: ".")
        guard let d = Double(v), d > 0 else { return nil }
        return d
    }

    private func prefill() {
        switch mode {
        case .add:
            // Direkt aus Einstellungen setzen
            selectedFuelType = defaultFuelTypeFromKey
            if !defaultConsumptionForCurrentFuel.isEmpty {
                fuelConsumptionStr = defaultConsumptionForCurrentFuel
            }
            if !defaultPriceForCurrentFuel.isEmpty {
                fuelPriceStr = defaultPriceForCurrentFuel
            }
        case .edit(let t):
            from        = t.from
            to          = t.to
            date        = t.date
            kmString    = String(Int(t.km.rounded()))
            note        = t.note
            tripArt     = t.art
            fahrzeitText = t.fahrzeitText ?? t.durationText ?? ""
            // Picker-Modus aktivieren wenn Fahrzeit vorhanden
            // Start/Endzeit wiederherstellen
            if let st = t.startTime { fahrzeitStart = st }
            if let et = t.endTime   { fahrzeitEnd   = et }
            if t.startTime == nil && !fahrzeitText.isEmpty {
                // Alten Text-basierten Wert: Startzeit = date 08:00, Endzeit berechnen
                let cal = Calendar.current
                if let base = cal.date(bySettingHour: 8, minute: 0, second: 0, of: t.date) {
                    fahrzeitStart = base
                    fahrzeitEnd = cal.date(byAdding: .minute, value: fahrzeitMinutes, to: base) ?? base
                }
            }
            if let fp = t.fuelPricePerLiter {
                fuelPriceStr = String(format: "%.3f", fp).replacingOccurrences(of: ".", with: ",")
            }
            if let fc = t.fuelConsumption {
                fuelConsumptionStr = String(format: "%.1f", fc).replacingOccurrences(of: ".", with: ",")
            }
            // Gespeicherte Kraftstoffart wiederherstellen
            if let raw = t.fuelTypeRaw {
                if raw.hasPrefix("hybrid|") {
                    // Hybrid-Daten dekodieren: "hybrid|benzinPreis|benzinVerbrauch"
                    selectedFuelType = .hybrid
                    let parts = raw.split(separator: "|", maxSplits: 3).map(String.init)
                    if parts.count >= 3 {
                        hybridFuelPriceStr      = parts[1]
                        hybridFuelConsumptionStr = parts[2]
                    }
                } else if let saved = FuelType.allCases.first(where: { $0.tankerkoenigKey == raw }) {
                    selectedFuelType = saved
                }
            }
        case .gpsResult(let f, let t, let km, let dur):
            from     = f
            to       = t
            kmString = String(Int(km.rounded()))
            note     = "GPS-Fahrt"
            let h = dur / 3600
            let m = (dur % 3600) / 60
            if h > 0 { fahrzeitText = String(format: "%dh %02dmin", h, m) }
            else if m > 0 { fahrzeitText = String(format: "%dmin", m) }
        case .importFromMaps(let f, let t, let travelTime, let km):
            from = f
            to   = t
            if km > 0 { kmString = String(Int(km.rounded())) }
            // Note = formatted travel time
            if travelTime > 0 {
                note = "Reisezeit"
                // Departure = now rounded to nearest 15 min
                let now = Date()
                let cal = Calendar.current
                let comps = cal.dateComponents([.hour, .minute], from: now)
                let rawMin = (comps.minute ?? 0)
                let roundedMin = ((rawMin + 7) / 15) * 15
                let minuteOverflow = roundedMin >= 60
                let finalMin = minuteOverflow ? roundedMin - 60 : roundedMin
                let finalHour = (comps.hour ?? 8) + (minuteOverflow ? 1 : 0)
                fahrzeitStart = cal.date(bySettingHour: finalHour % 24, minute: finalMin, second: 0, of: now) ?? now
                fahrzeitEnd   = fahrzeitStart.addingTimeInterval(TimeInterval(travelTime))
            } else {
                note = "Import aus Maps"
            }
            selectedFuelType = defaultFuelTypeFromKey
            if !defaultConsumptionForCurrentFuel.isEmpty { fuelConsumptionStr = defaultConsumptionForCurrentFuel }
            if !defaultPriceForCurrentFuel.isEmpty       { fuelPriceStr       = defaultPriceForCurrentFuel }
        }
    }

    private var fahrzeitMinutes: Int {
        guard !fahrzeitText.isEmpty else { return 0 }
        var total = 0
        if let hRange = fahrzeitText.range(of: #"(\d+)h"#, options: .regularExpression) {
            total += (Int(fahrzeitText[hRange].filter(\.isNumber)) ?? 0) * 60
        }
        if let mRange = fahrzeitText.range(of: #"(\d+)min"#, options: .regularExpression) {
            total += Int(fahrzeitText[mRange].filter(\.isNumber)) ?? 0
        }
        return total
    }

    private func updateFahrzeitFromPicker() {
        guard fahrzeitEnd > fahrzeitStart else { return }
        let mins = Int(fahrzeitEnd.timeIntervalSince(fahrzeitStart) / 60)
        let h = mins / 60; let m = mins % 60
        if h > 0 && m > 0 { fahrzeitText = String(format: "%dh %02dmin", h, m) }
        else if h > 0      { fahrzeitText = String(format: "%dh", h) }
        else               { fahrzeitText = String(format: "%dmin", m) }
    }

    private func save() {
        routeTask?.cancel()
        // Bei Hybrid: fuelTypeRaw speichert Benzinpreis|Benzinverbrauch kodiert
        let hybridExtra: String? = selectedFuelType == .hybrid
            ? "hybrid|\(hybridFuelPriceStr)|\(hybridFuelConsumptionStr)"
            : nil

        var trip = Trip(
            from: from, to: to, date: date,
            km: kmValue, note: note, art: tripArt,
            distanceText: mapsService.routeResult?.distanceText,
            durationText: mapsService.routeResult?.durationText,
            fuelPricePerLiter: parseFuelInput(fuelPriceStr),
            fuelConsumption: parseFuelInput(fuelConsumptionStr),
            fuelTypeRaw: hybridExtra ?? ((parseFuelInput(fuelPriceStr) != nil || parseFuelInput(fuelConsumptionStr) != nil) ? selectedFuelType.tankerkoenigKey : nil),
            startTime: fahrzeitEnd > fahrzeitStart ? fahrzeitStart : nil,
            endTime:   fahrzeitEnd > fahrzeitStart ? fahrzeitEnd   : nil
        )
        trip.fahrzeitText = fahrzeitText.isEmpty ? nil : fahrzeitText
        if let existing = editingTrip { trip.id = existing.id }
        if isEdit {
            store.updateTrip(trip)
            AppLogger.shared.log("Fahrt aktualisiert: \(from) → \(to), \(String(format: "%.1f", kmValue)) km", level: .store)
        } else {
            store.addTrip(trip)
            AppLogger.shared.log("Fahrt gespeichert: \(from) → \(to), \(String(format: "%.1f", kmValue)) km", level: .store)
        }
        dismiss()
    }

}

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
            .frame(height: 460)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 20)
    }
}
