import SwiftUI
import Charts

// MARK: - Statistik View
struct StatistikView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedTab: StatTab = .monate

    private var availableYears: [Int] {
        let years = Set(store.trips.map { Calendar.current.component(.year, from: $0.date) })
        return years.sorted().reversed()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Jahr-Picker
                yearPicker

                // Jahres-Zusammenfassung
                jahresSummary

                // Tab-Auswahl
                tabPicker

                // Inhalt je nach Tab
                switch selectedTab {
                case .monate:   monatsChart
                case .strecken: streckenListe
                case .steuer:   steuerAuswertung
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Jahr Picker
    private var yearPicker: some View {
        HStack {
            Button {
                if let prev = availableYears.last(where: { $0 < selectedYear }) {
                    selectedYear = prev
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(availableYears.contains(where: { $0 < selectedYear }) ? .primary : .secondary.opacity(0.3))
            }
            .accessibilityLabel("Vorheriges Jahr")
            .accessibilityHint("Wechselt zu \(selectedYear - 1)")
            .disabled(!availableYears.contains(where: { $0 < selectedYear }))
            Spacer()
            Text(String(selectedYear))
                .font(.title3.bold())
                .accessibilityLabel("Jahr \(selectedYear)")
            Spacer()
            Button {
                if let next = availableYears.first(where: { $0 > selectedYear }) {
                    selectedYear = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(availableYears.contains(where: { $0 > selectedYear }) ? .primary : .secondary.opacity(0.3))
            }
            .accessibilityLabel("Nächstes Jahr")
            .accessibilityHint("Wechselt zu \(selectedYear + 1)")
            .disabled(!availableYears.contains(where: { $0 > selectedYear }))
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - Jahres-Zusammenfassung
    private var jahresSummary: some View {
        let trips = tripsForYear
        let km    = trips.reduce(0) { $0 + $1.km }
        let euro  = km * store.kmRate

        return HStack(spacing: 12) {
            summaryTile(icon: "car.fill",          color: .orange,  value: "\(trips.count)",                 label: "Fahrten")
            summaryTile(icon: "road.lanes",        color: .blue,    value: "\(Int(km)) km",                  label: "Kilometer")
            summaryTile(icon: "eurosign.circle",   color: .green,   value: euro.euroFormatted,               label: "Erstattung")
        }
    }

    private func summaryTile(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .accessibilityHidden(true)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Tab Picker
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(StatTab.allCases) { tab in
                Button {
                    withOptionalAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                            .accessibilityHidden(true)
                        Text(tab.label)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab
                            ? Color.orange
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel("Ansicht wählen")
    }

    // MARK: - Monats-Chart
    private var monatsChart: some View {
        let data = monthlyData

        return VStack(alignment: .leading, spacing: 16) {
            Text("Erstattung pro Monat")
                .font(.headline)

            if data.allSatisfy({ $0.euro == 0 }) {
                emptyState(icon: "chart.bar.xaxis", text: "Keine Fahrten in \(selectedYear)")
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Monat", item.shortMonth),
                        y: .value("Euro", item.euro)
                    )
                    .foregroundStyle(item.isCurrentMonth ? Color.orange : Color.orange.opacity(0.45))
                    .cornerRadius(5)
                    .annotation(position: .top) {
                        if item.euro > 0 {
                            Text(item.euro > 99 ? "\(Int(item.euro))€" : item.euro.euroFormatted)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))€").font(.system(size: 10))
                            }
                        }
                        AxisGridLine()
                    }
                }

                // Spitzenwert
                if let best = data.max(by: { $0.euro < $1.euro }), best.euro > 0 {
                    HStack {
                        Image(systemName: "trophy.fill").foregroundColor(.orange)
                            .accessibilityHidden(true)
                        Text("Bester Monat: **\(best.month)** mit \(best.euro.euroFormatted)")
                            .font(.subheadline)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Häufigste Strecken
    private var streckenListe: some View {
        let strecken = topRoutes

        return VStack(alignment: .leading, spacing: 16) {
            Text("Häufigste Strecken")
                .font(.headline)

            if strecken.isEmpty {
                emptyState(icon: "road.lanes", text: "Keine Fahrten in \(selectedYear)")
            } else {
                let maxCount = strecken.first?.count ?? 1

                VStack(spacing: 10) {
                    ForEach(Array(strecken.enumerated()), id: \.element.route) { index, item in
                        HStack(spacing: 12) {
                            // Rang
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.route)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                Text("\(item.count)× · Ø \(String(format: "%.0f", item.avgKm)) km · \((item.totalKm * store.kmRate).euroFormatted)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Balken
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.orange.opacity(0.3 + 0.5 * Double(item.count) / Double(maxCount)))
                                    .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                            }
                            .frame(width: 50, height: 6)
                        }
                        .padding(12)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Steuer-Auswertung
    private var steuerAuswertung: some View {
        let trips   = tripsForYear
        let km      = trips.reduce(0) { $0 + $1.km }
        let euro    = km * store.kmRate
        let meals   = store.meals.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
        let hotels  = store.hotels.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
        let mealSum = meals.reduce(0.0) { $0 + $1.allowance(rates: store.mealRates(for: $1.region)) }
        let hotelSum = hotels.reduce(0.0) { $0 + $1.amount(flat: store.hotelFlat) }
        let gesamt  = euro + mealSum + hotelSum

        return VStack(alignment: .leading, spacing: 16) {
            Text("Steuerjahr \(selectedYear)")
                .font(.headline)

            VStack(spacing: 0) {
                steuerZeile(icon: "car.fill",       color: .orange, label: "Fahrtkostenpauschale", value: euro,     detail: "\(Int(km)) km × \(store.kmRate.euroFormatted)")
                Divider().padding(.leading, 48)
                steuerZeile(icon: "fork.knife",     color: .green,  label: "Verpflegungskosten",   value: mealSum,  detail: "\(meals.count) Einträge")
                Divider().padding(.leading, 48)
                steuerZeile(icon: "bed.double.fill", color: .blue,  label: "Übernachtungskosten",  value: hotelSum, detail: "\(hotels.count) Nächte")
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Gesamt
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gesamterstattung \(selectedYear)")
                        .font(.subheadline.bold())
                    Text("Für Anlage N / Reisekostenabrechnung")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(gesamt.euroFormatted)
                    .font(.title3.bold())
                    .foregroundColor(.orange)
            }
            .padding(14)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Hinweis
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.footnote)
                    .accessibilityHidden(true)
                Text("Diese Auswertung dient als Orientierung. Bitte prüfe die Beträge mit deinem Steuerberater oder Steuerprogramm.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func steuerZeile(icon: String, color: Color, label: String, value: Double, detail: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 14))
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(value.euroFormatted)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(12)
    }

    // MARK: - Empty State
    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Daten-Berechnung
    private var tripsForYear: [Trip] {
        store.trips.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
    }

    private var monthlyData: [MonthData] {
        let cal = Calendar.current
        let now = Date()
        let currentMonth = cal.component(.month, from: now)
        let currentYear  = cal.component(.year, from: now)

        return (1...12).map { month in
            let trips = tripsForYear.filter { cal.component(.month, from: $0.date) == month }
            let euro  = trips.reduce(0) { $0 + $1.km * store.kmRate }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            var comps = DateComponents(); comps.month = month; comps.year = selectedYear
            let date = cal.date(from: comps) ?? Date()
            formatter.dateFormat = "MMM"
            let short = formatter.string(from: date)
            formatter.dateFormat = "MMMM"
            let full = formatter.string(from: date)
            return MonthData(
                month: full,
                shortMonth: short,
                euro: euro,
                isCurrentMonth: month == currentMonth && selectedYear == currentYear
            )
        }
    }

    private var topRoutes: [RouteData] {
        var counts: [String: (count: Int, kmSum: Double)] = [:]
        for trip in tripsForYear {
            let key = "\(trip.from) → \(trip.to)"
            let existing = counts[key] ?? (0, 0)
            counts[key] = (existing.count + 1, existing.kmSum + trip.km)
        }
        return counts.map { key, val in
            RouteData(route: key, count: val.count, totalKm: val.kmSum, avgKm: val.count > 0 ? val.kmSum / Double(val.count) : 0)
        }
        .sorted { $0.count > $1.count }
        .prefix(10)
        .map { $0 }
    }
}

// MARK: - Hilfstypen
enum StatTab: String, CaseIterable, Identifiable {
    case monate   = "Monate"
    case strecken = "Strecken"
    case steuer   = "Steuer"

    var id: String { rawValue }
    var label: String { rawValue }
    var icon: String {
        switch self {
        case .monate:   return "chart.bar.fill"
        case .strecken: return "road.lanes"
        case .steuer:   return "doc.text.fill"
        }
    }
}

struct MonthData: Identifiable {
    let id = UUID()
    let month: String
    let shortMonth: String
    let euro: Double
    let isCurrentMonth: Bool
}

struct RouteData {
    let route: String
    let count: Int
    let totalKm: Double
    let avgKm: Double
}

// MARK: - Preview
#Preview {
    StatistikView()
        .environmentObject(DataStore())
}
