import SwiftUI

// MARK: - Wiederkehrende Fahrten Verwaltung
struct RecurringTripManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager

    @State private var showAdd   = false
    @State private var editTrip: RecurringTrip?

    var body: some View {
        NavigationStack {
            List {
                if store.recurringTrips.isEmpty {
                    emptyState
                } else {
                    ForEach(store.recurringTrips) { trip in
                        RecurringTripRow(trip: trip)
                            .contentShape(Rectangle())
                            .onTapGesture { editTrip = trip }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deleteRecurringTrip(trip.id)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    store.toggleRecurringTrip(trip.id)
                                } label: {
                                    Label(trip.isActive ? "Pausieren" : "Aktivieren",
                                          systemImage: trip.isActive ? "pause.circle" : "play.circle")
                                }
                                .tint(trip.isActive ? .orange : .green)
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Wiederkehrende Fahrten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                RecurringTripFormView(mode: .add)
                    .environmentObject(store)
            }
            .sheet(item: $editTrip) { trip in
                RecurringTripFormView(mode: .edit(trip))
                    .environmentObject(store)
            }
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 14) {
                Image(systemName: "repeat.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.purple.opacity(0.6))
                Text("Keine wiederkehrenden Fahrten")
                    .font(.subheadline)
                Text("Speichere häufige Routen mit Wochentagen – sie erscheinen automatisch als Vorschlag beim Anlegen einer neuen Fahrt.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button { showAdd = true } label: {
                    Label("Erste Route anlegen", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .listRowBackground(Color.clear)
        }
    }
}

// MARK: - Row
struct RecurringTripRow: View {
    let trip: RecurringTrip

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(trip.isActive ? Color.purple.opacity(0.12) : Color(.systemGray5))
                    .frame(width: 40, height: 40)
                Image(systemName: "repeat.circle.fill")
                    .foregroundColor(trip.isActive ? .purple : .secondary)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(trip.from) → \(trip.to)")
                    .font(.system(size: 15))
                    .foregroundColor(trip.isActive ? .primary : .secondary)
                HStack(spacing: 6) {
                    Text(trip.km.kmFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(trip.weekdayLabel)
                        .font(.caption)
                        .foregroundColor(trip.isActive ? .purple : .secondary)
                    if !trip.note.isEmpty {
                        Text("· \(trip.note)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            if !trip.isActive {
                Text("Pausiert")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.6))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        .opacity(trip.isActive ? 1.0 : 0.6)
    }
}

// MARK: - Form
enum RecurringTripFormMode { case add; case edit(RecurringTrip) }

struct RecurringTripFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore

    let mode: RecurringTripFormMode

    @State private var from     = ""
    @State private var to       = ""
    @State private var kmString = ""
    @State private var note     = ""
    @State private var weekdays : Set<Int> = [2, 3, 4, 5, 6]  // Mo–Fr default
    @State private var isActive = true

    private var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var editingTrip: RecurringTrip? { if case .edit(let t) = mode { return t }; return nil }
    private var isValid: Bool { !from.isEmpty && !to.isEmpty && kmValue > 0 && !weekdays.isEmpty }
    private var kmValue: Double { Double(kmString.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    // Wochentage: 1=So 2=Mo 3=Di 4=Mi 5=Do 6=Fr 7=Sa
    private let allWeekdays: [(Int, String)] = [
        (2, "Mo"), (3, "Di"), (4, "Mi"), (5, "Do"), (6, "Fr"), (7, "Sa"), (1, "So")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Route") {
                    HStack {
                        Label("Von", systemImage: "mappin.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        TextField("Startort", text: $from)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Nach", systemImage: "mappin.circle.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        TextField("Zielort", text: $to)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Kilometer", systemImage: "road.lanes")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField("0", text: $kmString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("km").foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Notiz", systemImage: "note.text")
                        Spacer()
                        TextField("Optional", text: $note)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    // Wochentag-Auswahl als Toggle-Chips
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(allWeekdays, id: \.0) { (wd, name) in
                            let selected = weekdays.contains(wd)
                            Button {
                                if selected { weekdays.remove(wd) } else { weekdays.insert(wd) }
                            } label: {
                                Text(name)
                                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selected ? Color.purple : Color(.systemGray5))
                                    .foregroundColor(selected ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Wochentage")
                } footer: {
                    Text("Fahrt erscheint als Vorschlag wenn der Wochentag übereinstimmt.")
                }

                if isEdit {
                    Section {
                        Toggle("Aktiv", isOn: $isActive)
                            .tint(.purple)
                    }
                }
            }
            .navigationTitle(isEdit ? "Fahrt bearbeiten" : "Neue Wiederholung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? "Sichern" : "Hinzufügen") { save() }
                        .disabled(!isValid)
                        .fontWeight(.regular)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        guard let t = editingTrip else { return }
        from     = t.from
        to       = t.to
        kmString = String(format: "%.1f", t.km)
        note     = t.note
        weekdays = Set(t.weekdays)
        isActive = t.isActive
    }

    private func save() {
        let trip = RecurringTrip(
            id:       editingTrip?.id ?? UUID(),
            from:     from,
            to:       to,
            km:       kmValue,
            weekdays: Array(weekdays).sorted(),
            note:     note,
            isActive: isActive
        )
        if isEdit {
            store.updateRecurringTrip(trip)
        } else {
            store.addRecurringTrip(trip)
        }
        dismiss()
    }
}
