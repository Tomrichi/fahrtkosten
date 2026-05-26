import SwiftUI

struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var proMgr: ProManager
    @State private var selectedPlan = "yearly"

    let features: [(String, String, Color, String)] = [
        ("map.fill",         "Google/Apple Maps Integration", .blue,   "Routenvorschau & automatischer km-Import"),
        ("arrow.down.circle.fill", "Automatischer km-Import", .green,  "Strecke direkt in die Abrechnung übernehmen"),
        ("infinity",         "Unbegrenzte Einträge",          .orange, "Fahrten, Verpflegung & Übernachtungen"),
        ("doc.fill",         "PDF-Export",                    .purple, "Fertige Abrechnung als Dokument"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.yellow, .orange)
                            .accessibilityHidden(true)
                        Text("Fahrtkosten Pro")
                            .font(.title.bold())
                        Text("Alles was du für die perfekte Abrechnung brauchst")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    // Features
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
                                .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title).font(.system(size: 15, weight: .semibold))
                                    Text(desc).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.iosGreen)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(title). \(desc)")
                            if features.last?.1 != title {
                                Divider().padding(.leading, 74)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .padding(.horizontal)

                    // Plan picker
                    VStack(spacing: 10) {
                        ForEach([
                            ("monthly", "Monatlich",  "4,99 €",  "/ Monat",   "Flexibel · jederzeit kündbar", false),
                            ("yearly",  "Jährlich",   "39,99 €", "/ Jahr",    "= 3,33 € / Monat · 33 % günstiger", true),
                        ], id: \.0) { id, name, price, unit, desc, isBest in
                            PlanCard(
                                id: id, name: name, price: price,
                                unit: unit, desc: desc, isBest: isBest,
                                isSelected: selectedPlan == id
                            )
                            .onTapGesture { selectedPlan = id }
                        }
                    }
                    .padding(.horizontal)

                    // CTA
                    Button {
                        proMgr.isPro = true
                        dismiss()
                    } label: {
                        Text("Jetzt upgraden – \(selectedPlan == "monthly" ? "4,99 € / Monat" : "39,99 € / Jahr")")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.horizontal)
                    .accessibilityLabel("Fahrtkosten Pro kaufen, \(selectedPlan == "monthly" ? "4,99 Euro pro Monat" : "39,99 Euro pro Jahr")")
                    .accessibilityHint("Startet den In-App-Kauf")

                    Text("Abonnement über Apple In-App-Käufe.\nJederzeit in den Einstellungen kündbar.")
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
        }
    }
}

struct PlanCard: View {
    let id: String, name: String, price: String, unit: String, desc: String, isBest: Bool, isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(name).font(.headline)
                    if isBest {
                        Text("BEST VALUE")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.iosGreen)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(price).font(.system(size: 22, weight: .bold, design: .monospaced))
                    Text(unit).font(.subheadline).foregroundColor(.secondary)
                }
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .secondary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(price) \(unit). \(desc)\(isBest ? ". Bestes Angebot." : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
