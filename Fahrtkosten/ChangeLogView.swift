import SwiftUI

// MARK: - Änderungsprotokoll (Fahrtenbuchmodus)
// Zeigt das unveränderliche, verkettete Änderungsprotokoll aus DataStore.changeLog an.
struct ChangeLogView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedType: LoggedEntityType? = nil

    private var filtered: [ChangeLogEntry] {
        store.changeLog
            .filter { selectedType == nil || $0.entityType == selectedType }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        List {
            Section {
                Picker("Art", selection: $selectedType) {
                    Text("Alle").tag(LoggedEntityType?.none)
                    ForEach(LoggedEntityType.allCases, id: \.self) { type in
                        Text(type.localizedName).tag(LoggedEntityType?.some(type))
                    }
                }
                .pickerStyle(.menu)
            }

            if filtered.isEmpty {
                Text("Noch keine protokollierten Änderungen.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filtered) { entry in
                    ChangeLogRow(entry: entry)
                }
            }
        }
        .navigationTitle("Änderungsprotokoll")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Einzelner Protokoll-Eintrag
private struct ChangeLogRow: View {
    let entry: ChangeLogEntry
    @State private var expanded = false

    private var icon: String {
        switch entry.changeType {
        case .created: return "plus.circle.fill"
        case .updated: return "pencil.circle.fill"
        case .deleted: return "trash.circle.fill"
        case .rollbackDetected: return "exclamationmark.triangle.fill"
        }
    }
    private var color: Color {
        switch entry.changeType {
        case .created: return .iosGreen
        case .updated: return .orange
        case .deleted: return .red
        case .rollbackDetected: return .red
        }
    }
    private var changeLabel: String {
        switch entry.changeType {
        case .created: return "Angelegt"
        case .updated: return "Geändert"
        case .deleted: return "Gelöscht"
        case .rollbackDetected: return "Rollback erkannt"
        }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(diffLines, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let reason = entry.changeReason, !reason.isEmpty {
                    Text("Änderungsgrund: \(reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("#\(entry.seq) · Hash: \(entry.hash.prefix(16))…  ·  Vorheriger: \(entry.previousHash.prefix(16))…")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospaced()
                Text("Geräte-Signatur: \(entry.deviceSignature.isEmpty ? "–" : String(entry.deviceSignature.prefix(16)) + "…")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospaced()
                Text(entry.tsaTokenBase64 != nil ? "RFC-3161-Zeitstempel: vorhanden ✓" : "RFC-3161-Zeitstempel: noch nicht abgerufen")
                    .font(.caption2)
                    .foregroundStyle(entry.tsaTokenBase64 != nil ? Color.secondary : Color.orange)
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.entityType.localizedName) – \(changeLabel)")
                        .font(.subheadline)
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Feldweiser Vergleich der JSON-Snapshots vor/nach der Änderung – entitätsunabhängig,
    /// damit kein eigener Diff-Code pro Trip/Meal/Hotel/… nötig ist.
    private var diffLines: [String] {
        let before = jsonDict(entry.snapshotBefore)
        let after  = jsonDict(entry.snapshotAfter)
        let keys = Set(before.keys).union(after.keys).sorted()
        var lines: [String] = []
        for key in keys where key != "id" {
            let b = before[key].map(describe) ?? "–"
            let a = after[key].map(describe) ?? "–"
            if b != a { lines.append("\(key): \(b) → \(a)") }
        }
        return lines.isEmpty ? ["Keine erkennbare Feldänderung."] : lines
    }

    private func jsonDict(_ data: Data?) -> [String: Any] {
        guard let data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }

    private func describe(_ value: Any) -> String {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        if value is NSNull { return "–" }
        return "\(value)"
    }
}
