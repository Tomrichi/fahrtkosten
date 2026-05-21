import SwiftUI

// MARK: - Watch Hauptmenü
struct WatchContentView: View {
    @EnvironmentObject var model: WatchViewModel

    var body: some View {
        NavigationStack {
            List {
                // Aktive Fahrt Banner
                if model.hasActiveTrip {
                    activeTripSection
                }

                // Fahrt starten / stoppen
                NavigationLink {
                    WatchTripView()
                        .environmentObject(model)
                } label: {
                    Label(
                        model.hasActiveTrip ? "Fahrt stoppen" : "Fahrt starten",
                        systemImage: model.hasActiveTrip ? "stop.circle.fill" : "car.fill"
                    )
                    .foregroundColor(model.hasActiveTrip ? .red : .orange)
                }

                // Monatssumme
                NavigationLink {
                    WatchSummaryView()
                        .environmentObject(model)
                } label: {
                    Label("Monatsübersicht", systemImage: "eurosign.circle.fill")
                        .foregroundColor(.green)
                }

                // Aktualisieren
                Button {
                    model.requestUpdate()
                } label: {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Fahrtkosten")
        }
        .onAppear { model.requestUpdate() }
    }

    // MARK: - Aktive Fahrt Banner
    private var activeTripSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Fahrt läuft", systemImage: "location.fill")
                .font(.caption2.bold())
                .foregroundColor(.orange)
            Text("→ \(model.activeTo)")
                .font(.caption)
                .lineLimit(1)
            if let since = model.activeSince {
                Text(since, style: .timer)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .listRowBackground(Color.orange.opacity(0.15))
    }
}
