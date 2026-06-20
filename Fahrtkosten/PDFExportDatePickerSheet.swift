import SwiftUI

// MARK: - PDF Export Datumswahl Sheet
struct PDFExportDatePickerSheet: View {
    @Binding var selectedDate: Date
    let zeitFilter: ZeitFilter
    let onExport: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    // Für Monatspicker: Monat + Jahr separat
    @State private var selectedMonth: Int
    @State private var selectedYear: Int

    private let calendar = Calendar.current
    private let currentYear = Calendar.current.component(.year, from: Date())

    init(selectedDate: Binding<Date>, zeitFilter: ZeitFilter, onExport: @escaping (Date) -> Void) {
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
        return (1...12).map { month in
            fmt.monthSymbols[month - 1].capitalized
        }
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // Icon + Titel
                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Zeitraum für PDF wählen")
                        .font(.title3.bold())
                    Text("Wähle den \(zeitFilter.rawValue), den du exportieren möchtest.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 8)

                Divider()

                // Picker je nach Zeitfilter
                switch zeitFilter {
                case .monat:
                    monthYearPicker
                case .jahr:
                    yearPicker
                case .woche:
                    weekPicker
                }

                Spacer()

                // Export Button
                Button {
                    let date = buildDate()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onExport(date)
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

    // MARK: - Monat + Jahr Picker
    private var monthYearPicker: some View {
        HStack(spacing: 0) {
            // Monats-Picker
            Picker("Monat", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(monthNames[month - 1]).tag(month)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            // Jahr-Picker
            Picker("Jahr", selection: $selectedYear) {
                ForEach(years, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }

    // MARK: - Nur Jahr Picker
    private var yearPicker: some View {
        Picker("Jahr", selection: $selectedYear) {
            ForEach(years, id: \.self) { year in
                Text(String(year)).tag(year)
            }
        }
        .pickerStyle(.wheel)
        .padding(.horizontal)
    }

    // MARK: - Woche Picker (DatePicker)
    private var weekPicker: some View {
        VStack(spacing: 12) {
            Text("Wähle ein Datum in der gewünschten Woche:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            DatePicker(
                "Datum",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
        }
    }

    // MARK: - Datum aus Picker-Werten bauen
    private func buildDate() -> Date {
        switch zeitFilter {
        case .monat:
            var components = DateComponents()
            components.year  = selectedYear
            components.month = selectedMonth
            components.day   = 1
            return calendar.date(from: components) ?? Date()
        case .jahr:
            var components = DateComponents()
            components.year  = selectedYear
            components.month = 1
            components.day   = 1
            return calendar.date(from: components) ?? Date()
        case .woche:
            return selectedDate
        }
    }
}
