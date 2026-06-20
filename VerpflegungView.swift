import SwiftUI

struct VerpflegungView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager
    @State private var showAdd        = false
    @State private var editMeal: MealEntry?
    @State private var showSettings   = false
    @State private var showExport     = false
    @State private var showPDFPreview = false
    @State private var pdfPreviewData: Data? = nil
    @State private var pdfPreviewName = ""

    // ── Zeitraum-Filter ──
    enum MealFilter: String, CaseIterable {
        case tag   = "Tag"
        case woche = "Woche"
        case monat = "Monat"
        case alle  = "Alle"
    }
    @State private var selectedFilter: MealFilter = .alle
    @State private var selectedDate: Date = Date()

    private var filteredMeals: [MealEntry] {
        let cal = Calendar.current
        switch selectedFilter {
        case .alle:
            return store.meals.sorted(by: { $0.date > $1.date })
        case .tag:
            return store.meals
                .filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
                .sorted(by: { $0.date > $1.date })
        case .woche:
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: selectedDate)?.start else {
                return store.meals.sorted(by: { $0.date > $1.date })
            }
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
            return store.meals
                .filter { $0.date >= weekStart && $0.date < weekEnd }
                .sorted(by: { $0.date > $1.date })
        case .monat:
            return store.meals
                .filter { cal.isDate($0.date, equalTo: selectedDate, toGranularity: .month) }
                .sorted(by: { $0.date > $1.date })
        }
    }

    private var filteredTotal: Double {
        filteredMeals.reduce(0) { $0 + $1.allowance(rates: store.mealRates(for: $1.region)) }
    }

    private var filterLabel: String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        switch selectedFilter {
        case .alle:   return lm.t("tab.meals")
        case .tag:
            if cal.isDateInToday(selectedDate) { return "Heute" }
            fmt.dateStyle = .medium; fmt.timeStyle = .none
            return fmt.string(from: selectedDate)
        case .woche:
            guard let interval = cal.dateInterval(of: .weekOfYear, for: selectedDate) else { return "Diese Woche" }
            let end = cal.date(byAdding: .day, value: 6, to: interval.start)!
            fmt.dateFormat = "d. MMM"
            return "\(fmt.string(from: interval.start)) – \(fmt.string(from: end))"
        case .monat:
            fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: selectedDate)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.meals.isEmpty {
                    Section {
                        Button { showAdd = true } label: {
                            VStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.green.opacity(0.12))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 30, weight: .regular))
                                        .foregroundColor(.green)
                                }
                                Text(lm.t("meals.add"))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text(lm.t("meals.add.hint"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 44)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
                    }
                } else {
                    // ── Zeitraum-Filter ──
                    Section {
                        VStack(spacing: 10) {
                            Picker("Zeitraum", selection: $selectedFilter) {
                                ForEach(MealFilter.allCases, id: \.self) { f in
                                    Text(f.rawValue).tag(f)
                                }
                            }
                            .pickerStyle(.segmented)

                            if selectedFilter != .alle {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.green)
                                        .font(.system(size: 15, weight: .regular))
                                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                    Spacer()
                                    Button {
                                        withOptionalAnimation(.easeInOut(duration: 0.2)) { selectedDate = Date() }
                                    } label: {
                                        Text("Heute")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.green.opacity(0.1))
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
                            icon: "fork.knife",
                            color: .green,
                            title: filterLabel,
                            countLabel: "\(filteredMeals.count) \(lm.t("meals.unit"))",
                            total: filteredTotal
                        )
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }

                    // ── Einträge ──
                    if filteredMeals.isEmpty {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary.opacity(0.6))
                                    Text("Keine Einträge im gewählten Zeitraum")
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
                            ForEach(filteredMeals) { meal in
                                MealRow(meal: meal, rates: store.mealRates(for: meal.region))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        AppLogger.shared.logTap("Verpflegung bearbeiten: \(meal.date.shortDate)")
                                        editMeal = meal
                                    }
                                    .dynamicSwipeActions(
                                        onDelete: {
                                            AppLogger.shared.logTap("Verpflegung gelöscht: \(meal.date.shortDate)")
                                            store.deleteMeal(meal.id)
                                        },
                                        onEdit: { editMeal = meal }
                                    )
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(lm.t("tab.meals"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        // Export Button
                        Button {
                            showExport = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Exportieren")
                        // Drei Punkte Menü
                        Menu {
                            Button { showAdd = true } label: {
                                Label("Neuer Eintrag", systemImage: "plus")
                            }
                            Divider()
                            Button { showExport = true } label: {
                                Label("Exportieren", systemImage: "square.and.arrow.up")
                            }
                            Divider()
                            Button { showSettings = true } label: {
                                Label("Einstellungen", systemImage: "gearshape")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog("Exportieren", isPresented: $showExport, titleVisibility: .visible) {
                Button("CSV exportieren") {
                    let mealDates = Set(filteredMeals.map { Calendar.current.startOfDay(for: $0.date) })
                    let relatedTrips = store.trips.filter { mealDates.contains(Calendar.current.startOfDay(for: $0.date)) }
                    let content = CSVExportService.generate(
                        store: store, trips: relatedTrips, meals: filteredMeals,
                        hotels: [], vehicleCosts: [], reiseSpesen: [], privateExpenses: []
                    )
                    let url = CSVExportService.fileURL(content: content, zeitraum: "Verpflegung")
                    shareFile(url)
                }
                Button("PDF Vorschau") {
                    let mealDates = Set(filteredMeals.map { Calendar.current.startOfDay(for: $0.date) })
                    let relatedTrips = store.trips.filter { mealDates.contains(Calendar.current.startOfDay(for: $0.date)) }
                    let data = PDFExportService.generatePDF(
                        store: store, trips: relatedTrips, meals: filteredMeals,
                        hotels: [], vehicleCosts: [], reiseSpesen: [], privateExpenses: [],
                        zeitraum: filterLabel
                    )
                    pdfPreviewData = data
                    pdfPreviewName = "Verpflegung_\(filterLabel).pdf"
                    showPDFPreview = true
                }
                Button("Abbrechen", role: .cancel) {}
            }
            .sheet(isPresented: $showPDFPreview) {
                if let data = pdfPreviewData {
                    PDFPreviewView(pdfData: data, filename: pdfPreviewName)
                }
            }
            .sheet(isPresented: $showSettings) { EinstellungenView() }
            .sheet(isPresented: $showAdd) { MealFormView(mode: .add) }
            .sheet(item: $editMeal) { meal in MealFormView(mode: .edit(meal)) }
        }
    }
    private func shareFile(_ url: URL) {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(controller, animated: true)
        }
    }
}

// MARK: - Meal Row
struct MealRow: View {
    @EnvironmentObject var lm: LocalizationManager

    let meal: MealEntry
    let rates: MealRates

    private var allowance: Double { meal.allowance(rates: rates) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(allowanceColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "fork.knife")
                    .foregroundColor(allowanceColor)
                    .font(.system(size: 17, weight: .regular))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(meal.date.weekdayShortDate)
                        .font(.system(size: 15, weight: .regular))
                    // Region-Badge
                    Text(meal.region.localizedName)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(regionColor)
                        .clipShape(Capsule())
                }
                Text("\(meal.startTime.timeOnly) – \(meal.endTime.timeOnly)  ·  \(String(format: "%.1f", meal.hours)) h")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !meal.note.isEmpty {
                    Text(meal.note).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(allowance.euroFormatted)
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .foregroundColor(allowanceColor)
                HStack(spacing: 4) {
                    if meal.breakfastAmount > 0 {
                        Text("Verpfl. Dritte −\(meal.breakfastAmount.euroFormatted)")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.75))
                            .clipShape(Capsule())
                    }
                    if meal.ownBreakfastAmount > 0 {
                        Text("☕ +\(meal.ownBreakfastAmount.euroFormatted)")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.75))
                            .clipShape(Capsule())
                    }
                    Text(stufeBadge)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(allowanceColor.opacity(0.75))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var allowanceColor: Color {
        switch meal.hours {
        case ..<1:  return Color(.systemGray2)
        case ..<3:  return .iosOrange.opacity(0.7)
        case ..<6:  return .iosOrange
        default:    return .iosGreen
        }
    }

    private var regionColor: Color {
        switch meal.region {
        case .inland:  return .blue
        case .schweiz: return .red
        case .ausland: return .iosIndigo
        }
    }

    private var stufeBadge: String {
        switch meal.hours {
        case ..<1:  return "Keine"
        case ..<3:  return "1–3 h"
        case ..<6:  return "3–6 h"
        default:    return "ab 6 h"
        }
    }
}

// MARK: - Meal Form
enum MealFormMode { case add; case edit(MealEntry) }

struct MealFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager

    let mode: MealFormMode

    @State private var date              = Date()
    @State private var startTime         = Calendar.current.date(bySettingHour: 8,  minute: 0, second: 0, of: Date())!
    @State private var endTime           = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date())!
    @State private var note              = ""
    @State private var region            : TravelRegion = .inland
    @State private var breakfastChecked  = false   // Häkchen: Verpflegung von Dritten gestellt?
    @State private var ownBreakfastStr   = ""       // Eigenes Frühstück (selbst bezahlt)
    @State private var pauseMinutes: Int = 0
    @State private var includeTodaysTrips: Bool = true

    private var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var editingMeal: MealEntry? { if case .edit(let m) = mode { return m }; return nil }

    private var hours: Double { max(0, endTime.timeIntervalSince(startTime) / 3600) }
    private var rates: MealRates { store.mealRates(for: region) }
    /// Betrag aus Einstellungen – wird beim Setzen des Häkchens übernommen
    private var breakfastAmt: Double { breakfastChecked ? store.breakfastFlat : 0 }

    private var ownBreakfastAmt: Double { Double(ownBreakfastStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var currentMeal: MealEntry {
        MealEntry(id: editingMeal?.id ?? UUID(), date: date,
                  startTime: startTime, endTime: endTime, note: note, region: region,
                  breakfastAmount: breakfastAmt, ownBreakfastAmount: ownBreakfastAmt,
                  pauseMinutes: pauseMinutes,
                  excludeTrips: !includeTodaysTrips)
    }
    private var currentAllowance: Double { currentMeal.allowance(rates: rates) }
    private var currentLabel: String { currentMeal.allowanceLabel(rates: rates) }

    var body: some View {
        NavigationStack {
            Form {
                // ── Fahrten dieses Tages (Kontext) ──
                let tripsToday = store.trips.filter {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                }
                if !tripsToday.isEmpty {
                    Section {
                        ForEach(tripsToday.sorted(by: { ($0.startTime ?? $0.date) < ($1.startTime ?? $1.date) })) { trip in
                            HStack(spacing: 10) {
                                Image(systemName: "car.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 13))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(trip.from) → \(trip.to)")
                                        .font(.system(size: 13, weight: .regular))
                                    if let st = trip.startTime, let et = trip.endTime {
                                        Text("\(st.timeOnly) – \(et.timeOnly)  ·  \(trip.fahrzeitText ?? "")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else if let fz = trip.fahrzeitText {
                                        Text(fz).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        // Hinweis wenn Startzeit von Fahrt übernommen
                        if let lastEnd = tripsToday.compactMap({ $0.endTime }).max(),
                           !isEdit {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Arbeitszeit beginnt ab \(lastEnd.timeOnly) (Fahrtenende)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Toggle(isOn: $includeTodaysTrips) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.forwardslash.minus")
                                    .foregroundColor(includeTodaysTrips ? .blue : .secondary)
                                    .font(.caption)
                                Text("Fahrzeit in Abwesenheit einrechnen")
                                    .font(.caption)
                                    .foregroundColor(includeTodaysTrips ? .primary : .secondary)
                            }
                        }
                        .tint(.blue)
                    } header: {
                        Label("Fahrten heute", systemImage: "car.fill")
                    }
                }

                // ── Region ──
                Section(lm.t("meals.region")) {
                    Picker(lm.t("common.region"), selection: $region) {
                        ForEach(TravelRegion.allCases, id: \.self) { r in
                            Label(r.localizedName, systemImage: r.icon).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                // ── Arbeitszeit ──
                Section("Arbeitszeit") {
                    DatePicker(lm.t("common.date"),   selection: $date,      displayedComponents: .date)
                    DatePicker(lm.t("meals.begin"),  selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker(lm.t("meals.end"),    selection: $endTime,   displayedComponents: .hourAndMinute)
                    HStack {
                        Label("Pause (Minuten)", systemImage: "pause.circle.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Stepper("\(pauseMinutes) min", value: $pauseMinutes, in: 0...120, step: 15)
                            .labelsHidden()
                        Text("\(pauseMinutes) min")
                            .foregroundColor(.secondary)
                            .frame(width: 55, alignment: .trailing)
                    }
                    HStack {
                        Label(lm.t("common.note"), systemImage: "note.text")
                        Spacer()
                        TextField(lm.t("common.optional"), text: $note).multilineTextAlignment(.trailing)
                    }
                }

                // ── Frühstück ──
                Section {
                    Toggle(isOn: $breakfastChecked) {
                        HStack(spacing: 8) {
                            Label("Verpflegung von Dritten bezahlt", systemImage: "cup.and.saucer.fill")
                            if breakfastChecked {
                                Text("−\(store.breakfastFlat.euroFormatted)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .tint(.red)

                    HStack {
                        Label("Eigenes Frühstück", systemImage: "sunrise.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField("0,00", text: $ownBreakfastStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("€").foregroundColor(.secondary)
                    }
                } header: {
                    Text("Frühstück")
                } footer: {
                    Text("Verpflegung von Dritten: Pauschale (\(store.breakfastFlat.euroFormatted)) wird abgezogen. Eigenes Frühstück: selbst bezahlter Betrag wird zur Erstattung addiert.")
                        .font(.caption)
                }

                // ── Ergebnis ──
                Section(lm.t("meals.result")) {
                    // Fahrzeit + Arbeitszeit kombiniert anzeigen
                    let tripsForResult = includeTodaysTrips ? store.trips.filter {
                        Calendar.current.isDate($0.date, inSameDayAs: date)
                    } : []
                    let earliestTripStart = tripsForResult.compactMap { $0.startTime }.min()
                    let totalHours: Double = {
                        if let start = earliestTripStart {
                            return max(0, endTime.timeIntervalSince(start) / 3600.0)
                        }
                        return hours
                    }()

                    VStack(alignment: .leading, spacing: 6) {
                        if let tripStart = earliestTripStart {
                            HStack {
                                Image(systemName: "car.fill").foregroundColor(.blue).font(.caption)
                                Text("Abfahrt \(tripStart.timeOnly)")
                                    .font(.caption).foregroundColor(.secondary)
                                Text("→")
                                    .font(.caption).foregroundColor(.secondary)
                                Image(systemName: "briefcase.fill").foregroundColor(.green).font(.caption)
                                Text("Arbeitsende \(endTime.timeOnly)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Gesamtarbeitszeit")
                                Spacer()
                                Text(String(format: "%.1f Stunden", totalHours))
                                    .foregroundColor(.blue).fontWeight(.regular)
                            }
                            .font(.subheadline)
                        } else {
                            HStack {
                                Text("Arbeitszeit")
                                Spacer()
                                Text(String(format: "%.1f Stunden", hours))
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(progressColor)
                                    .frame(width: geo.size.width * min(1, totalHours / 12), height: 8)
                                    .animation(.spring(response: 0.4), value: totalHours)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.vertical, 4)

                    // Pauschale basierend auf Gesamtarbeitszeit (oder nur Arbeitszeit wenn Toggle aus)
                    let effectiveMeal = MealEntry(
                        date: date,
                        startTime: earliestTripStart ?? startTime,
                        endTime: endTime, note: note, region: region,
                        breakfastAmount: breakfastAmt,
                        ownBreakfastAmount: ownBreakfastAmt,
                        pauseMinutes: pauseMinutes,
                        excludeTrips: !includeTodaysTrips
                    )
                    let effectiveAllowance = effectiveMeal.allowance(rates: rates)
                    LabeledRow(label: lm.t("meals.level"),
                               value: effectiveMeal.allowanceLabel(rates: rates),
                               valueColor: progressColor)

                    // Verpflegungspauschale
                    HStack {
                        Text("Verpflegungspauschale").foregroundColor(.secondary)
                        Spacer()
                        Text(effectiveMeal.mealAllowance(rates: rates).euroFormatted)
                            .font(.system(size: 15, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    // Verpflegung von Dritten (nur anzeigen wenn Häkchen gesetzt)
                    if breakfastChecked && store.breakfastFlat > 0 {
                        HStack {
                            Label("Verpflegung von Dritten", systemImage: "cup.and.saucer.fill")
                                .foregroundColor(.red)
                            Spacer()
                            Text("−\(store.breakfastFlat.euroFormatted)")
                                .font(.system(size: 15, weight: .regular, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    }

                    // Eigenes Frühstück (nur anzeigen wenn Betrag > 0)
                    if ownBreakfastAmt > 0 {
                        HStack {
                            Label("Eigenes Frühstück", systemImage: "sunrise.fill")
                                .foregroundColor(.orange)
                            Spacer()
                            Text("+\(ownBreakfastAmt.euroFormatted)")
                                .font(.system(size: 15, weight: .regular, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                    }

                    // Netto Verpflegung
                    HStack {
                        Text("Netto Verpflegung").foregroundColor(.secondary)
                        Spacer()
                        Text(effectiveAllowance.euroFormatted)
                            .font(.system(size: 15, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    // Gesamt
                    HStack {
                        Text(lm.t("meals.allowance")).fontWeight(.regular)
                        Spacer()
                        Text(effectiveAllowance.euroFormatted)
                            .font(.system(size: 18, weight: .regular, design: .monospaced))
                            .foregroundColor(.iosGreen)
                    }
                }

                // ── Info-Tabelle ──
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        stufenRow("< 1 h",   "0,00 €")
                        stufenRow("1 – 3 h", rates.rate1to3.euroFormatted)
                        stufenRow("3 – 6 h", rates.rate3to6.euroFormatted)
                        stufenRow("ab 6 h",  rates.rate6plus.euroFormatted)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                } header: {
                    Text("\(lm.t("meals.allowance")) (\(region.localizedName))")
                }
            }
            .navigationTitle(isEdit ? lm.t("meals.form.edit") : lm.t("meals.form.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lm.t("action.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? lm.t("action.save") : lm.t("action.add")) { save() }.fontWeight(.regular)
                }
            }
            .onAppear { prefill() }
        }
    }

    @ViewBuilder
    private func stufenRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).frame(width: 70, alignment: .leading)
            Text(value)
        }
    }

    private var progressColor: Color {
        switch hours {
        case ..<1:  return Color(.systemGray)
        case ..<3:  return .iosOrange.opacity(0.7)
        case ..<6:  return .iosOrange
        default:    return .iosGreen
        }
    }

    private func prefill() {
        if let m = editingMeal {
            date                = m.date
            startTime           = m.startTime
            endTime             = m.endTime
            note                = m.note
            region              = m.region
            breakfastChecked    = m.breakfastAmount > 0
            pauseMinutes        = m.pauseMinutes
            includeTodaysTrips  = !m.excludeTrips
            if m.ownBreakfastAmount > 0 {
                ownBreakfastStr = String(format: "%.2f", m.ownBreakfastAmount).replacingOccurrences(of: ".", with: ",")
            }
        } else {
            // Neuer Eintrag: Startzeit = Endzeit der letzten Fahrt des Tages (falls vorhanden)
            let cal = Calendar.current
            let today = date
            let tripsToday = store.trips.filter { cal.isDate($0.date, inSameDayAs: today) }
            if let lastTripEnd = tripsToday.compactMap({ $0.endTime }).max() {
                startTime = lastTripEnd
                // Endzeit = letzte Fahrt Ende + 8h (Richtwert)
                endTime = cal.date(byAdding: .hour, value: 8, to: lastTripEnd) ?? endTime
            }
        }
    }

    private func save() {
        let meal = MealEntry(id: editingMeal?.id ?? UUID(), date: date,
                             startTime: startTime, endTime: endTime,
                             note: note, region: region,
                             breakfastAmount: breakfastAmt,
                             ownBreakfastAmount: ownBreakfastAmt,
                             pauseMinutes: pauseMinutes,
                             excludeTrips: !includeTodaysTrips)
        if isEdit {
            store.updateMeal(meal)
            AppLogger.shared.log("Verpflegung aktualisiert: \(meal.date.shortDate), \(meal.startTime.timeOnly)–\(meal.endTime.timeOnly)", level: .store)
        } else {
            store.addMeal(meal)
            AppLogger.shared.log("Verpflegung gespeichert: \(meal.date.shortDate), \(meal.startTime.timeOnly)–\(meal.endTime.timeOnly)", level: .store)
        }
        dismiss()
    }
}
