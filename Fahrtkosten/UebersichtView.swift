import SwiftUI

// MARK: - PDF Preview Item (für sheet(item:))
struct PDFPreviewItem: Identifiable {
    let id = UUID()
    let data: Data
    let filename: String
}

// MARK: - Übersicht Tab Enum
enum UebersichtTab: String, CaseIterable, Identifiable {
    case dashboard = "Übersicht"
    case statistik = "Statistik"
    var id: String { rawValue }
    var label: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "list.bullet.rectangle.portrait.fill"
        case .statistik: return "chart.bar.fill"
        }
    }
}

// MARK: - Zeit-Filter Enum
enum ZeitFilter: String, CaseIterable {
    case woche  = "Woche"
    case monat  = "Monat"
    case jahr   = "Jahr"
}

// MARK: - Übersicht (Dashboard)
struct UebersichtView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager
    @State private var showSettings    = false
    @AppStorage("uebersicht.tab") private var uebersichtTab: UebersichtTab = .dashboard
    @AppStorage("uebersicht.zeitFilter") private var zeitFilter: ZeitFilter = .monat
    @State private var showExport         = false
    @State private var pdfPreviewItem    : PDFPreviewItem? = nil
    @State private var showPDFDatePicker = false
    @State private var pdfExportDate     = Date()
    @State private var expandTrips     = false
    @State private var expandMeals     = false
    @State private var expandHotels    = false
    @State private var expandFuel      = false
    @State private var expandVerbrauch = false
    @State private var expandKFZ       = false
    @State private var expandVehicle   = false
    @State private var expandReisespesen        = false
    @State private var expandVerpflegungAusgaben = false
    @State private var expandPrivate             = false
    @State private var showAddVerpflegungSpese  = false
    @State private var editVerpflegungSpese: ReiseSpese?
    @State private var showAddPrivateExpense    = false
    @State private var editPrivateExpense: PrivateExpense?

    var body: some View {
        NavigationStack {
            Group {
                if store.trips.isEmpty && store.meals.isEmpty && store.hotels.isEmpty && store.reiseSpesen.isEmpty && uebersichtTab == .dashboard {
                    emptyState
                } else {
                    switch uebersichtTab {
                    case .dashboard:  dashboard
                    case .statistik:  StatistikView().environmentObject(store)
                    }
                }
            }
            .navigationTitle(lm.t("tab.overview"))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $uebersichtTab) {
                        ForEach(UebersichtTab.allCases) { tab in
                            Label(tab.label, systemImage: tab.icon).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            let content = CSVExportService.generate(
                                store: store,
                                trips: filteredTrips,
                                meals: filteredMeals,
                                hotels: filteredHotels,
                                vehicleCosts: filteredVehicleCosts,
                                reiseSpesen: filteredReiseSpesen,
                                privateExpenses: filteredPrivateExpenses
                            )
                            let url = CSVExportService.fileURL(content: content, zeitraum: zeitFilter.rawValue)
                            shareFile(url)
                        } label: {
                            Label("CSV exportieren", systemImage: "tablecells")
                        }
                        Button {
                            pdfExportDate = Date()
                            showPDFDatePicker = true
                        } label: {
                            Label("PDF Vorschau & Export", systemImage: "doc.richtext.fill")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                EinstellungenView()
            }
            .sheet(isPresented: $showAddVerpflegungSpese) {
                KFZKostenFormView(mode: .add, defaultKategorie: .verpflegung)
                    .environmentObject(store)
            }
            .sheet(item: $editVerpflegungSpese) { spese in
                KFZKostenFormView(mode: .edit(spese))
                    .environmentObject(store)
            }
            .sheet(isPresented: $showAddPrivateExpense) {
                PrivateExpenseFormView(mode: .add)
                    .environmentObject(store)
            }
            .sheet(item: $editPrivateExpense) { item in
                PrivateExpenseFormView(mode: .edit(item))
                    .environmentObject(store)
            }
            .sheet(item: $pdfPreviewItem) { item in
                PDFPreviewView(pdfData: item.data, filename: item.filename)
            }
            .sheet(isPresented: $showPDFDatePicker) {
                PDFExportDatePickerSheet(
                    selectedDate: $pdfExportDate,
                    zeitFilter: zeitFilter
                ) { exportDate in
                    let exportedTrips = store.trips.filter { inPeriodOf($0.date, reference: exportDate) }
                    let exportedMeals = store.meals.filter { inPeriodOf($0.date, reference: exportDate) }
                    let exportedHotels = store.hotels.filter { inPeriodOf($0.date, reference: exportDate) }
                    let exportedVehicle = store.vehicleCosts.filter { inPeriodOf($0.date, reference: exportDate) }
                    let exportedSpesen = store.reiseSpesen.filter { inPeriodOf($0.date, reference: exportDate) }
                    let exportedPrivate = store.privateExpenses.filter { inPeriodOf($0.date, reference: exportDate) }

                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "de_DE")
                    switch zeitFilter {
                    case .monat: formatter.dateFormat = "MMMM_yyyy"
                    case .jahr:  formatter.dateFormat = "yyyy"
                    case .woche: formatter.dateFormat = "'KW'ww_yyyy"
                    }
                    let zeitraumLabel = formatter.string(from: exportDate)

                    let data = PDFExportService.generatePDF(
                        store: store,
                        trips: exportedTrips,
                        meals: exportedMeals,
                        hotels: exportedHotels,
                        vehicleCosts: exportedVehicle,
                        reiseSpesen: exportedSpesen,
                        privateExpenses: exportedPrivate,
                        zeitraum: zeitraumLabel.replacingOccurrences(of: "_", with: " ")
                    )

                    let fileFormatter = DateFormatter()
                    fileFormatter.dateFormat = "yyyy-MM-dd"
                    let name = "Fahrtkosten_\(zeitraumLabel)_\(fileFormatter.string(from: Date())).pdf"
                    pdfPreviewItem = PDFPreviewItem(data: data, filename: name)
                }
            }
        }
    }

    // MARK: - Filtered Data
    private var filteredTrips: [Trip] { store.trips.filter { inPeriod($0.date) } }
    private var filteredMeals: [MealEntry] { store.meals.filter { inPeriod($0.date) } }
    private var filteredHotels: [HotelEntry] { store.hotels.filter { inPeriod($0.date) } }
    private var filteredReiseSpesen: [ReiseSpese] { store.reiseSpesen.filter { inPeriod($0.date) } }
    private var filteredVerpflegungAusgaben: [ReiseSpese] {
        store.reiseSpesen.filter { inPeriod($0.date) && $0.kategorie == .verpflegung }
    }
    private var filteredVehicleCosts: [VehicleCost]    { store.vehicleCosts.filter { inPeriod($0.date) } }
    private var filteredPrivateExpenses: [PrivateExpense] { store.privateExpenses.filter { inPeriod($0.date) } }

    private func inPeriod(_ date: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch zeitFilter {
        case .woche:  return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .monat:  return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .jahr:   return cal.isDate(date, equalTo: now, toGranularity: .year)
        }
    }

    private func inPeriodOf(_ date: Date, reference: Date) -> Bool {
        let cal = Calendar.current
        switch zeitFilter {
        case .woche:  return cal.isDate(date, equalTo: reference, toGranularity: .weekOfYear)
        case .monat:  return cal.isDate(date, equalTo: reference, toGranularity: .month)
        case .jahr:   return cal.isDate(date, equalTo: reference, toGranularity: .year)
        }
    }

    private var filteredTotal: Double {
        let tripTotal   = filteredTrips.reduce(0)  { $0 + ($1.km * store.kmRate) }
        let mealTotal   = filteredMeals.reduce(0)  { acc, m in acc + m.allowance(rates: store.mealRates(for: m.region)) }
        let hotelTotal  = filteredHotels.reduce(0) { $0 + $1.amount(flat: store.hotelFlat) }
        return tripTotal + mealTotal + hotelTotal
    }

    private var heroFuelCost: Double {
        filteredTrips.compactMap { $0.fuelCost }.reduce(0, +)
    }
    private var heroReiseSpesenTotal: Double {
        filteredReiseSpesen.reduce(0) { $0 + $1.amount }
    }
    private var heroVehicleTotal: Double {
        filteredVehicleCosts.reduce(0) { $0 + $1.amount }
    }
    private var heroPrivateTotal: Double {
        filteredPrivateExpenses.reduce(0) { $0 + $1.amount }
    }

    // CSV + PDF Export → CSVExportService / PDFExportService in ExportServices.swift

    // MARK: - Share Helper
    private func shareFile(_ url: URL) {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(controller, animated: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.25))
            Text(lm.t("overview.empty.title"))
                .font(.title2.bold())
            Text(lm.t("overview.empty.subtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Dashboard
    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 12) {

                // ── Zeitraum-Filter ──
                Picker("Zeitraum", selection: $zeitFilter) {
                    ForEach(ZeitFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 2)

                // ── Hero-Kachel: Gesamterstattung ──
                HeroTotalCard(
                    total: filteredTotal,
                    tripCount: filteredTrips.count,
                    mealCount: filteredMeals.count,
                    hotelCount: filteredHotels.count,
                    fuelCost: heroFuelCost,
                    reiseSpesenTotal: heroReiseSpesenTotal,
                    vehicleTotal: heroVehicleTotal,
                    privateTotal: heroPrivateTotal
                )

                // ── Aufklappbare Kacheln ──
                let tripAmount     = filteredTrips.reduce(0.0)          { $0 + ($1.km * store.kmRate) }
                let mealAmount     = filteredMeals.reduce(0.0)          { acc, m in acc + m.allowance(rates: store.mealRates(for: m.region)) }
                let hotelAmount    = filteredHotels.reduce(0.0)         { $0 + $1.amount(flat: store.hotelFlat) }
                let vehicleAmount  = filteredVehicleCosts.reduce(0.0)    { $0 + $1.amount }
                let privateAmount  = filteredPrivateExpenses.reduce(0.0) { $0 + $1.amount }

                // Fahrten
                expandableCard(
                    icon: "car.fill", color: Color(.systemGray3),
                    label: lm.t("tab.trips"),
                    amount: tripAmount,
                    detail: filteredTrips.count == 1 ? "1 Eintrag" : "\(filteredTrips.count) Einträge",
                    isExpanded: $expandTrips
                ) {
                    ForEach(filteredTrips.sorted(by: { $0.date > $1.date })) { trip in
                        expandRow(
                            icon: "car.fill", color: Color(.systemGray3),
                            title: "\(trip.from) → \(trip.to)",
                            subtitle: "\(trip.date.shortDateShort)  ·  \(trip.km.kmFormatted)",
                            amount: (trip.km * store.kmRate).euroFormatted,
                            amountColor: .iosGreen
                        )
                    }
                }

                // Verpflegung
                expandableCard(
                    icon: "fork.knife", color: .green,
                    label: lm.t("tab.meals"),
                    amount: mealAmount,
                    detail: filteredMeals.count == 1 ? "1 Eintrag" : "\(filteredMeals.count) Einträge",
                    isExpanded: $expandMeals
                ) {
                    ForEach(filteredMeals.sorted(by: { $0.date > $1.date })) { meal in
                        let a = meal.allowance(rates: store.mealRates(for: meal.region))
                        expandRow(
                            icon: "fork.knife", color: .green,
                            title: meal.date.weekdayShortDate,
                            subtitle: "\(meal.startTime.timeOnly) – \(meal.endTime.timeOnly)  ·  \(String(format: "%.1f", meal.hours)) h",
                            amount: a.euroFormatted,
                            amountColor: a > 0 ? .iosGreen : .secondary
                        )
                    }
                }

                // Verpflegungssaldo (Pauschale vs. tatsächliche Ausgaben)
                if !filteredMeals.isEmpty || !filteredVerpflegungAusgaben.isEmpty {
                    let ausgaben = filteredVerpflegungAusgaben.reduce(0.0) { $0 + $1.amount }
                    let saldo = mealAmount - ausgaben
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.brown)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Verpflegung Saldo")
                                    .font(.system(size: 15, weight: .semibold))
                                HStack(spacing: 6) {
                                    Text("Pauschale \(mealAmount.euroFormatted)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text("·")
                                        .foregroundColor(.secondary)
                                    Text("Ausgaben \(ausgaben.euroFormatted)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(saldo >= 0 ? "+\(saldo.euroFormatted)" : saldo.euroFormatted)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(saldo >= 0 ? .iosGreen : .red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                }

                // Übernachtungen
                expandableCard(
                    icon: "bed.double.fill", color: .iosPurple,
                    label: lm.t("overview.accommodation.short"),
                    amount: hotelAmount,
                    detail: filteredHotels.count == 1 ? "1 Eintrag" : "\(filteredHotels.count) Einträge",
                    isExpanded: $expandHotels
                ) {
                    ForEach(filteredHotels.sorted(by: { $0.date > $1.date })) { hotel in
                        let desc = [hotel.city, hotel.hotelName].filter { !$0.isEmpty }.joined(separator: " · ")
                        let nightsStr = hotel.numberOfNights == 1 ? "1 Nacht" : "\(hotel.numberOfNights) Nächte"
                        let subtitle = [desc.isEmpty ? nil : desc, nightsStr]
                            .compactMap { $0 }.joined(separator: "  ·  ")
                        expandRow(
                            icon: "bed.double.fill", color: .iosPurple,
                            title: hotel.date.shortDate,
                            subtitle: subtitle,
                            amount: hotel.amount(flat: store.hotelFlat).euroFormatted,
                            amountColor: .iosPurple
                        )
                    }
                }

                // ── Trennbereich: Ausgaben ──
                if !filteredReiseSpesen.isEmpty || !filteredVehicleCosts.isEmpty || !filteredPrivateExpenses.isEmpty || filteredTrips.contains(where: { $0.fuelCost != nil }) {

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ausgaben")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(.label).opacity(0.55))
                                .textCase(.uppercase)
                            Text("nicht erstattungsfähig")
                                .font(.system(size: 11))
                                .foregroundColor(Color(.label).opacity(0.4))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                }

                // Kraftstoff / Strom (manuelle Tankeinträge aus Reisespesen)
                let tankEintraege = filteredReiseSpesen.filter { $0.kategorie == .benzin || $0.kategorie == .strom }
                let tankTotal     = tankEintraege.reduce(0.0) { $0 + $1.amount }
                if !tankEintraege.isEmpty {
                    expandableCard(
                        icon: "fuelpump.fill", color: .orange,
                        label: "Kraftstoff / Strom",
                        amount: tankTotal,
                        detail: "\(tankEintraege.count) Einträge",
                        isExpanded: $expandFuel
                    ) {
                        ForEach(tankEintraege.sorted(by: { $0.date > $1.date })) { spese in
                            expandRow(
                                icon: spese.kategorie == .strom ? "bolt.fill" : "fuelpump.fill",
                                color: .orange,
                                title: spese.title.isEmpty ? spese.kategorie.localizedName : spese.title,
                                subtitle: spese.date.shortDateShort,
                                amount: spese.amount.euroFormatted,
                                amountColor: .orange
                            )
                        }
                    }
                }

                // Kosten gefahrener km
                if filteredTrips.contains(where: { $0.fuelCost != nil }) {
                    expandableCard(
                        icon: "gauge.with.needle", color: .iosTeal,
                        label: "Kosten gefahrener km",
                        amount: filteredTrips.compactMap { $0.fuelCost }.reduce(0, +),
                        detail: filteredTrips.filter { $0.fuelCost != nil }.reduce(0.0) { $0 + $1.km }.kmFormatted,
                        isExpanded: $expandVerbrauch
                    ) {
                        verbrauchRows
                    }
                }


                // Verpflegungsausgaben (tatsächliche Essenausgaben)
                let verpflegungAusgabenTotal = filteredVerpflegungAusgaben.reduce(0.0) { $0 + $1.amount }
                expandableCard(
                    icon: "fork.knife.circle.fill", color: .brown,
                    label: "Verpflegungsausgaben",
                    amount: verpflegungAusgabenTotal,
                    detail: filteredVerpflegungAusgaben.isEmpty ? "Keine Einträge" : (filteredVerpflegungAusgaben.count == 1 ? "1 Eintrag" : "\(filteredVerpflegungAusgaben.count) Einträge"),
                    isExpanded: $expandVerpflegungAusgaben,
                    onAdd: { showAddVerpflegungSpese = true }
                ) {
                    ForEach(filteredVerpflegungAusgaben.sorted(by: { $0.date > $1.date })) { spese in
                        expandRow(
                            icon: "fork.knife.circle.fill", color: .brown,
                            title: spese.title.isEmpty ? "Verpflegung" : spese.title,
                            subtitle: spese.date.shortDateShort,
                            amount: spese.amount.euroFormatted,
                            amountColor: .brown
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { editVerpflegungSpese = spese }
                        .contextMenu {
                            Button { editVerpflegungSpese = spese } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }
                            Button(role: .destructive) { store.deleteReiseSpese(spese.id) } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }

                // Reisespesen ohne Kraftstoff
                let reisespesenOhneTank = filteredReiseSpesen.filter {
                    $0.kategorie == .werkstatt || $0.kategorie == .leasing ||
                    $0.kategorie == .vignetteMaut || $0.kategorie == .kfzSteuer ||
                    $0.kategorie == .kfzVersicherung
                }
                let reisespesenOhneTankTotal = reisespesenOhneTank.reduce(0.0) { $0 + $1.amount }
                if !reisespesenOhneTank.isEmpty {
                    expandableCard(
                        icon: "wrench.and.screwdriver.fill", color: .iosOrange,
                        label: "Reisespesen / KFZ",
                        amount: reisespesenOhneTankTotal,
                        detail: "\(reisespesenOhneTank.count) Einträge",
                        isExpanded: $expandReisespesen
                    ) {
                        ForEach(reisespesenOhneTank.sorted(by: { $0.date > $1.date })) { spese in
                            expandRow(
                                icon: spese.kategorie.icon, color: .iosOrange,
                                title: spese.title.isEmpty ? spese.kategorie.localizedName : spese.title,
                                subtitle: "\(spese.date.shortDateShort)  ·  \(spese.kategorie.localizedName)",
                                amount: spese.amount.euroFormatted,
                                amountColor: .iosOrange
                            )
                        }
                    }
                }

                // Fahrzeugkosten (inkl. Fahrzeugwäsche)
                if !filteredVehicleCosts.isEmpty {
                    expandableCard(
                        icon: "sparkles", color: Color.cyan,
                        label: "Fahrzeugkosten",
                        amount: vehicleAmount,
                        detail: "\(filteredVehicleCosts.count) Einträge",
                        isExpanded: $expandVehicle
                    ) {
                        ForEach(filteredVehicleCosts.sorted(by: { $0.date > $1.date })) { v in
                            expandRow(
                                icon: v.category.icon, color: .cyan,
                                title: v.title.isEmpty ? v.category.localizedName : v.title,
                                subtitle: "\(v.date.shortDateShort)  ·  \(v.category.localizedName)",
                                amount: v.amount.euroFormatted,
                                amountColor: .cyan
                            )
                        }
                    }
                }

                // Private Ausgaben
                expandableCard(
                    icon: "person.fill", color: Color.pink,
                    label: "Private Ausgaben",
                    amount: privateAmount,
                    detail: filteredPrivateExpenses.isEmpty ? "Keine Einträge" : "\(filteredPrivateExpenses.count) Einträge",
                    isExpanded: $expandPrivate,
                    onAdd: { showAddPrivateExpense = true }
                ) {
                    ForEach(filteredPrivateExpenses.sorted(by: { $0.date > $1.date })) { p in
                        expandRow(
                            icon: "person.fill", color: .pink,
                            title: p.title.isEmpty ? "Ausgabe" : p.title,
                            subtitle: p.date.shortDateShort,
                            amount: p.amount.euroFormatted,
                            amountColor: .pink
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { editPrivateExpense = p }
                        .contextMenu {
                            Button { editPrivateExpense = p } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }
                            Button(role: .destructive) { store.deletePrivateExpense(p.id) } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }

                // ── Gesamtausgaben-Kachel (am Ende der Ausgaben) ──
                let gesamtAusgabenUnten = heroReiseSpesenTotal + heroVehicleTotal + heroPrivateTotal
                if gesamtAusgabenUnten > 0 {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Gesamtausgaben")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("nicht erstattungsfähig")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        Text(gesamtAusgabenUnten.euroFormatted)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var verbrauchRows: some View {
        ForEach(filteredTrips.filter { $0.fuelCost != nil }.sorted(by: { $0.date > $1.date })) { trip in
            verbrauchRow(trip: trip)
        }
    }

    private func verbrauchRow(trip: Trip) -> some View {
        let isElektro = trip.fuelTypeRaw == "elektro"
        let isHybrid  = trip.fuelTypeRaw?.hasPrefix("hybrid|") == true
        let icon      = isElektro ? "bolt.fill" : isHybrid ? "bolt.car.fill" : "fuelpump.fill"
        let cons      = trip.fuelConsumption ?? 0
        let unit      = isElektro ? "kWh" : "L"
        let consStr   = cons > 0 ? String(format: "%.1f \(unit)/100km", cons).replacingOccurrences(of: ".", with: ",") : ""
        let subtitle  = consStr.isEmpty
            ? "\(trip.date.shortDateShort)  ·  \(trip.km.kmFormatted)"
            : "\(trip.date.shortDateShort)  ·  \(trip.km.kmFormatted)  ·  \(consStr)"
        return expandRow(
            icon: icon, color: .iosTeal,
            title: "\(trip.from) → \(trip.to)",
            subtitle: subtitle,
            amount: (trip.fuelCost ?? 0).euroFormatted,
            amountColor: .iosTeal
        )
    }

    @ViewBuilder
    private func ausgabenZeile(icon: String, color: Color, label: String, amount: Double) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            Spacer()
            Text(amount.euroFormatted)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        Divider().padding(.leading, 58)
    }

    // MARK: - Expandable Card

    @ViewBuilder
    private func expandableCard<Content: View>(
        icon: String, color: Color,
        label: String, amount: Double, detail: String,
        isExpanded: Binding<Bool>,
        badge: String? = nil,
        onAdd: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    withOptionalAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.wrappedValue.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(color.opacity(0.12))
                                .frame(width: 42, height: 42)
                            Image(systemName: icon)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(label)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                if let badge {
                                    Text(badge)
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(badge == "Ausgabe" ? Color.orange.opacity(0.75) : Color.secondary.opacity(0.6))
                                        .clipShape(Capsule())
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                            }
                            .lineLimit(1)
                            Text(amount.euroFormatted)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(color)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if isExpanded.wrappedValue {
                Divider().padding(.horizontal, 14)
                content()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func expandRow(icon: String, color: Color, title: String, subtitle: String, amount: String, amountColor: Color) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(amount)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundColor(amountColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            Divider().padding(.leading, 56)
        }
    }
}

