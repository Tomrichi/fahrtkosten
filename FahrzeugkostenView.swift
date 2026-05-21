import SwiftUI

// MARK: - Fahrzeugkosten List
struct FahrzeugkostenView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager
    @State private var showAdd   = false
    @State private var editCost: VehicleCost?
    @State private var zeitFilter: ZeitFilter = .monat

    private var filteredCosts: [VehicleCost] {
        store.vehicleCosts.filter { inPeriod($0.date) }
    }

    private func inPeriod(_ date: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch zeitFilter {
        case .woche: return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .monat: return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .jahr:  return cal.isDate(date, equalTo: now, toGranularity: .year)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Zeitraum-Filter Chips ──
                Section {
                    FilterChipBar(selection: $zeitFilter)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                if filteredCosts.isEmpty {
                    Section {
                        emptyState
                    }
                } else {
                    // ── Header-Karte ──
                    Section {
                        ListHeaderCard(
                            icon: "wrench.and.screwdriver.fill",
                            color: .iosOrange,
                            title: lm.t("vehicle.title"),
                            countLabel: "\(filteredCosts.count) \(lm.t("vehicle.unit"))",
                            total: filteredCosts.reduce(0) { $0 + $1.amount }
                        )
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }

                    // ── Einträge nach Kategorie ──
                    let grouped = Dictionary(
                        grouping: filteredCosts.sorted(by: { $0.date > $1.date }),
                        by: { $0.category }
                    )
                    ForEach(VehicleCostCategory.allCases, id: \.self) { cat in
                        if let items = grouped[cat], !items.isEmpty {
                            Section(cat.localizedName) {
                                ForEach(items) { cost in
                                    VehicleCostRow(cost: cost)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            AppLogger.shared.logTap("KFZ-Kosten bearbeiten: \(cost.category.localizedName) \(cost.amount.euroFormatted)")
                                            editCost = cost
                                        }
                                        .dynamicSwipeActions(
                                        onDelete: {
                                            AppLogger.shared.logTap("KFZ-Kosten gelöscht: \(cost.category.localizedName) \(cost.amount.euroFormatted)")
                                            store.deleteVehicleCost(cost.id)
                                        },
                                        onEdit: { editCost = cost }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(lm.t("vehicle.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        AppLogger.shared.logTap("KFZ-Kosten: Neuer Eintrag")
                        showAdd = true
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd)  { VehicleCostFormView(mode: .add) }
            .sheet(item: $editCost) { c in  VehicleCostFormView(mode: .edit(c)) }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.iosOrange.opacity(0.1))
                    .frame(width: 64, height: 64)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(.iosOrange)
            }
            VStack(spacing: 6) {
                Text(lm.t("vehicle.add"))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(lm.t("vehicle.add.hint"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                AppLogger.shared.logTap("KFZ-Kosten: Erster Eintrag hinzufügen")
                showAdd = true
            } label: {
                Label("Eintrag hinzufügen", systemImage: "plus")
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(Color.iosOrange)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
    }
}

// MARK: - Fahrzeugkosten Row
struct VehicleCostRow: View {
    @EnvironmentObject var lm: LocalizationManager

    let cost: VehicleCost

    var body: some View {
        HStack(spacing: 12) {
            // Kleineres Icon (36 statt 44)
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(categoryColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: cost.category.icon)
                    .foregroundColor(categoryColor)
                    .font(.system(size: 15, weight: .regular))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(cost.title.isEmpty ? cost.category.localizedName : cost.title)
                    .font(.system(size: 15, weight: .regular))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(cost.date.shortDateShort)
                    if let km = cost.mileage {
                        Text("·")
                        Text("\(km) km")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                if !cost.note.isEmpty {
                    Text(cost.note).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(cost.amount.euroFormatted)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundColor(categoryColor)
        }
        .padding(.vertical, 5)
    }

    private var categoryColor: Color {
        switch cost.category {
        case .werkstatt:       return .iosOrange
        case .leasing:         return .iosIndigo
        case .versicherung:    return .blue
        case .tuvHu:           return .iosGreen
        case .steuer:          return .iosPurple
        case .reifen:          return .iosTeal
        case .strom:           return .yellow
        case .fahrzeugwaesche: return Color(red: 0.0, green: 0.8, blue: 0.9)
        case .sonstiges:       return Color(.systemGray)
        }
    }
}

// MARK: - Form Mode
enum VehicleCostFormMode { case add; case edit(VehicleCost) }

// MARK: - Ausstehende Beleg-Position (für Multi-Scan Review)
struct PendingVehicleItem: Identifiable {
    var id         = UUID()
    var category   : VehicleCostCategory
    var title      : String
    var amountStr  : String
    var date       : Date
    var amount: Double { parseCurrency(amountStr) }
}

// MARK: - Fahrzeugkosten Form
struct VehicleCostFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager

    let mode: VehicleCostFormMode

    @State private var date           = Date()
    @State private var category       : VehicleCostCategory = .werkstatt
    @State private var title          = ""
    @State private var amountStr      = ""
    @State private var note           = ""
    @State private var mileageStr     = ""
    @State private var showScanner    = false
    @State private var showMultiReview = false
    @State private var pendingItems   : [PendingVehicleItem] = []

    private var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var editingCost: VehicleCost? { if case .edit(let c) = mode { return c }; return nil }
    private var amount: Double { parseCurrency(amountStr) }
    private var mileage: Int? { Int(mileageStr.filter(\.isNumber)).flatMap { $0 > 0 ? $0 : nil } }
    private var isValid: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            Form {
                // ── Beleg scannen ──
                if !isEdit {
                    Section {
                        Button { showScanner = true } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.iosOrange.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "doc.viewfinder.fill")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.iosOrange)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Beleg scannen")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.iosOrange)
                                    Text("Positionen, Kategorien und Beträge automatisch erkennen")
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
                }

                // ── Kategorie ──
                Section(lm.t("vehicle.category.section")) {
                    Picker(lm.t("vehicle.category.section"), selection: $category) {
                        ForEach(VehicleCostCategory.allCases, id: \.self) { cat in
                            Label(cat.localizedName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // ── Details ──
                Section(lm.t("vehicle.details")) {
                    DatePicker(lm.t("common.date"), selection: $date, displayedComponents: .date)

                    HStack {
                        Label(lm.t("vehicle.title.label"), systemImage: "text.alignleft")
                        Spacer()
                        TextField(lm.t("common.optional"), text: $title)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Label(lm.t("common.amount"), systemImage: "eurosign.circle")
                        Spacer()
                        TextField("0,00", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("€").foregroundColor(.secondary)
                    }

                    HStack {
                        Label(lm.t("vehicle.mileage"), systemImage: "speedometer")
                        Spacer()
                        TextField(lm.t("common.optional"), text: $mileageStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("km").foregroundColor(.secondary)
                    }

                    HStack {
                        Label(lm.t("common.note"), systemImage: "note.text")
                        Spacer()
                        TextField(lm.t("common.optional"), text: $note)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // ── Zusammenfassung ──
                if amount > 0 {
                    Section(lm.t("vehicle.summary")) {
                        LabeledRow(label: lm.t("vehicle.category.section"), value: category.localizedName)
                        HStack {
                            Text(lm.t("common.amount")).fontWeight(.regular)
                            Spacer()
                            Text(amount.euroFormatted)
                                .font(.system(size: 18, weight: .regular, design: .monospaced))
                                .foregroundColor(.iosOrange)
                        }
                    }
                }
            }
            .navigationTitle(isEdit ? lm.t("vehicle.form.edit") : lm.t("vehicle.form.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lm.t("action.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? lm.t("action.save") : lm.t("action.add")) { save() }
                        .disabled(!isValid)
                        .fontWeight(.regular)
                }
            }
            .onAppear { prefill() }
            .sheet(isPresented: $showScanner) {
                ReceiptScannerView(target: .vehicleCost) { result in
                    applyResult(result)
                }
            }
            .sheet(isPresented: $showMultiReview) {
                VehicleCostMultiItemReview(items: $pendingItems) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Scan-Ergebnis verarbeiten
    private func applyResult(_ result: ReceiptScanResult) {
        if let d = result.suggestedDate { date = d }

        if let items = result.lineItems, items.count >= 2 {
            // Mehrere Positionen → kurz warten bis Scanner-Sheet weg, dann Review öffnen
            pendingItems = items.map {
                PendingVehicleItem(
                    category: $0.suggestedCategory,
                    title:    $0.description,
                    amountStr: String(format: "%.2f", $0.amount).replacingOccurrences(of: ".", with: ","),
                    date:     result.suggestedDate ?? Date()
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showMultiReview = true
            }
        } else {
            // Einzelne Position oder Gesamtbetrag → Formular befüllen
            if let item = result.lineItems?.first {
                category  = item.suggestedCategory
                title     = item.description
                amountStr = String(format: "%.2f", item.amount).replacingOccurrences(of: ".", with: ",")
            } else {
                if let a = result.suggestedAmount {
                    amountStr = String(format: "%.2f", a).replacingOccurrences(of: ".", with: ",")
                }
                if let n = result.suggestedName, title.isEmpty { title = n }
            }
        }
    }

    private func prefill() {
        guard let c = editingCost else { return }
        date       = c.date
        category   = c.category
        title      = c.title
        amountStr  = String(format: "%.2f", c.amount).replacingOccurrences(of: ".", with: ",")
        note       = c.note
        mileageStr = c.mileage.map { String($0) } ?? ""
    }

    private func save() {
        let cost = VehicleCost(
            id: editingCost?.id ?? UUID(),
            date: date, category: category,
            title: title, amount: amount,
            note: note, mileage: mileage
        )
        if isEdit {
            store.updateVehicleCost(cost)
            AppLogger.shared.log("KFZ-Kosten aktualisiert: \(category.localizedName), \(amount.euroFormatted)", level: .store)
        } else {
            store.addVehicleCost(cost)
            AppLogger.shared.log("KFZ-Kosten gespeichert: \(category.localizedName), \(amount.euroFormatted)", level: .store)
        }
        dismiss()
    }
}

// MARK: - Multi-Positionen Review Sheet
struct VehicleCostMultiItemReview: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager

    @Binding var items: [PendingVehicleItem]
    var onSaved: () -> Void

    private var totalAmount: Double { items.reduce(0) { $0 + $1.amount } }
    private var allValid: Bool { items.allSatisfy { $0.amount > 0 } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("\(items.count) Positionen erkannt")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(totalAmount.euroFormatted)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.iosOrange)
                    }
                }

                Section("Positionen prüfen & anpassen") {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 10) {
                            // Kategorie
                            Picker("", selection: $item.category) {
                                ForEach(VehicleCostCategory.allCases, id: \.self) { cat in
                                    Label(cat.localizedName, systemImage: cat.icon).tag(cat)
                                }
                            }
                            .pickerStyle(.navigationLink)

                            // Bezeichnung
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Bezeichnung", text: $item.title)
                                    .font(.system(size: 15))
                            }

                            // Betrag
                            HStack {
                                Image(systemName: "eurosign.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("0,00", text: $item.amountStr)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 15, design: .monospaced))
                                Spacer()
                                Text("€").foregroundColor(.secondary)
                            }

                            // Datum
                            DatePicker("Datum", selection: $item.date, displayedComponents: .date)
                                .font(.system(size: 14))
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indices in items.remove(atOffsets: indices) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Positionen prüfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Alle speichern") {
                        for item in items where item.amount > 0 {
                            store.addVehicleCost(VehicleCost(
                                date:     item.date,
                                category: item.category,
                                title:    item.title,
                                amount:   item.amount,
                                note:     "Via Beleg-Scan",
                                mileage:  nil
                            ))
                            AppLogger.shared.log(
                                "KFZ-Scan gespeichert: \(item.category.localizedName), \(item.amount.euroFormatted)",
                                level: .store
                            )
                        }
                        onSaved()
                        dismiss()
                    }
                    .disabled(items.isEmpty || !allValid)
                    .fontWeight(.regular)
                }
            }
        }
    }
}
