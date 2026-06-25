import SwiftUI

struct UebernachtungView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager
    @State private var showAdd      = false
    @State private var editHotel: HotelEntry?
    @State private var showSettings = false

    // ── Zeitraum-Filter ──
    enum HotelFilter: String, CaseIterable {
        case tag   = "Tag"
        case woche = "Woche"
        case monat = "Monat"
        case alle  = "Alle"
    }
    @AppStorage("uebernachtung.selectedFilter") private var selectedFilter: HotelFilter = .alle
    @State private var selectedDate: Date = Date()

    private var filteredHotels: [HotelEntry] {
        let cal = Calendar.current
        switch selectedFilter {
        case .alle:
            return store.hotels.sorted(by: { $0.date > $1.date })
        case .tag:
            return store.hotels
                .filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
                .sorted(by: { $0.date > $1.date })
        case .woche:
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: selectedDate)?.start else {
                return store.hotels.sorted(by: { $0.date > $1.date })
            }
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
            return store.hotels
                .filter { $0.date >= weekStart && $0.date < weekEnd }
                .sorted(by: { $0.date > $1.date })
        case .monat:
            return store.hotels
                .filter { cal.isDate($0.date, equalTo: selectedDate, toGranularity: .month) }
                .sorted(by: { $0.date > $1.date })
        }
    }

    private var filteredTotal: Double {
        filteredHotels.reduce(0) { $0 + $1.amount(flat: store.hotelFlat) }
    }

    private var filterLabel: String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        switch selectedFilter {
        case .alle:   return lm.t("hotel.title")
        case .tag:
            if cal.isDateInToday(selectedDate) { return "Heute" }
            fmt.dateStyle = .medium; fmt.timeStyle = .none
            return fmt.string(from: selectedDate)
        case .woche:
            guard let interval = cal.dateInterval(of: .weekOfYear, for: selectedDate) else { return "Diese Woche" }
            let end = cal.date(byAdding: .day, value: 6, to: interval.start)!
            fmt.dateFormat = "d. MMM"
            return "\(fmt.string(from: interval.start)) – \(fmt.string(from: end))"
        case .monat:
            fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: selectedDate)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.hotels.isEmpty {
                    Section { emptyState }
                } else {
                    // ── Zeitraum-Filter ──
                    Section {
                        VStack(spacing: 10) {
                            FilterChipBar(selection: $selectedFilter)
                                .padding(.vertical, 2)

                            if selectedFilter != .alle {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.iosPurple)
                                        .font(.system(size: 15, weight: .regular))
                                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                    Spacer()
                                    Button {
                                        withOptionalAnimation(.easeInOut(duration: 0.2)) { selectedDate = Date() }
                                    } label: {
                                        Text("Heute")
                                            .font(.caption)
                                            .foregroundColor(.iosPurple)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.iosPurple.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }

                    // ── Header-Karte ──
                    Section {
                        ListHeaderCard(
                            icon: "bed.double.fill",
                            color: .iosPurple,
                            title: filterLabel,
                            countLabel: "\(filteredHotels.count) \(lm.t("hotel.unit"))",
                            total: filteredTotal
                        )
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }

                    // ── Einträge ──
                    if filteredHotels.isEmpty {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("Keine Einträge im gewählten Zeitraum")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 20)
                                Spacer()
                            }
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                        }
                    } else {
                        Section(filterLabel) {
                            ForEach(filteredHotels) { hotel in
                                HotelRow(hotel: hotel, hotelFlat: store.hotelFlat)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editHotel = hotel }
                                    .dynamicSwipeActions(
                                        onDelete: { store.deleteHotel(hotel.id) },
                                        onEdit: { editHotel = hotel },
                    onDuplicate: { store.duplicateHotel(hotel) }
                                    )
                                    .contextMenu {
                                        Button { editHotel = hotel } label: {
                                            Label(lm.t("action.edit"), systemImage: "pencil")
                                        }
                                        Button {
                                            store.duplicateHotel(hotel)
                                        } label: {
                                            Label("Eintrag duplizieren", systemImage: "doc.on.doc")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            store.deleteHotel(hotel.id)
                                        } label: {
                                            Label(lm.t("action.delete"), systemImage: "trash")
                                        }.tint(.red)
                                    }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(lm.t("hotel.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showAdd = true } label: {
                            Label("Neuer Eintrag", systemImage: "plus")
                        }
                        Divider()
                        Button { showSettings = true } label: {
                            Label("Einstellungen", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { EinstellungenView() }
            .sheet(isPresented: $showAdd)      { HotelFormView(mode: .add) }
            .sheet(item: $editHotel) { h in    HotelFormView(mode: .edit(h)) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.iosPurple.opacity(0.1)).frame(width: 64, height: 64)
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 26, weight: .regular)).foregroundColor(.iosPurple)
            }
            VStack(spacing: 6) {
                Text(lm.t("hotel.add")).font(.subheadline).foregroundColor(.primary)
                Text(lm.t("hotel.add.hint")).font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                Button { showAdd = true } label: {
                    Label("Scannen", systemImage: "doc.viewfinder.fill")
                        .font(.system(size: 16, weight: .regular))
                        .padding(.horizontal, 22).padding(.vertical, 13)
                        .background(Color.iosOrange).foregroundColor(.white).clipShape(Capsule())
                }
                Button { showAdd = true } label: {
                    Label("Manuell", systemImage: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .padding(.horizontal, 22).padding(.vertical, 13)
                        .background(Color(red: 0.20, green: 0.40, blue: 0.65)).foregroundColor(.white).clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
    }
}

// MARK: - Hotel Row
struct HotelRow: View {
    @EnvironmentObject var lm: LocalizationManager
    let hotel: HotelEntry
    let hotelFlat: Double

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.iosPurple.opacity(0.11)).frame(width: 36, height: 36)
                Image(systemName: "bed.double.fill")
                    .foregroundColor(.iosPurple).font(.system(size: 15, weight: .regular))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(hotel.date.shortDate).font(.system(size: 15, weight: .regular))
                HStack(spacing: 4) {
                    if !hotel.city.isEmpty     { Text(hotel.city) }
                    if !hotel.hotelName.isEmpty {
                        if !hotel.city.isEmpty { Text("·") }
                        Text(hotel.hotelName)
                    }
                    if hotel.city.isEmpty && hotel.hotelName.isEmpty { Text(hotel.mode.localizedName) }
                    if hotel.numberOfNights > 1 {
                        Text("·")
                        Text("\(hotel.numberOfNights) Nächte")
                    }
                }
                .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(hotel.amount(flat: hotelFlat).euroFormatted)
                    .font(.system(size: 15, weight: .regular, design: .monospaced)).foregroundColor(.iosPurple)
                HStack(spacing: 3) {
                    Text(hotel.mode == .flat ? lm.t("hotel.flat.badge") : lm.t("hotel.actual.badge"))
                        .font(.system(size: 10, weight: .regular))
                    if hotel.numberOfNights > 1 {
                        Text("· \(hotel.numberOfNights)×")
                            .font(.system(size: 10, weight: .regular))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.iosPurple.opacity(0.7)).clipShape(Capsule())
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Hotel Form
enum HotelFormMode { case add; case edit(HotelEntry) }

struct HotelFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager

    let mode: HotelFormMode

    @State private var checkInDate   = Date()
    @State private var checkOutDate  = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var city          = ""
    @State private var hotelName     = ""
    @State private var hotelMode     = HotelMode.flat
    @State private var costString    = ""
    @State private var showScanner   = false
    @State private var showDateRange = false

    private var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var editingHotel: HotelEntry? { if case .edit(let h) = mode { return h }; return nil }
    private var actualCost: Double { parseCurrency(costString) }
    private var numberOfNights: Int {
        let days = Calendar.current.dateComponents([.day], from: checkInDate, to: checkOutDate).day ?? 1
        return max(1, days)
    }
    private var amount: Double {
        hotelMode == .flat ? store.hotelFlat * Double(numberOfNights) : actualCost
    }
    private var overFlat: Bool {
        hotelMode == .actual && actualCost > store.hotelFlat * Double(numberOfNights)
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Scan-Shortcut ──
                Section {
                    Button { showScanner = true } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.iosPurple.opacity(0.12)).frame(width: 32, height: 32)
                                Image(systemName: "doc.viewfinder.fill")
                                    .font(.system(size: 14, weight: .regular)).foregroundColor(.iosPurple)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rechnung scannen")
                                    .font(.system(size: 15, weight: .regular)).foregroundColor(.iosPurple)
                                Text("Datum, Hotelname, Betrag & Nächte automatisch erkennen")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rechnung scannen")
                    .accessibilityHint("Öffnet Kamera oder Fotoauswahl, Datum, Hotelname und Betrag werden automatisch erkannt")
                }

                // ── Aufenthaltszeitraum (NEU) ──
                Section("Aufenthalt") {
                    // Check-in
                    DatePicker("Check-in", selection: $checkInDate, displayedComponents: .date)
                        .onChange(of: checkInDate) { _, newIn in
                            // Check-out darf nicht vor Check-in liegen
                            if checkOutDate <= newIn {
                                checkOutDate = Calendar.current.date(byAdding: .day, value: 1, to: newIn) ?? newIn
                            }
                        }
                    // Check-out
                    DatePicker("Check-out", selection: $checkOutDate,
                               in: Calendar.current.date(byAdding: .day, value: 1, to: checkInDate)!...,
                               displayedComponents: .date)

                    // Nächteanzahl als Info-Zeile
                    HStack {
                        Label("Anzahl Nächte", systemImage: "moon.fill")
                            .foregroundColor(.iosPurple)
                        Spacer()
                        Text("\(numberOfNights) \(numberOfNights == 1 ? "Nacht" : "Nächte")")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.iosPurple)
                    }
                }

                // ── Hoteldetails ──
                Section(lm.t("hotel.section")) {
                    HStack {
                        Label(lm.t("hotel.city"), systemImage: "building.2.fill")
                        Spacer()
                        TextField(lm.t("hotel.city.placeholder"), text: $city)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label(lm.t("hotel.name"), systemImage: "bed.double.fill")
                        Spacer()
                        TextField(lm.t("common.optional"), text: $hotelName)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // ── Abrechnung ──
                Section(lm.t("hotel.billing")) {
                    Picker(lm.t("hotel.type"), selection: $hotelMode) {
                        ForEach(HotelMode.allCases, id: \.self) { m in Text(m.localizedName).tag(m) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                    if hotelMode == .actual {
                        HStack {
                            Label("Rechnungsbetrag (Gesamt, inkl. MwSt)", systemImage: "eurosign.circle")
                            Spacer()
                            TextField("0,00", text: $costString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }

                // ── Erstattung ──
                Section(lm.t("hotel.reimbursement")) {
                    if hotelMode == .flat {
                        LabeledRow(
                            label: "\(store.hotelFlat.euroFormatted) × \(numberOfNights) Nächte",
                            value: ""
                        )
                        HStack {
                            Text(lm.t("hotel.flat.label")).fontWeight(.regular)
                            Spacer()
                            Text(amount.euroFormatted)
                                .font(.system(size: 18, weight: .regular, design: .monospaced))
                                .foregroundColor(.iosGreen)
                        }
                    } else {
                        LabeledRow(label: "Rechnungsbetrag gesamt", value: actualCost.euroFormatted)
                        LabeledRow(
                            label: "Pro Nacht",
                            value: numberOfNights > 0
                                ? (actualCost / Double(numberOfNights)).euroFormatted
                                : "-"
                        )
                        if overFlat {
                            LabeledRow(
                                label: String(format: lm.t("hotel.over.flat"),
                                              (store.hotelFlat * Double(numberOfNights)).euroFormatted),
                                value: "+ \((actualCost - store.hotelFlat * Double(numberOfNights)).euroFormatted)",
                                valueColor: .iosOrange
                            )
                        }
                        HStack {
                            Text(lm.t("hotel.reimbursement")).fontWeight(.regular)
                            Spacer()
                            Text(amount.euroFormatted)
                                .font(.system(size: 18, weight: .regular, design: .monospaced))
                                .foregroundColor(.iosGreen)
                        }
                    }
                }

                Section {
                    InfoBox(text: String(format: lm.t("hotel.info"), store.hotelFlat.euroFormatted))
                }
            }
            .navigationTitle(isEdit ? lm.t("hotel.form.edit") : lm.t("hotel.form.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lm.t("action.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? lm.t("action.save") : lm.t("action.add")) { save() }
                        .fontWeight(.regular)
                }
            }
            .onAppear { prefill() }
            .sheet(isPresented: $showScanner) {
                ReceiptScannerView(target: .hotel) { result in
                    // Check-in Datum: bevorzuge Anreise-Zeile, fallback auf Rechnungsdatum
                    let lines = result.rawText.components(separatedBy: "\n")
                    if let anreise = ReceiptParser.extractCheckInDate(from: lines) {
                        checkInDate = anreise
                    } else if let d = result.suggestedDate {
                        checkInDate = d
                    }
                    if let n = result.suggestedName   { hotelName = n }
                    if let c = result.suggestedCity   { city = c }
                    if let a = result.suggestedAmount {
                        hotelMode  = .actual
                        costString = String(format: "%.2f", a).replacingOccurrences(of: ".", with: ",")
                    }
                    // Nächte aus OCR → Check-out berechnen
                    if let nights = result.suggestedNights, nights > 0 {
                        checkOutDate = Calendar.current.date(byAdding: .day, value: nights, to: checkInDate) ?? checkInDate
                    }
                }
            }
        }
    }

    private func prefill() {
        guard let h = editingHotel else { return }
        checkInDate  = h.date
        checkOutDate = h.checkOutDate
            ?? Calendar.current.date(byAdding: .day, value: h.numberOfNights, to: h.date)
            ?? h.date
        city         = h.city
        hotelName    = h.hotelName
        hotelMode    = h.mode
        if h.mode == .actual {
            costString = String(format: "%.2f", h.actualCost).replacingOccurrences(of: ".", with: ",")
        }
    }

    private func save() {
        let entry = HotelEntry(
            id: editingHotel?.id ?? UUID(),
            date: checkInDate,
            checkOutDate: checkOutDate,
            city: city, hotelName: hotelName,
            mode: hotelMode,
            actualCost: actualCost,
            numberOfNights: numberOfNights
        )
        if isEdit { store.updateHotel(entry) } else { store.addHotel(entry) }
        dismiss()
    }
}
