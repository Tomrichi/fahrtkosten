import SwiftUI

// MARK: - Suchergebnis-Typen

enum SearchResultKind {
    case trip(Trip)
    case meal(MealEntry)
    case hotel(HotelEntry)
    case vehicleCost(VehicleCost)
    case reiseSpese(ReiseSpese)
}

struct SearchResult: Identifiable {
    let id = UUID()
    let kind: SearchResultKind
    let date: Date
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let category: String
}

// MARK: - SearchView

struct SearchView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager

    @State private var searchText = ""
    @State private var selectedDate: Date? = nil
    @State private var showDatePicker = false
    @State private var editTrip: Trip? = nil
    @State private var editMeal: MealEntry? = nil
    @State private var editHotel: HotelEntry? = nil

    // Punkt 1: Bereichsfilter
    @State private var showRangeFilter = false
    @State private var minKm: Double = 0
    @State private var maxKm: Double = 0      // 0 = kein Maximum
    @State private var minAmount: Double = 0
    @State private var maxAmount: Double = 0  // 0 = kein Maximum

    // Punkt 5: Export
    @State private var showExportPreview = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    // MARK: - Bereichsfilter aktiv?
    private var hasRangeFilter: Bool {
        minKm > 0 || maxKm > 0 || minAmount > 0 || maxAmount > 0
    }

    // MARK: - Suchergebnisse berechnen

    private var results: [SearchResult] {
        let query  = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let hasText = !query.isEmpty
        let hasDate = selectedDate != nil

        guard hasText || hasDate || hasRangeFilter else { return [] }

        var out: [SearchResult] = []

        // ── Fahrten ──
        for trip in store.trips {
            if let d = selectedDate {
                guard Calendar.current.isDate(trip.date, inSameDayAs: d) else { continue }
            }
            if hasText {
                let hay = "\(trip.from) \(trip.to) \(trip.note) \(trip.date.shortDate)".lowercased()
                guard hay.contains(query) else { continue }
            }
            if minKm > 0 && trip.km < minKm { continue }
            if maxKm > 0 && trip.km > maxKm { continue }
            let km = String(format: "%.0f km", trip.km)
            out.append(SearchResult(
                kind: .trip(trip),
                date: trip.date,
                title: "\(trip.from) → \(trip.to)",
                subtitle: "\(trip.date.shortDate)  ·  \(km)\(trip.note.isEmpty ? "" : "  ·  \(trip.note)")",
                icon: "car.fill",
                iconColor: .blue,
                category: "Fahrten"
            ))
        }

        // ── Arbeitszeit / Mahlzeiten ──
        for meal in store.meals {
            if let d = selectedDate {
                guard Calendar.current.isDate(meal.date, inSameDayAs: d) else { continue }
            }
            if hasText {
                let hay = "\(meal.note) \(meal.region.rawValue) \(meal.date.shortDate)".lowercased()
                guard hay.contains(query) else { continue }
            }
            let hours = String(format: "%.1f h", meal.hours)
            out.append(SearchResult(
                kind: .meal(meal),
                date: meal.date,
                title: meal.note.isEmpty ? "Arbeitstag" : meal.note,
                subtitle: "\(meal.date.shortDate)  ·  \(hours)  ·  \(meal.region.rawValue)",
                icon: "clock.fill",
                iconColor: .orange,
                category: "Arbeitszeit"
            ))
        }

        // ── Übernachtungen ──
        for hotel in store.hotels {
            if let d = selectedDate {
                guard Calendar.current.isDate(hotel.date, inSameDayAs: d) else { continue }
            }
            if hasText {
                let hay = "\(hotel.city) \(hotel.hotelName) \(hotel.date.shortDate)".lowercased()
                guard hay.contains(query) else { continue }
            }
            let amount = hotel.amount(flat: store.hotelFlat)
            if minAmount > 0 && amount < minAmount { continue }
            if maxAmount > 0 && amount > maxAmount { continue }
            let name = hotel.hotelName.isEmpty ? hotel.city : "\(hotel.hotelName), \(hotel.city)"
            out.append(SearchResult(
                kind: .hotel(hotel),
                date: hotel.date,
                title: name,
                subtitle: "\(hotel.date.shortDate)  ·  \(hotel.numberOfNights) Nacht/Nächte",
                icon: "bed.double.fill",
                iconColor: .purple,
                category: "Übernachtung"
            ))
        }

        // ── Fahrzeugkosten ──
        for vc in store.vehicleCosts {
            if let d = selectedDate {
                guard Calendar.current.isDate(vc.date, inSameDayAs: d) else { continue }
            }
            if hasText {
                let hay = "\(vc.title) \(vc.category.rawValue) \(vc.note) \(vc.date.shortDate)".lowercased()
                guard hay.contains(query) else { continue }
            }
            if minAmount > 0 && vc.amount < minAmount { continue }
            if maxAmount > 0 && vc.amount > maxAmount { continue }
            let t = vc.title.isEmpty ? vc.category.rawValue : vc.title
            out.append(SearchResult(
                kind: .vehicleCost(vc),
                date: vc.date,
                title: t,
                subtitle: "\(vc.date.shortDate)  ·  \(vc.amount.euroFormatted)  ·  \(vc.category.rawValue)",
                icon: vc.category.icon,
                iconColor: colorForVehicle(vc.category),
                category: "Fahrzeugkosten"
            ))
        }

        // ── Reisespesen ──
        for rs in store.reiseSpesen {
            if let d = selectedDate {
                guard Calendar.current.isDate(rs.date, inSameDayAs: d) else { continue }
            }
            if hasText {
                let hay = "\(rs.title) \(rs.kategorie.rawValue) \(rs.note) \(rs.date.shortDate)".lowercased()
                guard hay.contains(query) else { continue }
            }
            if minAmount > 0 && rs.amount < minAmount { continue }
            if maxAmount > 0 && rs.amount > maxAmount { continue }
            let t = rs.title.isEmpty ? rs.kategorie.rawValue : rs.title
            out.append(SearchResult(
                kind: .reiseSpese(rs),
                date: rs.date,
                title: t,
                subtitle: "\(rs.date.shortDate)  ·  \(rs.amount.euroFormatted)  ·  \(rs.kategorie.rawValue)",
                icon: rs.kategorie.icon,
                iconColor: colorForSpese(rs.kategorie),
                category: "Reisespesen"
            ))
        }

        return out.sorted(by: { $0.date > $1.date })
    }

    // Gruppiert nach Kategorie
    private var groupedResults: [(String, [SearchResult])] {
        let order = ["Fahrten", "Arbeitszeit", "Übernachtung", "Fahrzeugkosten", "Reisespesen"]
        let dict = Dictionary(grouping: results, by: \.category)
        return order.compactMap { key in
            guard let items = dict[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    // Ergebnis-Summe (nur Fahrten-relevante Werte)
    private var resultSummary: (trips: Int, km: Double, euro: Double) {
        var trips = 0; var km = 0.0; var euro = 0.0
        for r in results {
            if case .trip(let t) = r.kind {
                trips += 1; km += t.km; euro += t.km * store.kmRate
            }
        }
        return (trips, km, euro)
    }

    // Punkt 4: Top-Städte/Routen aus echten Daten
    private var topSuggestions: [String] {
        var freq: [String: Int] = [:]
        for trip in store.trips {
            let locs = [trip.from, trip.to].compactMap { loc -> String? in
                let c = loc.trimmingCharacters(in: .whitespaces)
                return c.isEmpty ? nil : c
            }
            for loc in locs { freq[loc, default: 0] += 1 }
        }
        return freq.sorted { $0.value > $1.value }.prefix(6).map(\.key)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Suchzeile ──
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))
                        TextField(lm.t("nav.search"), text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 15))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Datum-Filter
                    Button { showDatePicker.toggle() } label: {
                        Image(systemName: selectedDate != nil ? "calendar.badge.checkmark" : "calendar")
                            .font(.system(size: 17))
                            .foregroundColor(selectedDate != nil ? .blue : .secondary)
                            .frame(width: 38, height: 38)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Punkt 1: Bereichsfilter
                    Button { showRangeFilter.toggle() } label: {
                        Image(systemName: hasRangeFilter ? "slider.horizontal.3" : "slider.horizontal.3")
                            .font(.system(size: 17))
                            .foregroundColor(hasRangeFilter ? .orange : .secondary)
                            .frame(width: 38, height: 38)
                            .background(hasRangeFilter ? Color.orange.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

                // ── Aktive Filter-Badges ──
                if selectedDate != nil || hasRangeFilter {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let d = selectedDate {
                                filterBadge(text: dateFormatter.string(from: d), color: .blue) {
                                    selectedDate = nil
                                }
                            }
                            if minKm > 0 || maxKm > 0 {
                                let label = maxKm > 0
                                    ? "\(Int(minKm))–\(Int(maxKm)) km"
                                    : "ab \(Int(minKm)) km"
                                filterBadge(text: label, color: .orange) {
                                    minKm = 0; maxKm = 0
                                }
                            }
                            if minAmount > 0 || maxAmount > 0 {
                                let label = maxAmount > 0
                                    ? "\(Int(minAmount))–\(Int(maxAmount)) €"
                                    : "ab \(Int(minAmount)) €"
                                filterBadge(text: label, color: .green) {
                                    minAmount = 0; maxAmount = 0
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 6)
                }

                // ── DatePicker ──
                if showDatePicker {
                    VStack(spacing: 0) {
                        DatePicker(
                            "Datum wählen",
                            selection: Binding(
                                get: { selectedDate ?? Date() },
                                set: { selectedDate = $0; showDatePicker = false }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        Button(lm.t("action.delete")) {
                            selectedDate = nil; showDatePicker = false
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // ── Punkt 1: Bereichsfilter-Panel ──
                if showRangeFilter {
                    rangeFilterPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Divider()

                // ── Inhalt ──
                if searchText.isEmpty && selectedDate == nil && !hasRangeFilter {
                    emptyPromptWithSuggestions
                } else if results.isEmpty {
                    noResults
                } else {
                    // Ergebnis-Summe (Punkt 4 Teilaspekt)
                    let s = resultSummary
                    if s.trips > 0 {
                        HStack(spacing: 16) {
                            Label("\(s.trips) Fahrten", systemImage: "car.fill")
                            Text("·").foregroundColor(.secondary)
                            Text("\(Int(s.km)) km")
                            Text("·").foregroundColor(.secondary)
                            Text(s.euro.euroFormatted)
                                .foregroundColor(.orange)
                                .fontWeight(.semibold)
                            Spacer()
                            // Punkt 5: Export-Button
                            Button {
                                showExportPreview = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground))
                    }

                    List {
                        ForEach(groupedResults, id: \.0) { (category, items) in
                            Section(header: categoryHeader(category, count: items.count)) {
                                ForEach(items) { result in
                                    resultRow(result)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(lm.t("nav.search"))
            .sheet(item: $editTrip) { trip in
                TripFormView(mode: .edit(trip))
                    .environmentObject(store)
                    .environmentObject(lm)
            }
            .sheet(item: $editMeal) { meal in
                MealFormView(mode: .edit(meal))
                    .environmentObject(store)
                    .environmentObject(lm)
            }
            .sheet(item: $editHotel) { hotel in
                HotelFormView(mode: .edit(hotel))
                    .environmentObject(store)
                    .environmentObject(lm)
            }
            // Punkt 5: Export-Preview
            .sheet(isPresented: $showExportPreview) {
                exportPreviewSheet
            }
        }
    }

    // MARK: - Punkt 1: Bereichsfilter-Panel

    private var rangeFilterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter nach Bereich")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            // km-Filter (nur bei Fahrten relevant)
            VStack(alignment: .leading, spacing: 6) {
                Text("Strecke (km)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    rangeField(label: "von", value: $minKm, unit: "km")
                    Text("–").foregroundColor(.secondary)
                    rangeField(label: "bis", value: $maxKm, unit: "km")
                    if minKm > 0 || maxKm > 0 {
                        Button { minKm = 0; maxKm = 0 } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Betrag-Filter
            VStack(alignment: .leading, spacing: 6) {
                Text("Betrag (€)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    rangeField(label: "von", value: $minAmount, unit: "€")
                    Text("–").foregroundColor(.secondary)
                    rangeField(label: "bis", value: $maxAmount, unit: "€")
                    if minAmount > 0 || maxAmount > 0 {
                        Button { minAmount = 0; maxAmount = 0 } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func rangeField(label: String, value: Binding<Double>, unit: String) -> some View {
        HStack(spacing: 4) {
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 64)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Punkt 4: Leerer Zustand mit Vorschlägen

    private var emptyPromptWithSuggestions: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(lm.t("misc.search.hint"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                if !topSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Häufige Orte")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)

                        FlowLayout(spacing: 8) {
                            ForEach(topSuggestions, id: \.self) { suggestion in
                                Button {
                                    searchText = suggestion
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.orange)
                                        Text(suggestion)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Punkt 5: Export-Sheet

    private var exportPreviewSheet: some View {
        let tripResults   = results.compactMap { if case .trip(let t)   = $0.kind { return t } else { return nil } }
        let mealResults   = results.compactMap { if case .meal(let m)   = $0.kind { return m } else { return nil } }
        let hotelResults  = results.compactMap { if case .hotel(let h)  = $0.kind { return h } else { return nil } }
        let vcResults     = results.compactMap { if case .vehicleCost(let v) = $0.kind { return v } else { return nil } }
        let rsResults     = results.compactMap { if case .reiseSpese(let r)  = $0.kind { return r } else { return nil } }

        let label: String
        if !searchText.isEmpty {
            label = "Suche: \(searchText)"
        } else if let d = selectedDate {
            label = dateFormatter.string(from: d)
        } else {
            label = "Gefilterter Export"
        }

        let pdfData = PDFExportService.generatePDF(
            store: store,
            trips: tripResults,
            meals: mealResults,
            hotels: hotelResults,
            vehicleCosts: vcResults,
            reiseSpesen: rsResults,
            privateExpenses: [],
            zeitraum: label
        )

        return PDFPreviewView(pdfData: pdfData, filename: label)
            .environmentObject(store)
            .environmentObject(lm)
    }

    // MARK: - Subviews

    private var noResults: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary.opacity(0.5))
            Text(lm.t("misc.no.entries.search"))
                .font(.headline)
                .foregroundColor(.secondary)
            Text(lm.t("misc.search.hint2"))
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func filterBadge(text: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .foregroundColor(color)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func categoryHeader(_ name: String, count: Int) -> some View {
        HStack {
            Text(name.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func resultRow(_ result: SearchResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(result.iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: result.icon)
                    .font(.system(size: 16))
                    .foregroundColor(result.iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                highlightedText(result.title, query: searchText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(result.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.4))
        }
        .contentShape(Rectangle())
        .onTapGesture { handleTap(result) }
        .padding(.vertical, 2)
    }

    private func highlightedText(_ text: String, query: String) -> Text {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Text(text) }
        var attributed = AttributedString(text)
        if let attrRange = attributed.range(of: q, options: .caseInsensitive) {
            attributed[attrRange].foregroundColor = .orange
            attributed[attrRange].font = .subheadline.weight(.semibold)
        }
        return Text(attributed)
    }

    // MARK: - Tap-Navigation

    private func handleTap(_ result: SearchResult) {
        switch result.kind {
        case .trip(let trip):   editTrip  = trip
        case .meal(let meal):   editMeal  = meal
        case .hotel(let hotel): editHotel = hotel
        case .vehicleCost, .reiseSpese: break
        }
    }

    // MARK: - Farb-Helfer

    private func colorForVehicle(_ cat: VehicleCostCategory) -> Color {
        switch cat {
        case .werkstatt:       return .orange
        case .leasing:         return .blue
        case .versicherung:    return .blue
        case .tuvHu:           return .iosGreen
        case .steuer:          return .purple
        case .reifen:          return .teal
        case .strom:           return .yellow
        case .fahrzeugwaesche: return .cyan
        case .sonstiges:       return .gray
        }
    }

    private func colorForSpese(_ kat: ReisespesenKategorie) -> Color {
        switch kat {
        case .werkstatt:       return .orange
        case .leasing:         return .blue
        case .vignetteMaut:    return .blue
        case .benzin:          return .red
        case .strom:           return .iosGreen
        case .kfzSteuer:       return .purple
        case .kfzVersicherung: return .teal
        case .verpflegung:     return .brown
        case .sonstiges:       return .gray
        }
    }
}

// MARK: - FlowLayout (Chip-Zeilen automatisch umbrechen)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        y += rowHeight
        return CGSize(width: maxWidth, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
