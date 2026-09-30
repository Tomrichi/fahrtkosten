import SwiftUI

enum ExportGranularitaet: String, CaseIterable {
    case tag   = "Tag"
    case monat = "Monat"
    case jahr  = "Jahr"
}

// MARK: - PDF Export Datumswahl Sheet
struct PDFExportDatePickerSheet: View {
    @Binding var selectedDate: Date
    let zeitFilter: ZeitFilter
    let onExport: (Date, ExportGranularitaet) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var granularitaet: ExportGranularitaet = .monat
    @State private var selectedMonth: Int
    @State private var selectedYear: Int

    private let calendar = Calendar.current
    private let currentYear = Calendar.current.component(.year, from: Date())

    init(selectedDate: Binding<Date>, zeitFilter: ZeitFilter, onExport: @escaping (Date, ExportGranularitaet) -> Void) {
        self._selectedDate = selectedDate
        self.zeitFilter = zeitFilter
        self.onExport = onExport
        let now = Date()
        let cal = Calendar.current
        self._selectedMonth = State(initialValue: cal.component(.month, from: now))
        self._selectedYear  = State(initialValue: cal.component(.year,  from: now))
    }

    private var years: [Int] {
        Array((currentYear - 5)...currentYear).reversed()
    }

    private let monthNames: [String] = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        return (1...12).map { fmt.monthSymbols[$0 - 1].capitalized }
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                // Icon + Titel
                VStack(spacing: 6) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                    Text("PDF exportieren")
                        .font(.title3.bold())
                }
                .padding(.top, 8)

                Divider()

                // Granularität wählen
                VStack(spacing: 8) {
                    Text("Zeitraum-Art")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    Picker("Zeitraum-Art", selection: $granularitaet) {
                        ForEach(ExportGranularitaet.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                Divider()

                // Datum wählen je nach Granularität
                switch granularitaet {
                case .tag:
                    dayPicker
                case .monat:
                    monthYearPicker
                case .jahr:
                    yearPicker
                }

                Spacer()

                // Export Button
                Button {
                    let date = buildDate()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onExport(date, granularitaet)
                    }
                } label: {
                    Label("PDF erstellen", systemImage: "doc.richtext.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .font(.headline)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("PDF Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    // MARK: - Tag Picker
    private var dayPicker: some View {
        VStack(spacing: 8) {
            Text("Tag wählen")
                .font(.caption).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            DatePicker("Datum", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal)
        }
    }

    // MARK: - Monat + Jahr Picker
    private var monthYearPicker: some View {
        VStack(spacing: 8) {
            Text("Monat und Jahr wählen")
                .font(.caption).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            HStack(spacing: 0) {
                Picker("Monat", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { Text(monthNames[$0 - 1]).tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Jahr", selection: $selectedYear) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Nur Jahr Picker
    private var yearPicker: some View {
        VStack(spacing: 8) {
            Text("Jahr wählen")
                .font(.caption).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            Picker("Jahr", selection: $selectedYear) {
                ForEach(years, id: \.self) { Text(String($0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .padding(.horizontal)
        }
    }

    // MARK: - Datum aus Picker-Werten bauen
    private func buildDate() -> Date {
        switch granularitaet {
        case .tag:
            return selectedDate
        case .monat:
            var c = DateComponents()
            c.year = selectedYear; c.month = selectedMonth; c.day = 1
            return calendar.date(from: c) ?? Date()
        case .jahr:
            var c = DateComponents()
            c.year = selectedYear; c.month = 1; c.day = 1
            return calendar.date(from: c) ?? Date()
        }
    }
}
