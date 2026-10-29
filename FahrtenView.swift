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
class CurrentLocationProvider: NSObject, CLLocationManagerDelegate, ObservableObject {
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
    @EnvironmentObject var proMgr: ProManager

    @State private var showAdd                  = false
    @State private var editTrip: Trip?
    @State private var showGPSSheet             = false
    @State private var showRecurringManager     = false
    @State private var showProUpgrade    = false
    @State private var showGPSMacAlert   = false
    private var isRunningOnMac: Bool { ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp }
    @State private var importMode: TripFormMode? = nil
    

    // ── Zeitraum-Filter ──
    enum TripFilter: String, CaseIterable {
        case tag    = "Tag"
        case woche  = "Woche"
        case monat  = "Monat"
        case alle   = "Alle"
    }
    @AppStorage("fahrten.selectedFilter") private var selectedFilter: TripFilter = .alle
    @AppStorage("gps.trialUsed") private var gpsTrialUsed: Bool = false
    @State private var showGPSTrial = false
    @AppStorage("defaultFuelType")              private var defaultFuelTypeKey: String = "e10"
    @AppStorage("defaultFuelPrice.e5")          private var defaultPriceE5: String = ""
    @AppStorage("defaultFuelPrice.e10")         private var defaultPriceE10: String = ""
    @AppStorage("defaultFuelPrice.diesel")      private var defaultPriceDiesel: String = ""
    @AppStorage("defaultFuelPrice.elektro")     private var defaultPriceElektro: String = ""
    @AppStorage("defaultConsumption.e5")        private var defaultConsE5: String = ""
    @AppStorage("defaultConsumption.e10")       private var defaultConsE10: String = ""
    @AppStorage("defaultConsumption.diesel")    private var defaultConsDiesel: String = ""
    @AppStorage("defaultConsumption.elektro")   private var defaultConsElektro: String = ""
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
            if isRunningOnMac { showGPSMacAlert = true }
            else if proMgr.isPro { showGPSSheet = true }
            else if !gpsTrialUsed { showGPSTrial = true }
            else { showProUpgrade = true }
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
                            if isRunningOnMac { showGPSMacAlert = true }
                            else if proMgr.isPro { showGPSSheet = true }
                            else if !gpsTrialUsed { showGPSTrial = true }
                            else { showProUpgrade = true }
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
                            FilterChipBar(selection: $selectedFilter, labelFor: { filter in
                                switch filter {
                                case .tag:   return lm.t("filter.day")
                                case .woche: return lm.t("filter.week")
                                case .monat: return lm.t("filter.month")
                                case .alle:  return lm.t("filter.all")
                                }
                            })
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
                            Label(lm.t("trips.form.new"), systemImage: "plus")
                        }
                        Button {
                            AppLogger.shared.logTap("GPS-Aufzeichnung (Menü)")
                            if isRunningOnMac { showGPSMacAlert = true }
                            else if proMgr.isPro { showGPSSheet = true }
                            else if !gpsTrialUsed { showGPSTrial = true }
                            else { showProUpgrade = true }
                        } label: {
                            Label(lm.t("trips.gps.menu"), systemImage: "location.circle.fill")
                        }
                        Divider()
                        Button {
                            AppLogger.shared.logTap("Wiederkehrende Fahrten (Menü)")
                            showRecurringManager = true
                        } label: {
                            Label("Wiederkehrende Fahrten", systemImage: "repeat.circle")
                        }
                        Divider()
                        Button {
                            AppLogger.shared.logTap("Einstellungen (Menü)")
                            settingsCtrl.showSettings = true
                        } label: {
                            Label(lm.t("settings.title"), systemImage: "gearshape")
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
            // Wiederkehrende Fahrten
            .sheet(isPresented: $showRecurringManager) {
                RecurringTripManagerView()
                    .environmentObject(store)
                    .environmentObject(lm)
            }
            // Pro-Upgrade Sheet
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView().environmentObject(proMgr)
            }
            .sheet(isPresented: $showGPSTrial) {
                gpsTrialSheetContent
            }
            .alert("GPS nicht verfügbar", isPresented: $showGPSMacAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Die GPS-Aufzeichnung ist nur auf iPhone und iPad verfügbar. Starte die Fahrt auf deinem iPhone – die Daten werden automatisch per iCloud synchronisiert.")
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
                    if defaultFuelTypeKey != "hybrid" {
                        let fuelType: FuelType = {
                            switch defaultFuelTypeKey {
                            case "e5":      return .e5
                            case "diesel":  return .diesel
                            case "elektro": return .elektro
                            default:        return .e10
                            }
                        }()
                        let priceStr = switch defaultFuelTypeKey {
                            case "e5":      defaultPriceE5
                            case "diesel":  defaultPriceDiesel
                            case "elektro": defaultPriceElektro
                            default:        defaultPriceE10
                        }
                        let consStr = switch defaultFuelTypeKey {
                            case "e5":      defaultConsE5
                            case "diesel":  defaultConsDiesel
                            case "elektro": defaultConsElektro
                            default:        defaultConsE10
                        }
                        let price = Double(priceStr.replacingOccurrences(of: ",", with: "."))
                        let cons  = Double(consStr.replacingOccurrences(of: ",", with: "."))
                        if let price { trip.fuelPricePerLiter = price }
                        if let cons  { trip.fuelConsumption   = cons  }
                        // storageKey verwenden damit Edit-Modus Kraftstoffart immer korrekt dekodiert
                        trip.fuelTypeRaw = fuelType.storageKey
                    }
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
            .onReceive(NotificationCenter.default.publisher(for: .gpsTrackingAutoStopped)) { note in
                guard let info = note.userInfo else { return }
                let from      = info["from"]      as? String ?? ""
                let to        = info["to"]        as? String ?? from
                let km        = info["km"]        as? Double ?? 0
                let elapsed   = info["elapsed"]   as? Int    ?? 0
                let startDate = info["startDate"] as? Date
                let endDate   = info["endDate"]   as? Date   ?? Date()
                let h = elapsed / 3600
                let m = (elapsed % 3600) / 60
                let fahrzeitText: String
                if h > 0      { fahrzeitText = String(format: "%dh %02dmin", h, m) }
                else if m > 0 { fahrzeitText = String(format: "%dmin", m) }
                else          { fahrzeitText = "" }
                let start = startDate ?? endDate
                var trip = Trip(
                    from: from.isEmpty ? "Unbekannt" : from,
                    to: to.isEmpty ? (from.isEmpty ? "Unbekannt" : from) : to,
                    date: start,
                    km: km,
                    note: "GPS-Fahrt (auto)",
                    startTime: start,
                    endTime: endDate
                )
                trip.fahrzeitText = fahrzeitText.isEmpty ? nil : fahrzeitText
                if defaultFuelTypeKey != "hybrid" {
                    let fuelType: FuelType = {
                        switch defaultFuelTypeKey {
                        case "e5":      return .e5
                        case "diesel":  return .diesel
                        case "elektro": return .elektro
                        default:        return .e10
                        }
                    }()
                    let priceStr = switch defaultFuelTypeKey {
                        case "e5":      defaultPriceE5
                        case "diesel":  defaultPriceDiesel
                        case "elektro": defaultPriceElektro
                        default:        defaultPriceE10
                    }
                    let consStr = switch defaultFuelTypeKey {
                        case "e5":      defaultConsE5
                        case "diesel":  defaultConsDiesel
                        case "elektro": defaultConsElektro
                        default:        defaultConsE10
                    }
                    let price = Double(priceStr.replacingOccurrences(of: ",", with: "."))
                    let cons  = Double(consStr.replacingOccurrences(of: ",", with: "."))
                    if let price { trip.fuelPricePerLiter = price }
                    if let cons  { trip.fuelConsumption   = cons  }
                    trip.fuelTypeRaw = fuelType.storageKey
                }
                store.addTrip(trip)
                AppLogger.shared.log("GPS-Fahrt (auto-gestoppt) gespeichert: \(from) → \(to), \(String(format: "%.1f", km)) km", level: .gps)
            }
        }
    }

    @ViewBuilder
    private var gpsTrialSheetContent: some View {
        GPSTrialSheet {
            showGPSTrial = false
            gpsTrialUsed = true
            showGPSSheet = true
        } onUpgrade: {
            showGPSTrial = false
            showProUpgrade = true
        }
        .environmentObject(proMgr)
        .environmentObject(lm)
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
                        if tracker.isTracking || tracker.isPaused {
                            tracker.stopAndGeocode { _, _, _ in }
                        }
                        dismiss()
                    }
                    .disabled(tracker.isGeocoding)
                }
            }
        }
        // Kein versehentliches Wischen während Aufzeichnung oder Pause
        .interactiveDismissDisabled(tracker.isTracking || tracker.isPaused || tracker.isGeocoding)
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
        VStack(spacing: 0) {

            // ── Anzeige-Panel: Status + km + Zeit ──
            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    PulsingDot(color: .blue)
                    Text("REC")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .kerning(1.0)
                }
                Spacer()
                Text(gpsDistanceFormatted(tracker.totalKm))
                    .font(.system(size: 28, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.spring(response: 0.35), value: tracker.totalKm)
                Spacer()
                Text(formatElapsed(tracker.elapsedSeconds))
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText())
                    .animation(.default, value: tracker.elapsedSeconds)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 3)
            .padding(.horizontal, 20)

            Spacer(minLength: 8).fixedSize()

            // ── Tempo ──
            VStack(spacing: 4) {
                Text(String(format: "%.0f", tracker.currentSpeedKmh))
                    .font(.system(size: 43, weight: .thin, design: .monospaced))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .animation(.default, value: tracker.currentSpeedKmh)
                Text("km/h")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .kerning(1.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 3)
            .padding(.horizontal, 20)

            Spacer(minLength: 8).fixedSize()

            // ── Live-Karte ──
            LiveMapCard(tracker: tracker)

            if let err = tracker.errorMessage {
                errorBanner(err)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            Spacer(minLength: 8).fixedSize()

            // ── Pause + Stop ──
            HStack(spacing: 12) {
                Button { tracker.pauseTracking() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 22))
                        Text(lm.t("trips.gps.pause"))
                            .fontWeight(.regular)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
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
                    Text(lm.t("misc.paused").uppercased())
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
                    Text(gpsDistanceFormatted(tracker.totalKm))
                        .font(.system(size: 42, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                    Text(lm.t("misc.recorded.so.far"))
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
                        Text(lm.t("misc.resume"))
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
                        Text(lm.t("misc.end.trip"))
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

    // ── GPS-Distanz: Meter unter 1 km, sonst eine Nachkommastelle ──
    private func gpsDistanceFormatted(_ km: Double) -> String {
        if km < 1.0 {
            let m = (Int(km * 1000) / 100) * 100
            return "\(m) m"
        }
        let truncated = Double(Int(km * 10)) / 10.0
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        f.decimalSeparator = ","
        return (f.string(from: NSNumber(value: truncated)) ?? "0,0") + " km"
    }

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

