import SwiftUI
import StoreKit

struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var proMgr: ProManager

    let features: [(String, String, Color, String)] = [
        ("location.fill",          "GPS-Aufzeichnung",       .blue,   "Strecke automatisch per GPS erfassen"),
        ("doc.richtext.fill",      "Export PDF & Excel",     .green,  "Fertige Abrechnung als Dokument"),
        ("arrow.clockwise.icloud", "Backup & Restore",       .cyan,   "Daten sichern und wiederherstellen"),
        ("car.fill",               "CarPlay",                .indigo, "GPS-Aufzeichnung am Fahrzeugdisplay"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Hero ─────────────────────────────────────────────────
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow, .orange)
                            .padding(.top, 8)

                        Text("Fahrtkosten Pro")
                            .font(.title.bold())

                        // Rendite-Argument
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "eurosign.circle.fill")
                                    .foregroundStyle(.orange)
                                Text("Ø 3.200 € Erstattung pro Jahr")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text("Pro kostet einmalig 6,99 € – das ist weniger als 2 Minuten deiner jährlichen Erstattung.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // ── Feature-Liste ─────────────────────────────────────────
                    VStack(spacing: 0) {
                        ForEach(features, id: \.1) { icon, title, color, desc in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(color.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: icon)
                                        .foregroundColor(color)
                                        .font(.system(size: 17))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title).font(.system(size: 15, weight: .semibold))
                                    Text(desc).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.iosGreen)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            if features.last?.1 != title {
                                Divider().padding(.leading, 74)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .padding(.horizontal)

                    // ── Preis-Card ────────────────────────────────────────────
                    VStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("6,99 €")
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                            Text("einmalig")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text("Kein Abo · kein Ablaufdatum · alle zukünftigen Updates inklusive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .padding(.horizontal)

                    // ── Fehlermeldung ─────────────────────────────────────────
                    if let err = proMgr.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // ── Kaufen ────────────────────────────────────────────────
                    Button {
                        Task { await proMgr.purchase() }
                    } label: {
                        Group {
                            if proMgr.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Jetzt kaufen – 6,99 €")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(proMgr.isLoading)
                    .padding(.horizontal)

                    // ── Wiederherstellen ──────────────────────────────────────
                    Button {
                        Task { await proMgr.restore() }
                    } label: {
                        Text("Kauf wiederherstellen")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .disabled(proMgr.isLoading)

                    Text("Einmalkauf über Apple In-App-Käufe.\nNach dem Kauf auf allen deinen Geräten verfügbar.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onChange(of: proMgr.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }
}
