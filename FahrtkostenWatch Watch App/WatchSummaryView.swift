import SwiftUI

// MARK: - Watch Monatsübersicht
struct WatchSummaryView: View {
    @EnvironmentObject var model: WatchViewModel

    private var monthName: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                // Header
                VStack(spacing: 2) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text(monthName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Erstattung
                VStack(spacing: 2) {
                    Text("Erstattung")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(model.euroString(model.monthEuro))
                        .font(.title3.bold())
                        .foregroundColor(.orange)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(10)

                // Stats
                HStack(spacing: 8) {
                    statTile(
                        icon: "road.lanes",
                        value: model.kmString(model.monthKm),
                        label: "Kilometer",
                        color: .blue
                    )
                    statTile(
                        icon: "car.fill",
                        value: "\(model.tripCount)",
                        label: "Fahrten",
                        color: .orange
                    )
                }

                // Km-Satz
                HStack {
                    Image(systemName: "eurosign.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Km-Satz: \(String(format: "%.2f", model.kmRate).replacingOccurrences(of: ".", with: ",")) €/km")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Letzte Aktualisierung
                if let updated = model.lastUpdate {
                    Text("Stand: \(updated, style: .time)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Aktualisieren Button
                Button {
                    model.requestUpdate()
                } label: {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle("Übersicht")
        .onAppear { model.requestUpdate() }
    }

    private func statTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.caption.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
