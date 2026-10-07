import SwiftUI

/// Einmalige Vorschau-Fahrt für Nicht-Pro-Nutzer.
/// Zeigt was GPS leistet + Rendite-Argument, bietet "Jetzt ausprobieren" oder "Pro kaufen".
struct GPSTrialSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var proMgr: ProManager
    @EnvironmentObject var lm: LocalizationManager

    let onStart: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Hero ──────────────────────────────────────────────────
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.iosGreen.opacity(0.12))
                                .frame(width: 88, height: 88)
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.iosGreen)
                        }
                        Text("GPS-Aufzeichnung")
                            .font(.title2.bold())
                        Text("Probiere es einmal kostenlos aus –\ndanach mit Pro unbegrenzt.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // ── So funktioniert's ─────────────────────────────────────
                    VStack(spacing: 0) {
                        trialStep(number: "1", icon: "location.fill", color: .iosGreen,
                                  title: "GPS starten",
                                  desc: "Einfach auf 'Starten' tippen - die App zeichnet deine Route automatisch auf.")
                        Divider().padding(.leading, 56)
                        trialStep(number: "2", icon: "road.lanes", color: .blue,
                                  title: "Fahren",
                                  desc: "Kilometer werden live gemessen. Kurze Pausen werden automatisch erkannt.")
                        Divider().padding(.leading, 56)
                        trialStep(number: "3", icon: "doc.text.fill", color: .orange,
                                  title: "Fertig – Fahrt wird gespeichert",
                                  desc: "Start- und Zielort werden automatisch ermittelt und direkt eingetragen.")
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    // ── Rendite-Argument ──────────────────────────────────────
                    HStack(spacing: 14) {
                        Image(systemName: "eurosign.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ø 3.200 € Erstattung/Jahr")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Fahrtkosten Pro kostet einmalig 6,99 €.\nDas ist weniger als 2 Minuten deiner Erstattung.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    // ── Buttons ───────────────────────────────────────────────
                    VStack(spacing: 12) {
                        Button(action: onStart) {
                            Label("Jetzt kostenlos ausprobieren", systemImage: "location.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.iosGreen)
                        .padding(.horizontal)

                        Button(action: onUpgrade) {
                            Text("Direkt Pro kaufen – 6,99 €")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }

                        Text("Nach der Testfahrt kannst du mit Pro unbegrenzt GPS nutzen.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("GPS testen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private func trialStep(number: String, icon: String, color: Color,
                           title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
