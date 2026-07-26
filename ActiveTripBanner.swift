import SwiftUI
import Combine

// MARK: - App Group ID (muss mit FahrtkostenIntents.swift übereinstimmen)
private let kAppGroupID = "group.de.tommwagner.fahrtkosten"
private var appGroupDefaults: UserDefaults {
    UserDefaults(suiteName: kAppGroupID) ?? .standard
}

// MARK: - Aktive Fahrt Banner
struct ActiveTripBanner: View {
    @Binding var activeTrip: Trip?
    @State private var showStopSheet = false
    @State private var elapsed: String = "00:00"
    @State private var timer: Timer?

    var body: some View {
        if let trip = activeTrip {
            HStack(spacing: 12) {
                // Pulsierende Aufnahme-Anzeige (dekorativ)
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.25))
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fahrt läuft · \(elapsed)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text("→ \(trip.to)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Button {
                    showStopSheet = true
                } label: {
                    Text("Stoppen")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Fahrt stoppen")
                .accessibilityHint("Öffnet das Formular zum Beenden der aktuellen Fahrt")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red.gradient)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Aktive Fahrt nach \(trip.to), läuft seit \(elapsed)")
            .accessibilityAddTraits(.isHeader)
            .onAppear { startTimer(from: trip.startTime ?? Date()) }
            .onDisappear { timer?.invalidate() }
            .sheet(isPresented: $showStopSheet) {
                StopTripSheet(trip: trip, activeTrip: $activeTrip)
                    .presentationDetents([.medium])
            }
        }
    }

    private func startTimer(from start: Date) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let diff = Int(Date().timeIntervalSince(start))
            let h = diff / 3600
            let m = (diff % 3600) / 60
            let s = diff % 60
            if h > 0 {
                elapsed = String(format: "%d:%02d:%02d", h, m, s)
            } else {
                elapsed = String(format: "%02d:%02d", m, s)
            }
        }
    }
}

// MARK: - Stop Sheet
struct StopTripSheet: View {
    let trip: Trip
    @Binding var activeTrip: Trip?
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    @State private var kmText: String = ""
    @State private var note: String = ""

    @AppStorage("defaultFuelType")            private var defaultFuelTypeKey: String = "e10"
    @AppStorage("defaultFuelPrice.e5")        private var defaultPriceE5: String = ""
    @AppStorage("defaultFuelPrice.e10")       private var defaultPriceE10: String = ""
    @AppStorage("defaultFuelPrice.diesel")    private var defaultPriceDiesel: String = ""
    @AppStorage("defaultFuelPrice.elektro")   private var defaultPriceElektro: String = ""
    @AppStorage("defaultFuelPrice.hybrid")    private var defaultPriceHybrid: String = ""
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

    private func parseFuelInput(_ s: String) -> Double? {
        let v = s.replacingOccurrences(of: ",", with: ".")
        guard let d = Double(v), d > 0 else { return nil }
        return d
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label(trip.from, systemImage: "location.fill")
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        Spacer()
                        Label(trip.to, systemImage: "mappin.fill")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Von \(trip.from) nach \(trip.to)")
                    if let start = trip.startTime {
                        LabeledContent("Gestartet") {
                            Text(start, style: .time)
                        }
                    }
                } header: { Text("Aktive Fahrt") }

                Section {
                    HStack {
                        TextField("z.B. 45.3", text: $kmText)
                            .keyboardType(.decimalPad)
                        Text("km")
                            .foregroundColor(.secondary)
                    }
                } header: { Text("Kilometer eingeben") }

                Section {
                    TextField("Optionale Notiz", text: $note)
                } header: { Text("Notiz") }
            }
            .navigationTitle("Fahrt beenden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { saveAndStop() }
                        .disabled(kmText.isEmpty)
                        .bold()
                }
            }
        }
    }

    private func saveAndStop() {
        let km = Double(kmText.replacingOccurrences(of: ",", with: ".")) ?? 0
        var finished = trip
        finished.km      = km
        finished.endTime = Date()
        if !note.isEmpty { finished.note = note }

        // Voreingestellte Spritangaben aus den Einstellungen übernehmen (wie beim manuellen Anlegen).
        // Hybrid ausgenommen: dafür gibt es keinen gespeicherten Benzin-Anteil, nur den Strom-Anteil,
        // daher hier lieber leer lassen statt falsche Werte zu übernehmen.
        if defaultFuelTypeKey != "hybrid" {
            let price = parseFuelInput(defaultPriceForCurrentFuel)
            let cons  = parseFuelInput(defaultConsumptionForCurrentFuel)
            finished.fuelPricePerLiter = price
            finished.fuelConsumption   = cons
            if price != nil || cons != nil {
                let fuelType: FuelType = {
                    switch defaultFuelTypeKey {
                    case "e5":      return .e5
                    case "diesel":  return .diesel
                    case "elektro": return .elektro
                    default:        return .e10
                    }
                }()
                finished.fuelTypeRaw = fuelType.tankerkoenigKey
            }
        }

        store.addTrip(finished)
        // Aus App Group löschen – gleicher Speicher wie Intent
        appGroupDefaults.removeObject(forKey: "activeTrip")
        activeTrip = nil
        dismiss()
    }
}

// MARK: - ActiveTrip Manager
// Liest aus App Group UserDefaults – gleicher Speicher wie der Intent
class ActiveTripManager: ObservableObject {
    @Published var activeTrip: Trip?

    private let key = "activeTrip"
    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: Timer?

    init() {
        load()

        // App Group UserDefaults feuert didChangeNotification nicht zuverlässig
        // → zusätzlich alle 2 Sekunden pollen wenn App im Vordergrund ist
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.startPolling()
            self?.load()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.stopPolling()
        }

        startPolling()
    }

    deinit { stopPolling() }

    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.load()
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func load() {
        guard let data = appGroupDefaults.data(forKey: key),
              let trip = try? JSONDecoder().decode(Trip.self, from: data) else {
            if activeTrip != nil { activeTrip = nil }
            return
        }
        // Nur updaten wenn sich was geändert hat
        if activeTrip?.id != trip.id {
            activeTrip = trip
        }
    }
}
