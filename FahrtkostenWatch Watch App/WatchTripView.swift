import SwiftUI

// Lokale Decodierung der iOS-Favoriten aus App Group
private struct WatchFavorite: Codable {
    var id: UUID
    var from: String
    var to: String
    var km: Double
}

// MARK: - Watch Fahrt starten / stoppen
struct WatchTripView: View {
    @EnvironmentObject var model: WatchViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("homeAddress") private var homeAddress: String = ""

    // Manueller Modus
    @State private var destination = ""
    @State private var origin      = ""
    @State private var kmInput: Double = 0
    @State private var showManual  = false
    @State private var showSuccess = false

    var body: some View {
        if model.isGPSTracking {
            gpsActiveView
        } else if model.hasActiveTrip {
            stopTripView
        } else if showManual {
            startTripView
        } else {
            tripModeSelection
        }
    }

    // MARK: - Modus-Auswahl (Manuell / GPS)
    private var tripModeSelection: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "car.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)

                Text("Neue Fahrt")
                    .font(.headline)

                // GPS Fahrt
                Button {
                    model.startGPSTrip()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("GPS starten")
                            .font(.body.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // Manuelle Eingabe
                Button {
                    showManual = true
                } label: {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("Manuell")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.orange.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                if let err = model.errorMessage {
                    Text(err).font(.caption).foregroundColor(.red)
                }
            }
            .padding()
        }
        .navigationTitle("Fahrt starten")
    }

    // MARK: - GPS aktiv (live Anzeige)
    private var gpsActiveView: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "location.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)

                Text("GPS läuft")
                    .font(.headline)
                    .foregroundColor(.green)

                // Live-Werte: km / Zeit
                HStack(spacing: 8) {
                    liveStatTile(
                        icon: "road.lanes",
                        value: String(format: "%.1f", model.gpsKm),
                        unit: "km",
                        color: .blue
                    )
                    liveStatTile(
                        icon: "timer",
                        value: model.elapsedString(model.gpsElapsed),
                        unit: "",
                        color: .orange
                    )
                }
                // Tempo: aktuell / Durchschnitt
                HStack(spacing: 8) {
                    liveStatTile(
                        icon: "speedometer",
                        value: String(format: "%.0f", model.gpsSpeed),
                        unit: "km/h",
                        color: .green
                    )
                    liveStatTile(
                        icon: "gauge.with.dots.needle.33percent",
                        value: String(format: "%.0f", model.gpsAvgSpeed),
                        unit: "⌀ km/h",
                        color: .cyan
                    )
                }

                if model.isLoading {
                    ProgressView()
                        .tint(.green)
                } else {
                    Button {
                        model.stopGPSTrip()
                        showSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            dismiss()
                        }
                    } label: {
                        Label("GPS stoppen", systemImage: "stop.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                if showSuccess {
                    VStack(spacing: 4) {
                        Label("Gespeichert!", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Wird geocodiert…")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if let err = model.errorMessage {
                    Text(err).font(.caption).foregroundColor(.red)
                }
            }
            .padding()
        }
        .navigationTitle("GPS-Fahrt")
    }

    private func liveStatTile(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.12))
        .cornerRadius(8)
    }

    // MARK: - Manuelle Fahrt starten
    private var startTripView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)

                Text("Manuell")
                    .font(.headline)

                // Ziel
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ziel").font(.caption).foregroundColor(.secondary)
                    TextField("z.B. München", text: $destination)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.darkGray).opacity(0.3))
                        .cornerRadius(8)
                }

                // Von (optional)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Von (optional)").font(.caption).foregroundColor(.secondary)
                    TextField("Startort", text: $origin)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.darkGray).opacity(0.3))
                        .cornerRadius(8)
                }

                // Schnellziele (Heimatadresse + Favoriten)
                let quick = quickDestinations
                if !quick.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Schnellziele").font(.caption).foregroundColor(.secondary)
                        ForEach(quick, id: \.self) { dest in
                            Button {
                                destination = dest
                            } label: {
                                HStack {
                                    Image(systemName: dest == homeAddress ? "house.fill" : "location.fill")
                                        .font(.caption2)
                                        .foregroundColor(dest == homeAddress ? .orange : .secondary)
                                    Text(dest)
                                        .font(.caption)
                                    Spacer()
                                }
                                .padding(6)
                                .background(destination == dest ? Color.orange.opacity(0.3) : Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if model.isLoading {
                    ProgressView()
                } else {
                    Button {
                        guard !destination.isEmpty else { return }
                        let from = origin.isEmpty ? "Aktueller Standort" : origin
                        model.startTrip(from: from, to: destination)
                        showSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    } label: {
                        Label("Starten", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(destination.isEmpty ? Color.gray : Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(destination.isEmpty)
                    .buttonStyle(.plain)
                }

                if showSuccess {
                    Label("Gestartet!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }

                if let err = model.errorMessage {
                    Text(err).font(.caption).foregroundColor(.red)
                }
            }
            .padding()
        }
        .navigationTitle("Manuell")
    }

    // MARK: - Fahrt stoppen (manuell)
    private var stopTripView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red)

                Text("Fahrt beenden")
                    .font(.headline)

                // Aktive Fahrt Info
                VStack(spacing: 4) {
                    Text(model.activeFrom)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(model.activeTo)
                        .font(.caption.bold())
                }
                .padding(8)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)

                // Kilometer eingeben
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gefahrene km").font(.caption).foregroundColor(.secondary)
                    HStack {
                        TextField("0", value: $kmInput, format: .number)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.darkGray).opacity(0.3))
                            .cornerRadius(8)
                        Text("km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Schnell-km Buttons
                HStack(spacing: 8) {
                    ForEach([10.0, 25.0, 50.0, 100.0], id: \.self) { km in
                        Button {
                            kmInput = km
                        } label: {
                            Text("\(Int(km))")
                                .font(.caption2.bold())
                                .padding(6)
                                .background(kmInput == km ? Color.red.opacity(0.3) : Color.gray.opacity(0.2))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if model.isLoading {
                    ProgressView()
                } else {
                    Button {
                        model.stopTrip(km: kmInput)
                        showSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    } label: {
                        Label("Speichern", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(kmInput > 0 ? Color.red : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(kmInput <= 0)
                    .buttonStyle(.plain)
                }

                if showSuccess {
                    Label("Gespeichert!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }

                if let err = model.errorMessage {
                    Text(err).font(.caption).foregroundColor(.red)
                }
            }
            .padding()
        }
        .navigationTitle("Stoppen")
    }

    // MARK: - Schnellziele: Heimatadresse + Favoriten aus App Group

    private var quickDestinations: [String] {
        var result: [String] = []

        // 1. Heimatadresse zuerst
        if !homeAddress.isEmpty {
            result.append(homeAddress)
        }

        // 2. Favoriten aus App Group (iOS speichert dort unter "favorites")
        if let ud = UserDefaults(suiteName: "group.de.tommwagner.fahrtkosten"),
           let data = ud.data(forKey: "favorites"),
           let favs = try? JSONDecoder().decode([WatchFavorite].self, from: data) {
            for fav in favs {
                let dest = fav.to.trimmingCharacters(in: .whitespaces)
                if !dest.isEmpty && !result.contains(dest) {
                    result.append(dest)
                }
            }
        }

        return result
    }
}
