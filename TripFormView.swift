import SwiftUI
import Combine
import CoreLocation

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
    @State private var purpose           = ""
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
    @State private var editingFavorite: FavoriteTrip?
    @State private var favoriteJustSaved = false
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
                    Section {
                        ForEach(store.favorites) { fav in
                            Button {
                                from     = fav.from
                                to       = fav.to
                                kmString = fav.km.kmInputString
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
                                    Text(fav.km.kmInputString + " km")
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
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingFavorite = fav
                                } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button {
                                    editingFavorite = fav
                                } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    store.deleteFavorite(fav.id)
                                } label: {
                                    Label("Entfernen", systemImage: "star.slash")
                                }
                            }
                        }
                    } header: {
                        Text("Favoriten")
                    } footer: {
                        Text("Nach rechts wischen oder lange drücken zum Bearbeiten, nach links wischen zum Entfernen.")
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
                        Label(lm.t("trips.purpose"), systemImage: "tag")
                        Spacer()
                        TextField(lm.t("trips.purpose.placeholder"), text: $purpose)
                            .multilineTextAlignment(.trailing)
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
                                Text(lm.t("misc.business"))
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
                                Text(lm.t("misc.private"))
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

                // ── Als Favorit speichern ──
                if !isEdit && !isGPS {
                    Section {
                        Button {
                            store.addFavorite(from: from, to: to, km: (kmValue * 10).rounded() / 10)
                            favoriteJustSaved = true
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { favoriteJustSaved = false }
                        } label: {
                            Label(favoriteJustSaved ? "Als Favorit gespeichert" : "Als Favorit speichern",
                                  systemImage: favoriteJustSaved ? "checkmark.circle.fill" : "star")
                                .foregroundColor(favoriteJustSaved ? Color.green : nil)
                        }
                        .disabled(from.trimmingCharacters(in: .whitespaces).isEmpty
                                  || to.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
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
            .sheet(item: $editingFavorite) { fav in
                FavoriteEditSheet(favorite: fav)
                    .environmentObject(store)
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
            purpose     = t.purpose
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
                } else if let saved = FuelType.allCases.first(where: { $0.tankerkoenigKey == raw || $0.storageKey == raw }) {
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
            selectedFuelType = defaultFuelTypeFromKey
            if !defaultConsumptionForCurrentFuel.isEmpty { fuelConsumptionStr = defaultConsumptionForCurrentFuel }
            if !defaultPriceForCurrentFuel.isEmpty       { fuelPriceStr       = defaultPriceForCurrentFuel }
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
            endTime:   fahrzeitEnd > fahrzeitStart ? fahrzeitEnd   : nil,
            purpose: purpose
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

