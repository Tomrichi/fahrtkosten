import SwiftUI

// MARK: - KFZ Kosten List
struct KFZKostenView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager
    @State private var showAdd              = false
    @State private var editSpese: ReiseSpese?
    @State private var showScanner          = false
    @State private var pendingSpese: ReiseSpese?
    @State private var selectedKategorie: ReisespesenKategorie? = nil

    @State private var zeitFilter: ZeitFilter = .monat
    private let columns = [GridItem(.flexible())]

    private func inPeriod(_ date: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch zeitFilter {
        case .woche: return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .monat: return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .jahr:  return cal.isDate(date, equalTo: now, toGranularity: .year)
        }
    }

    private var filteredSpesen: [ReiseSpese] {
        store.reiseSpesen.filter { inPeriod($0.date) }
    }

    private var grouped: [ReisespesenKategorie: [ReiseSpese]] {
        Dictionary(grouping: filteredSpesen, by: { $0.kategorie })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.reiseSpesen.isEmpty {
                        emptyState
                    } else {
                        // ── Zeitraum-Filter ──
                        Picker("Zeitraum", selection: $zeitFilter) {
                            ForEach(ZeitFilter.allCases, id: \.self) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)

                        // ── Header-Karte ──
                        ListHeaderCard(
                            icon: "wrench.and.screwdriver.fill",
                            color: .iosOrange,
                            title: "KFZ Kosten",
                            countLabel: "\(filteredSpesen.count) Belege",
                            total: filteredSpesen.reduce(0) { $0 + $1.amount }
                        )
                        .padding(.horizontal, 16)

                        // ── Kategorie-Kacheln ──
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(ReisespesenKategorie.allCases.filter { $0 != .verpflegung }, id: \.self) { kat in
                                let items  = grouped[kat] ?? []
                                let color  = kfzColor(kat)
                                Button {
                                    selectedKategorie = kat
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(color.opacity(0.15))
                                                .frame(width: 34, height: 34)
                                            Image(systemName: kat.icon)
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(color)
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(kat.localizedName)
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text(items.isEmpty ? "Keine Einträge" : "\(items.count) Einträge")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if items.isEmpty {
                                            Text("–")
                                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text(items.reduce(0) { $0 + $1.amount }.euroFormatted)
                                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                                .foregroundColor(color)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary.opacity(0.4))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.secondarySystemGroupedBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(items.isEmpty ? Color.clear : color.opacity(0.2), lineWidth: 1)
                                    )
                                    .opacity(items.isEmpty ? 0.5 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)

                        // ── Fahrzeugkosten (KFZ-spezifisch) ──
                        VehicleCostTilesSection(zeitFilter: zeitFilter)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("KFZ Kosten")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            AppLogger.shared.logTap("KFZ-Spesen: Manuell erfassen")
                            showAdd = true
                        } label: {
                            Label("Manuell erfassen", systemImage: "plus")
                        }
                        Button {
                            AppLogger.shared.logTap("KFZ-Spesen: Beleg scannen")
                            showScanner = true
                        } label: {
                            Label("Beleg scannen", systemImage: "doc.viewfinder.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                KFZKostenFormView(mode: .add)
            }
            .sheet(item: $editSpese) { s in
                KFZKostenFormView(mode: .edit(s))
            }
            .sheet(item: $selectedKategorie) { kat in
                KFZKategorieDetailView(
                    kategorie: kat,
                    items: (grouped[kat] ?? []).sorted(by: { $0.date > $1.date }),
                    mealAllowance: nil,
                    onEdit: { _ in },
                    onDelete: { id in store.deleteReiseSpese(id) }
                )
            }
            .sheet(isPresented: $showScanner, onDismiss: {
                if let pending = pendingSpese {
                    editSpese    = pending
                    pendingSpese = nil
                }
            }) {
                ReceiptScannerView(target: .reiseSpese) { result in
                    pendingSpese = ReiseSpese(
                        date: result.suggestedDate ?? Date(),
                        kategorie: .sonstiges,
                        title: result.suggestedName ?? "",
                        amount: result.suggestedAmount ?? 0,
                        note: ""
                    )
                }
            }
        }
    }

    private func kfzColor(_ kat: ReisespesenKategorie) -> Color {
        switch kat {
        case .werkstatt:       return .iosOrange
        case .leasing:         return .iosIndigo
        case .vignetteMaut:    return .blue
        case .benzin:          return Color(.systemRed)
        case .strom:           return .iosGreen
        case .kfzSteuer:       return .iosPurple
        case .kfzVersicherung: return .iosTeal
        case .verpflegung:     return .brown
        case .sonstiges:       return Color(.systemGray)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.iosOrange.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(.iosOrange)
            }
            VStack(spacing: 6) {
                Text("KFZ Kosten")
                    .font(.subheadline).foregroundColor(.primary)
                Text("Werkstatt, Leasing, Benzin und weitere Kosten erfassen")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                Button { showScanner = true } label: {
                    Label("Scannen", systemImage: "doc.viewfinder.fill")
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Color.iosOrange).foregroundColor(.white)
                        .clipShape(Capsule())
                }
                Button { showAdd = true } label: {
                    Label("Manuell", systemImage: "plus")
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Color(.tertiarySystemGroupedBackground)).foregroundColor(.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 16)
    }
}

// MARK: - Kategorie Detail Sheet
struct KFZKategorieDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager
    let kategorie: ReisespesenKategorie
    let items: [ReiseSpese]
    var mealAllowance: Double? = nil   // nur für .verpflegung gesetzt
    let onEdit: (ReiseSpese) -> Void
    let onDelete: (UUID) -> Void

    @State private var showAdd = false
    @State private var editItem: ReiseSpese?

    private var total: Double { items.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            List {
                // Summen-Header
                Section {
                    if let allowance = mealAllowance {
                        // ── Verpflegung Balance-Karte ──
                        let netto = allowance - total
                        VStack(spacing: 10) {
                            HStack {
                                Label("Ausgaben", systemImage: "fork.knife")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("−\(total.euroFormatted)")
                                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                            HStack {
                                Label("Verpflegungspauschale", systemImage: "eurosign.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("+\(allowance.euroFormatted)")
                                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                                    .foregroundColor(.iosGreen)
                            }
                            Divider()
                            HStack {
                                Text("Netto")
                                    .font(.subheadline)
                                    .fontWeight(.regular)
                                Spacer()
                                Text(netto >= 0
                                     ? "+\(netto.euroFormatted)"
                                     : "−\(abs(netto).euroFormatted)")
                                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                                    .foregroundColor(netto >= 0 ? .iosGreen : .red)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Label(kategorie.localizedName, systemImage: kategorie.icon)
                                .font(.subheadline)
                            Spacer()
                            Text(total.euroFormatted)
                                .font(.system(size: 17, weight: .regular, design: .monospaced))
                                .foregroundColor(.iosOrange)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Einträge
                Section(items.isEmpty ? "Keine Einträge" : "\(items.count) Einträge") {
                    if items.isEmpty {
                        Button {
                            showAdd = true
                        } label: {
                            Label("Ersten Eintrag hinzufügen", systemImage: "plus.circle")
                                .foregroundColor(.iosOrange)
                                .font(.subheadline)
                        }
                    } else {
                        ForEach(items) { spese in
                            KFZKostenRow(spese: spese)
                                .contentShape(Rectangle())
                                .onTapGesture { editItem = spese }
                                .dynamicSwipeActions(
                                    onDelete: { onDelete(spese.id) },
                                    onEdit: { editItem = spese }
                                )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(kategorie.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                KFZKostenFormView(mode: .add, defaultKategorie: kategorie)
                    .environmentObject(store)
                    .environmentObject(lm)
            }
            .sheet(item: $editItem) { spese in
                KFZKostenFormView(mode: .edit(spese))
                    .environmentObject(store)
                    .environmentObject(lm)
            }
        }
    }
}

// MARK: - KFZ Kosten Row
struct KFZKostenRow: View {
    let spese: ReiseSpese

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(rowColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: spese.kategorie.icon)
                    .foregroundColor(rowColor)
                    .font(.system(size: 15, weight: .regular))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(spese.title.isEmpty ? spese.kategorie.localizedName : spese.title)
                    .font(.system(size: 15, weight: .regular))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(spese.date.shortDateShort)
                    if !spese.note.isEmpty {
                        Text("·")
                        Text(spese.note).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Text(spese.amount.euroFormatted)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundColor(rowColor)
        }
        .padding(.vertical, 5)
    }

    private var rowColor: Color {
        switch spese.kategorie {
        case .werkstatt:       return .iosOrange
        case .leasing:         return .iosIndigo
        case .vignetteMaut:    return .blue
        case .benzin:          return Color(.systemRed)
        case .strom:           return .iosGreen
        case .kfzSteuer:       return .iosPurple
        case .kfzVersicherung: return .iosTeal
        case .verpflegung:     return .brown
        case .sonstiges:       return Color(.systemGray)
        }
    }
}

// MARK: - Form Mode
enum KFZKostenFormMode { case add; case edit(ReiseSpese) }

// MARK: - KFZ Kosten Form
struct KFZKostenFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore

    let mode: KFZKostenFormMode
    var defaultKategorie: ReisespesenKategorie = .sonstiges

    @State private var date       = Date()
    @State private var kategorie  : ReisespesenKategorie = .sonstiges
    @State private var title      = ""
    @State private var amountStr  = ""
    @State private var note       = ""
    @State private var showScanner = false

    private var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var editing: ReiseSpese? { if case .edit(let s) = mode { return s }; return nil }
    private var amount: Double { parseCurrency(amountStr) }
    private var isValid: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            Form {
                // ── Scan-Button oben ──
                Section {
                    Button {
                        showScanner = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.iosIndigo.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "doc.viewfinder.fill")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.iosIndigo)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Beleg scannen")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.iosIndigo)
                                Text("Kamera oder Foto – Daten werden automatisch erkannt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // ── Kategorie ──
                Section("Kategorie") {
                    HStack {
                        Label("Kategorie", systemImage: kategorie.icon)
                            .foregroundColor(.primary)
                        Spacer()
                        Menu {
                            ForEach(ReisespesenKategorie.allCases.filter { $0 != .verpflegung }, id: \.self) { k in
                                Button {
                                    kategorie = k
                                } label: {
                                    Label(k.localizedName, systemImage: k.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(kategorie.localizedName)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // ── Details ──
                Section("Details") {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)

                    HStack {
                        Label("Bezeichnung", systemImage: "text.alignleft")
                        Spacer()
                        TextField("Optional", text: $title)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Label("Betrag", systemImage: "eurosign.circle")
                        Spacer()
                        TextField("0,00", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("€").foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Notiz", systemImage: "note.text")
                        Spacer()
                        TextField("Optional", text: $note)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // ── Zusammenfassung ──
                if amount > 0 {
                    Section("Zusammenfassung") {
                        HStack {
                            Text("Betrag").fontWeight(.regular)
                            Spacer()
                            Text(amount.euroFormatted)
                                .font(.system(size: 18, weight: .regular, design: .monospaced))
                                .foregroundColor(.iosIndigo)
                        }
                    }
                }
            }
            .navigationTitle(isEdit ? "Bearbeiten" : (kategorie == .verpflegung ? "Neue Verpflegungsausgabe" : "Neue KFZ Kosten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? "Speichern" : "Hinzufügen") { save() }
                        .disabled(!isValid)
                        .fontWeight(.regular)
                }
            }
            .onAppear { prefill() }
            .sheet(isPresented: $showScanner) {
                ReceiptScannerView(target: .reiseSpese) { result in
                    // Formular vorausfüllen
                    if let d = result.suggestedDate { date = d }
                    if let a = result.suggestedAmount {
                        amountStr = String(format: "%.2f", a).replacingOccurrences(of: ".", with: ",")
                    }
                    if let n = result.suggestedName, !n.isEmpty { title = n }
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        if let s = editing {
            date      = s.date
            kategorie = s.kategorie
            title     = s.title
            amountStr = String(format: "%.2f", s.amount).replacingOccurrences(of: ".", with: ",")
            note      = s.note
        } else {
            kategorie = defaultKategorie
        }
    }

    private func save() {
        let spese = ReiseSpese(
            id: editing?.id ?? UUID(),
            date: date, kategorie: kategorie,
            title: title, amount: amount, note: note
        )
        if isEdit {
            store.updateReiseSpese(spese)
            AppLogger.shared.log("KFZ-Spese aktualisiert: \(kategorie.localizedName), \(amount.euroFormatted)", level: .store)
        } else {
            store.addReiseSpese(spese)
            AppLogger.shared.log("KFZ-Spese gespeichert: \(kategorie.localizedName), \(amount.euroFormatted)", level: .store)
        }
        dismiss()
    }
}

// MARK: - Fahrzeugwäsche Kachel
struct VehicleCostTilesSection: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager
    @State private var showWaescheForm = false

    let zeitFilter: ZeitFilter

    private let columns = [GridItem(.flexible())]

    private func inPeriod(_ date: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch zeitFilter {
        case .woche: return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .monat: return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .jahr:  return cal.isDate(date, equalTo: now, toGranularity: .year)
        }
    }

    private var waescheItems: [VehicleCost] {
        store.vehicleCosts.filter { $0.category == .fahrzeugwaesche && inPeriod($0.date) }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            // Fahrzeugwäsche
            Button { showWaescheForm = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.cyan)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Fahrzeugwäsche")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(waescheItems.isEmpty ? "Keine Einträge" : "\(waescheItems.count) Einträge")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if waescheItems.isEmpty {
                        Text("–")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text(waescheItems.reduce(0) { $0 + $1.amount }.euroFormatted)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(waescheItems.isEmpty ? Color.clear : Color.cyan.opacity(0.2), lineWidth: 1)
                )
                .opacity(waescheItems.isEmpty ? 0.5 : 1.0)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showWaescheForm) {
            FahrzeugwaescheFormView()
                .environmentObject(store)
                .environmentObject(lm)
        }
    }
}

// MARK: - Fahrzeugwäsche View (Liste + Hinzufügen)
struct FahrzeugwaescheFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @State private var showAdd = false
    @State private var editItem: VehicleCost?

    private var items: [VehicleCost] {
        store.vehicleCosts.filter { $0.category == .fahrzeugwaesche }
            .sorted(by: { $0.date > $1.date })
    }
    private var total: Double { items.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 36)).foregroundColor(.cyan.opacity(0.5))
                            Text("Keine Einträge").font(.subheadline)
                            Text("Tippe auf + um eine Fahrzeugwäsche zu erfassen.")
                                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        HStack {
                            Label("Gesamt", systemImage: "sparkles").foregroundColor(.cyan)
                            Spacer()
                            Text(total.euroFormatted)
                                .font(.system(size: 17, weight: .regular, design: .monospaced)).foregroundColor(.cyan)
                        }.padding(.vertical, 4)
                        .listRowBackground(Color.cyan.opacity(0.07))
                    }
                    Section("\(items.count) Einträge") {
                        ForEach(items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.date.shortDate).font(.system(size: 15, weight: .regular))
                                    if !item.note.isEmpty {
                                        Text(item.note).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(item.amount.euroFormatted)
                                    .font(.system(size: 15, weight: .regular, design: .monospaced)).foregroundColor(.cyan)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture { editItem = item }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { store.deleteVehicleCost(item.id) } label: {
                                    Label("Löschen", systemImage: "trash")
                                }.tint(.red)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Fahrzeugwäsche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Neuen Eintrag hinzufügen")
                }
            }
            .sheet(isPresented: $showAdd) {
                WaescheEntryFormView()
                    .environmentObject(store)
            }
            .sheet(item: $editItem) { item in
                WaescheEntryFormView(editItem: item)
                    .environmentObject(store)
            }
        }
    }
}

struct WaescheEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    var editItem: VehicleCost? = nil

    @State private var date      = Date()
    @State private var amountStr = ""
    @State private var note      = ""

    private var amount: Double { parseCurrency(amountStr) }
    private var isEdit: Bool { editItem != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                    HStack {
                        Label("Betrag", systemImage: "eurosign.circle")
                        Spacer()
                        TextField("0,00", text: $amountStr)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                        Text("€").foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Notiz", systemImage: "note.text")
                        Spacer()
                        TextField("Optional", text: $note).multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(isEdit ? "Eintrag bearbeiten" : "Fahrzeugwäsche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? "Speichern" : "Hinzufügen") {
                        let entry = VehicleCost(
                            id: editItem?.id ?? UUID(),
                            date: date, category: .fahrzeugwaesche,
                            title: "Fahrzeugwäsche", amount: amount, note: note
                        )
                        if isEdit { store.updateVehicleCost(entry) }
                        else      { store.addVehicleCost(entry) }
                        dismiss()
                    }
                    .disabled(amount <= 0).fontWeight(.regular)
                }
            }
            .onAppear {
                guard let e = editItem else { return }
                date = e.date
                amountStr = String(format: "%.2f", e.amount).replacingOccurrences(of: ".", with: ",")
                note = e.note
            }
        }
    }
}


// MARK: - Private Expense Form
enum PrivateExpenseFormMode { case add; case edit(PrivateExpense) }

struct PrivateExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    let mode: PrivateExpenseFormMode

    @State private var date      = Date()
    @State private var title     = ""
    @State private var amountStr = ""
    @State private var note      = ""

    private var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var editingItem: PrivateExpense? { if case .edit(let i) = mode { return i }; return nil }
    private var amount: Double { parseCurrency(amountStr) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    InfoBox(text: "Private Ausgaben werden NICHT in die Reisekostenerstattung einberechnet. Sie dienen nur der persönlichen Übersicht.")
                }
                Section("Private Ausgabe") {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                    HStack {
                        Label("Bezeichnung", systemImage: "text.alignleft")
                        Spacer()
                        TextField("z.B. Restaurant, Shopping", text: $title)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Betrag", systemImage: "eurosign.circle")
                        Spacer()
                        TextField("0,00", text: $amountStr)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                        Text("€").foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Notiz", systemImage: "note.text")
                        Spacer()
                        TextField("Optional", text: $note).multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(isEdit ? "Ausgabe bearbeiten" : "Private Ausgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? "Speichern" : "Hinzufügen") { save() }
                        .disabled(amount <= 0).fontWeight(.regular)
                }
            }
            .onAppear {
                guard let item = editingItem else { return }
                date = item.date; title = item.title
                amountStr = String(format: "%.2f", item.amount).replacingOccurrences(of: ".", with: ",")
                note = item.note
            }
        }
    }

    private func save() {
        let item = PrivateExpense(id: editingItem?.id ?? UUID(), date: date, title: title, amount: amount, note: note)
        if isEdit { store.updatePrivateExpense(item) } else { store.addPrivateExpense(item) }
        dismiss()
    }
}
