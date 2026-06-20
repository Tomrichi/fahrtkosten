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

    // Datum-Formatter
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    // MARK: - Suchergebnisse berechnen

    private var results: [SearchResult] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let hasText = !query.isEmpty
        let hasDate = selectedDate != nil

        guard hasText || hasDate else { return [] }

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Suchzeile ──
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))
                        TextField("Suche nach Text, Ort, Notiz …", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
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

                    // Datum-Filter Button
                    Button {
                        showDatePicker.toggle()
                    } label: {
                        Image(systemName: selectedDate != nil ? "calendar.badge.checkmark" : "calendar")
                            .font(.system(size: 18))
                            .foregroundColor(selectedDate != nil ? .blue : .secondary)
                            .frame(width: 40, height: 40)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // ── Aktiver Datums-Filter Badge ──
                if let d = selectedDate {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(dateFormatter.string(from: d))
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Button {
                            selectedDate = nil
                        } label: {
                            Text("Entfernen")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
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

                        Button("Datum entfernen") {
                            selectedDate = nil
                            showDatePicker = false
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                Divider()

                // ── Ergebnisliste ──
                if searchText.isEmpty && selectedDate == nil {
                    emptyPrompt
                } else if results.isEmpty {
                    noResults
                } else {
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
            .navigationTitle("Suche")
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
        }
    }

    // MARK: - Subviews

    private var emptyPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Tippe einen Begriff ein oder\nwähle ein Datum")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noResults: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Keine Einträge gefunden")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Versuche einen anderen Suchbegriff\noder ein anderes Datum")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(result.iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: result.icon)
                    .font(.system(size: 16))
                    .foregroundColor(result.iconColor)
            }

            // Text
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
        .onTapGesture {
            handleTap(result)
        }
        .padding(.vertical, 2)
    }

    /// Hebt den Suchwort-Treffer im Text hervor (iOS 26-kompatibel via AttributedString)
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
        case .trip(let trip):
            editTrip = trip
        case .meal(let meal):
            editMeal = meal
        case .hotel(let hotel):
            editHotel = hotel
        case .vehicleCost, .reiseSpese:
            break // Keine eigene Edit-Sheet hier, einfach navigieren
        }
    }

    // MARK: - Farb-Helfer

    private func colorForVehicle(_ cat: VehicleCostCategory) -> Color {
        switch cat {
        case .werkstatt:       return .orange
        case .leasing:         return .indigo
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
        case .leasing:         return .indigo
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
