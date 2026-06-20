import WidgetKit
import SwiftUI

// MARK: - Shared Data Access (liest aus UserDefaults - gleiche Group wie Hauptapp)
// WICHTIG: In Xcode muss eine App Group aktiviert werden (siehe unten)
private struct WidgetDataAccess {

    // App Group ID – muss in beiden Targets (App + Widget) aktiviert sein
    // Xcode → Signing & Capabilities → + App Groups → z.B. "group.de.tommwagner.fahrtkosten"
    static let groupID = "group.de.tommwagner.fahrtkosten"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    static func loadTrips() -> [WidgetTrip] {
        guard let data = defaults.data(forKey: "trips") else { return [] }
        return (try? JSONDecoder().decode([WidgetTrip].self, from: data)) ?? []
    }

    static func kmRate() -> Double {
        let rate = defaults.double(forKey: "kmRate")
        return rate == 0 ? 0.30 : rate
    }

    static func monthlyData() -> WidgetEntry {
        let trips  = loadTrips()
        let rate   = kmRate()
        let cal    = Calendar.current
        let now    = Date()

        let monthTrips = trips.filter {
            cal.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        let yearTrips = trips.filter {
            cal.isDate($0.date, equalTo: now, toGranularity: .year)
        }

        let monthKm    = monthTrips.reduce(0) { $0 + $1.km }
        let monthEuro  = monthKm * rate
        let yearEuro   = yearTrips.reduce(0) { $0 + $1.km * rate }
        let tripCount  = monthTrips.count

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "MMMM yyyy"
        let monthLabel = formatter.string(from: now)

        return WidgetEntry(
            date: now,
            monthLabel: monthLabel,
            monthEuro: monthEuro,
            monthKm: monthKm,
            yearEuro: yearEuro,
            tripCount: tripCount
        )
    }
}

// MARK: - Minimales Trip-Model fürs Widget (nur was gebraucht wird)
struct WidgetTrip: Codable {
    var km: Double
    var date: Date
}

// MARK: - Timeline Entry
struct WidgetEntry: TimelineEntry {
    let date: Date
    let monthLabel: String
    let monthEuro: Double
    let monthKm: Double
    let yearEuro: Double
    let tripCount: Int

    static var placeholder: WidgetEntry {
        WidgetEntry(date: Date(), monthLabel: "Mai 2026",
                    monthEuro: 142.50, monthKm: 475.0,
                    yearEuro: 892.30, tripCount: 12)
    }
}

// MARK: - Timeline Provider
struct FahrtkostenProvider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : WidgetDataAccess.monthlyData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = WidgetDataAccess.monthlyData()
        // Alle 30 Minuten neu laden
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Small Widget (2×2)
struct SmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color.orange.gradient)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "car.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Fahrtkosten")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Text(euroFormatted(entry.monthEuro))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(entry.monthLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))

                HStack(spacing: 4) {
                    Image(systemName: "road.lanes")
                        .font(.system(size: 10))
                    Text("\(Int(entry.monthKm)) km")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.75))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Medium Widget (4×2)
struct MediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(.systemBackground))

            HStack(spacing: 0) {
                // Linke Seite – Monat
                VStack(alignment: .leading, spacing: 6) {
                    Label("Dieser Monat", systemImage: "calendar")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(euroFormatted(entry.monthEuro))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(entry.monthLabel)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 12) {
                        statChip(icon: "road.lanes",  value: "\(Int(entry.monthKm)) km",       color: .blue)
                        statChip(icon: "car.fill",     value: "\(entry.tripCount) Fahrten",     color: .orange)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Trennlinie
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 0.5)
                    .padding(.vertical, 12)

                // Rechte Seite – Jahr
                VStack(alignment: .leading, spacing: 6) {
                    Label("Dieses Jahr", systemImage: "chart.bar.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(euroFormatted(entry.yearEuro))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Spacer()

                    // Fortschrittsbalken (Monatsanteil am Jahr)
                    if entry.yearEuro > 0 {
                        let ratio = min(entry.monthEuro / entry.yearEuro, 1.0)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Monatsanteil")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.systemGray5))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.orange)
                                        .frame(width: geo.size.width * ratio)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func statChip(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Large Widget (4×4)
struct LargeWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(.systemBackground))

            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack {
                    Label("Fahrtkosten", systemImage: "car.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    Spacer()
                    Text(entry.monthLabel)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                // Monatssumme groß
                VStack(alignment: .leading, spacing: 4) {
                    Text("Erstattung diesen Monat")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(euroFormatted(entry.monthEuro))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                // Stats Grid
                HStack(spacing: 0) {
                    bigStat(icon: "road.lanes",  color: .blue,   value: "\(Int(entry.monthKm)) km",  label: "Kilometer")
                    Divider().frame(height: 50)
                    bigStat(icon: "car.fill",    color: .orange, value: "\(entry.tripCount)",         label: "Fahrten")
                    Divider().frame(height: 50)
                    bigStat(icon: "calendar",    color: .green,  value: euroFormatted(entry.yearEuro), label: "Jahressumme")
                }
                .padding(.vertical, 12)

                Divider()

                // Fortschrittsbalken
                if entry.yearEuro > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Monatsanteil am Jahr")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.0f%%", (entry.monthEuro / entry.yearEuro) * 100))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange.gradient)
                                    .frame(width: geo.size.width * min(entry.monthEuro / entry.yearEuro, 1.0))
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Spacer()
            }
        }
    }

    private func bigStat(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hilfs-Formatter (kein Zugriff auf Helpers.swift im Widget)
private func euroFormatted(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    f.decimalSeparator = ","
    f.groupingSeparator = "."
    return (f.string(from: NSNumber(value: value)) ?? "0,00") + " €"
}

// MARK: - Widget Konfiguration
struct FahrtkostenWidget: Widget {
    let kind: String = "FahrtkostenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FahrtkostenProvider()) { entry in
            FahrtkostenWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fahrtkosten")
        .description("Zeigt die Fahrtkosten-Erstattung des aktuellen Monats.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry View (wählt je nach Größe die richtige View)
struct FahrtkostenWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        case .systemLarge:  LargeWidgetView(entry: entry)
        default:            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle Entry Point
@main
struct FahrtkostenWidgetBundle: WidgetBundle {
    var body: some Widget {
        FahrtkostenWidget()
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    FahrtkostenWidget()
} timeline: {
    WidgetEntry.placeholder
}

#Preview(as: .systemMedium) {
    FahrtkostenWidget()
} timeline: {
    WidgetEntry.placeholder
}

#Preview(as: .systemLarge) {
    FahrtkostenWidget()
} timeline: {
    WidgetEntry.placeholder
}
