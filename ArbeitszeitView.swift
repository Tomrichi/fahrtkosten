import SwiftUI

struct ArbeitszeitView: View {
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
    enum ArbeitszeitFilter: String, CaseIterable {
        case tag   = "Tag"
        case woche = "Woche"
        case monat = "Monat"
        case alle  = "Alle"
    }
    @State private var expandedMeals: Set<UUID> = []
    @State private var selectedFilter: ArbeitszeitFilter = .alle
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

    private var filteredTrips: [Trip] {
        let cal = Calendar.current
        let mealDates = Set(filteredMeals.map { cal.startOfDay(for: $0.date) })
        return store.trips.filter { mealDates.contains(cal.startOfDay(for: $0.date)) }
    }

    private var combinedTotal: Double {
        filteredTotal + filteredTrips.reduce(0) { $0 + ($1.km * store.kmRate) }
    }

    private var combinedCountLabel: String {
        let tripCount = filteredTrips.count
        let unit = lm.t("meals.unit")
        let km = filteredTrips.reduce(0) { $0 + $1.km }
        if tripCount > 0 {
            return "\(filteredMeals.count) \(unit)  ·  \(tripCount) Fahrt(en)  ·  \(km.kmFormatted)"
        }
        return "\(filteredMeals.count) \(unit)"
    }

    private var filteredTotal: Double {
        filteredMeals.reduce(0) { $0 + store.adjustedMealAllowance(for: $1) }
    }

    private func tripsForMeal(_ meal: MealEntry) -> [Trip] {
        let cal = Calendar.current
        return store.trips.filter { cal.isDate($0.date, inSameDayAs: meal.date) }
    }

    private func totalAbsenceHours(for meal: MealEntry) -> Double {
        store.totalWorkHours(for: meal)
    }

    func suggestedWorkStart(for date: Date) -> Date? {
        let cal = Calendar.current
        return store.trips
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .compactMap { $0.endTime }.max()
    }

    private var filterLabel: String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        switch selectedFilter {
        case .alle:   return "Spesen"
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            listContent
                .listStyle(.insetGrouped)
                .navigationTitle("Arbeitszeit & Spesen")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                AppLogger.shared.logTap("Arbeitszeit: Neuer Eintrag (Menü)")
                                showAdd = true
                            } label: {
                                Label("Neuer Eintrag", systemImage: "plus")
                            }
                            Divider()
                            Button {
                                AppLogger.shared.logTap("Arbeitszeit: Exportieren")
                                showExport = true
                            } label: {
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
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            AppLogger.shared.logTap("Arbeitszeit: Neuer Eintrag (Plus)")
                            showAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Neuen Arbeitszeiteneintrag hinzufügen")
                    }
                }
                .confirmationDialog("Exportieren", isPresented: $showExport, titleVisibility: .visible) {
                    Button("CSV exportieren") {
                        let content = CSVExportService.generate(
                            store: store, trips: [], meals: filteredMeals,
                            hotels: [], vehicleCosts: [], reiseSpesen: [], privateExpenses: []
                        )
                        let url = CSVExportService.fileURL(content: content, zeitraum: "Verpflegung")
                        shareFile(url)
                    }
                    Button("PDF Vorschau") {
                        let data = PDFExportService.generatePDF(
                            store: store, trips: [], meals: filteredMeals,
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

    // MARK: - List-Inhalt ausgelagert (SwiftUI Type-Checker-Limit)

    @ViewBuilder
    private var listContent: some View {
        List {
            if store.meals.isEmpty {
                emptyState
            } else {
                filterSection
                headerSection
                if filteredMeals.isEmpty {
                    emptyFilterState
                } else {
                    entriesSection
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var emptyState: some View {
        Section {
            Button { showAdd = true } label: {
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "clock.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    Text("Arbeitstag erfassen")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Gesamtarbeitszeit und Verpflegungspauschale erfassen")
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
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
        }
    }

    @ViewBuilder
    private var filterSection: some View {
        Section {
            VStack(spacing: 10) {
                FilterChipBar(selection: $selectedFilter)
                    .padding(.vertical, 2)

                if selectedFilter != .alle {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.system(size: 15, weight: .semibold))
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        Spacer()
                        Button {
                            withOptionalAnimation(.easeInOut(duration: 0.2)) { selectedDate = Date() }
                        } label: {
                            Text("Heute")
                                .font(.caption.bold())
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
    }

    @ViewBuilder
    private var headerSection: some View {
        Section {
            ListHeaderCard(
                icon: "clock.fill",
                color: .blue,
                title: filterLabel,
                countLabel: "\(filteredMeals.count) \(lm.t("meals.unit"))",
                total: filteredTotal
            )
            .listRowBackground(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    @ViewBuilder
    private var emptyFilterState: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
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
    }

    @ViewBuilder
    private var entriesSection: some View {
        Section(filterLabel) {
            ForEach(filteredMeals) { meal in
                ArbeitszeitRow(
                    meal: meal,
                    trips: tripsForMeal(meal),
                    adjusted: store.adjustedMealAllowance(for: meal),
                    totalH: store.totalWorkHours(for: meal),
                    isExpanded: expandedMeals.contains(meal.id),
                    onToggle: {
                        withOptionalAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if expandedMeals.contains(meal.id) {
                                expandedMeals.remove(meal.id)
                            } else {
                                expandedMeals.insert(meal.id)
                            }
                        }
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withOptionalAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if expandedMeals.contains(meal.id) {
                            expandedMeals.remove(meal.id)
                        } else {
                            expandedMeals.insert(meal.id)
                        }
                    }
                }
                .dynamicSwipeActions(
                    onDelete: {
                        AppLogger.shared.logTap("Arbeitszeit gelöscht: \(meal.date.shortDate)")
                        store.deleteMeal(meal.id)
                    },
                    onEdit: { editMeal = meal },
                    onDuplicate: {
                        AppLogger.shared.logTap("Arbeitszeit dupliziert: \(meal.date.shortDate)")
                        store.duplicateMeal(meal)
                    }
                )
                .contextMenu {
                    Button { editMeal = meal } label: {
                        Label(lm.t("action.edit"), systemImage: "pencil")
                    }
                    Button {
                        store.duplicateMeal(meal)
                    } label: {
                        Label("Eintrag duplizieren", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button(role: .destructive) {
                        store.deleteMeal(meal.id)
                    } label: {
                        Label(lm.t("action.delete"), systemImage: "trash")
                    }.tint(.red)
                }
            }
        }
    }

    // MARK: - Helper

    private func shareFile(_ url: URL) {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(controller, animated: true)
        }
    }
}

// MARK: - Kompakte aufklappbare Zeile
struct ArbeitszeitRow: View {
    let meal:       MealEntry
    let trips:      [Trip]
    let adjusted:   Double
    let totalH:     Double
    let isExpanded: Bool
    let onToggle:   () -> Void

    /// Gesamter Zeitbereich: frühstes Start und spätestes Ende aus Meal + allen Fahrten mit Uhrzeiten.
    private var displayRange: (start: Date, end: Date) {
        let timed = trips.filter { $0.startTime != nil && $0.endTime != nil }
        guard !timed.isEmpty else { return (meal.startTime, meal.endTime) }
        let allStarts = timed.compactMap { $0.startTime } + [meal.startTime]
        let allEnds   = timed.compactMap { $0.endTime }   + [meal.endTime]
        return (allStarts.min() ?? meal.startTime, allEnds.max() ?? meal.endTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Kompakte Hauptzeile ────────────────────────────────
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .medium))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.date.shortDate)
                        .font(.system(size: 15, weight: .semibold))

                    HStack(spacing: 4) {
                        Text("\(displayRange.start.timeOnly)–\(displayRange.end.timeOnly)")
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                        if !trips.isEmpty {
                            Image(systemName: "car.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Text(String(format: "%.1fh", totalH) + (trips.isEmpty ? "" : " ges."))
                            .foregroundColor(totalH >= 6 ? .green : totalH >= 3 ? Color.orange : .secondary)
                            .fontWeight(totalH >= 6 ? .semibold : .regular)
                    }
                    .font(.caption)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(adjusted.euroFormatted)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)

                    if !trips.isEmpty {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { if !trips.isEmpty { onToggle() } }

            // ── Aufgeklappter Bereich: Fahrten ────────────────────
            if isExpanded && !trips.isEmpty {
                Divider()
                    .padding(.leading, 48)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(trips) { trip in
                        HStack(spacing: 8) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                                .frame(width: 14)
                            Text("\(trip.from) → \(trip.to)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let st = trip.startTime, let et = trip.endTime {
                                Text("\(st.timeOnly)–\(et.timeOnly)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let dur = trip.fahrzeitText {
                                Text(dur)
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text(String(format: "Gesamt %.1f h", totalH))
                            .font(.caption.bold())
                            .foregroundColor(.green)
                        Text("→ \(adjusted.euroFormatted)")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                    .padding(.top, 2)
                }
                .padding(.leading, 48)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
