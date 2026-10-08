import SwiftUI
import PDFKit

// MARK: - PDF Export Service
// Erzeugt ein vollständiges PDF mit Vorschau-Funktion
// Enthält: Kilometer, Spritpreis, Liter, Start- und Zielort (nur Ort, keine Straße)

struct PDFExportService {

    // MARK: - Hilfsfunktionen

    /// Kürzt eine Adresse auf nur den Ort (ohne Straße)
    static func cityOnly(from address: String) -> String {
        guard !address.isEmpty else { return address }
        // Format ist "Straße Hausnummer, Stadt" → wir nehmen nur den Teil nach dem Komma
        let parts = address.components(separatedBy: ", ")
        if parts.count >= 2 {
            return parts.last ?? address
        }
        return address
    }

    // MARK: - PDF generieren

    static func generatePDF(
        store: DataStore,
        trips: [Trip],
        meals: [MealEntry],
        hotels: [HotelEntry],
        vehicleCosts: [VehicleCost],
        reiseSpesen: [ReiseSpese],
        privateExpenses: [PrivateExpense],
        zeitraum: String
    ) -> Data {

        let pageWidth: CGFloat   = 595.2    // A4
        let pageHeight: CGFloat  = 841.8
        let margin: CGFloat      = 28
        let rowH: CGFloat        = 18
        let sectionH: CGFloat    = 24
        let tableW               = pageWidth - 2 * margin

        // Spalten: Datum | Von | Nach | Zweck | Strecke | Km-Satz | Betrag
        let cDatum:    CGFloat = margin
        let cVon:      CGFloat = margin + 60
        let cNach:     CGFloat = margin + 165
        let cZweck:    CGFloat = margin + 270
        let cStrecke:  CGFloat = margin + 355
        let cKmSatz:   CGFloat = margin + 395
        let cBetrag:   CGFloat = margin + 435

        // Spaltenbreiten
        let wDatum:    CGFloat = 58
        let wVon:      CGFloat = 100
        let wNach:     CGFloat = 100
        let wZweck:    CGFloat = 80
        let wStrecke:  CGFloat = 36
        let wKmSatz:   CGFloat = 36
        let wBetrag:   CGFloat = pageWidth - margin - cBetrag - 4

        let accent   = UIColor(red: 0.12, green: 0.35, blue: 0.75, alpha: 1)
        let textPri  = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
        let textSec  = UIColor(red: 0.38, green: 0.38, blue: 0.42, alpha: 1)
        let rowEven  = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)

        // Berechnungen
        let tripTotal    = trips.reduce(0.0)  { $0 + $1.km * store.kmRate }
        let mealTotal    = meals.reduce(0.0)  { $0 + store.effectiveAllowance(for: $1) }
        let hotelTotal   = hotels.reduce(0.0) { $0 + $1.amount(flat: store.hotelFlat) }
        let spesenTotal  = reiseSpesen.reduce(0.0) { $0 + $1.amount }
        let vehicleTotal = vehicleCosts.reduce(0.0) { $0 + $1.amount }
        let privateTotal = privateExpenses.reduce(0.0) { $0 + $1.amount }
        let grandTotal   = tripTotal + mealTotal + hotelTotal

        // Hilfsfunktionen
        func a(_ font: UIFont, _ color: UIColor = UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)) -> [NSAttributedString.Key: Any] {
            [.font: font, .foregroundColor: color]
        }
        func euro(_ v: Double) -> String { String(format: "%.2f €", v) }
        func km(_ v: Double) -> String { String(format: "%.1f km", v) }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin
            var rowIdx = 0
            var pageNum = 1

            func drawPageFooter() {
                let text = "Seite \(pageNum)"
                let sz = (text as NSString).size(withAttributes: a(.systemFont(ofSize: 8), textSec))
                text.draw(at: CGPoint(x: pageWidth - margin - sz.width, y: pageHeight - margin + 6),
                          withAttributes: a(.systemFont(ofSize: 8), textSec))
            }

            func newPage() {
                drawPageFooter()
                ctx.beginPage()
                pageNum += 1
                y = margin
                // Kopfzeile auf neuer Seite
                drawPageHeader()
                y += 36
                // Tabellenkopf wiederholen, damit Spalten auf jeder Seite erkennbar bleiben
                drawTableHeader()
            }

            func newPageIfNeeded(needed: CGFloat) {
                if y + needed > pageHeight - margin - 20 { newPage() }
            }

            func drawPageHeader() {
                // Subtiler Balken oben
                accent.withAlphaComponent(0.06).setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: 32)).fill()
                "Reisekostenabrechnung"
                    .draw(at: CGPoint(x: margin, y: 9),
                          withAttributes: a(.boldSystemFont(ofSize: 11), accent))
                let dateStr = Date().formatted(date: .abbreviated, time: .omitted)
                let right = "Erstellt: \(dateStr)"
                let sz = (right as NSString).size(withAttributes: a(.systemFont(ofSize: 9), textSec))
                right.draw(at: CGPoint(x: pageWidth - margin - sz.width, y: 11),
                           withAttributes: a(.systemFont(ofSize: 9), textSec))
            }

            func drawSectionHeader(title: String, subtotal: Double) {
                newPageIfNeeded(needed: sectionH + 4)
                // Hintergrund
                accent.withAlphaComponent(0.10).setFill()
                UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: tableW, height: sectionH),
                             cornerRadius: 4).fill()
                // Linker Akzentbalken
                accent.setFill()
                UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: 4, height: sectionH),
                             cornerRadius: 2).fill()
                title.draw(at: CGPoint(x: margin + 10, y: y + 6),
                           withAttributes: a(.boldSystemFont(ofSize: 10), accent))
                let sub = euro(subtotal)
                let subW = (sub as NSString).size(withAttributes: a(.boldSystemFont(ofSize: 10))).width
                sub.draw(at: CGPoint(x: pageWidth - margin - subW - 4, y: y + 6),
                         withAttributes: a(.boldSystemFont(ofSize: 10), accent))
                y += sectionH + 4
                rowIdx = 0
            }

            func drawTableHeader() {
                accent.setFill()
                UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: tableW, height: 18),
                             cornerRadius: 3).fill()
                let hA = a(.boldSystemFont(ofSize: 7.5), .white)
                "Datum".draw(at: CGPoint(x: cDatum + 2, y: y + 4), withAttributes: hA)
                "Von".draw(at: CGPoint(x: cVon + 2, y: y + 4), withAttributes: hA)
                "Nach".draw(at: CGPoint(x: cNach + 2, y: y + 4), withAttributes: hA)
                "Grund".draw(at: CGPoint(x: cZweck + 2, y: y + 4), withAttributes: hA)
                "Wegstrecke".draw(at: CGPoint(x: cStrecke + 2, y: y + 4), withAttributes: hA)
                "Km-Pauschale".draw(at: CGPoint(x: cKmSatz + 2, y: y + 4), withAttributes: hA)
                "Betrag".draw(at: CGPoint(x: cBetrag + 2, y: y + 4), withAttributes: hA)
                y += 22
                rowIdx = 0
            }

            // Fahrt-Zeile: 7 Spalten
            func drawTripRow(trip: Trip) {
                let hasPurpose = !trip.purpose.isEmpty
                let effectiveRowH: CGFloat = hasPurpose ? rowH + 10 : rowH
                newPageIfNeeded(needed: effectiveRowH + 1)
                if rowIdx % 2 == 0 {
                    rowEven.setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: y, width: tableW, height: effectiveRowH)).fill()
                }
                let rA  = a(.systemFont(ofSize: 7.5), textPri)
                let rAs = a(.systemFont(ofSize: 7.5), textSec)
                let rAb = a(.systemFont(ofSize: 7.5, weight: .semibold), textPri)
                let chipA = a(.systemFont(ofSize: 6.5), UIColor(red: 0.20, green: 0.20, blue: 0.24, alpha: 1))

                let dateStr = {
                    let df = DateFormatter()
                    df.locale = Locale(identifier: "de_DE")
                    df.dateFormat = "d. MMM yyyy"
                    return df.string(from: trip.date)
                }()
                dateStr.draw(in: CGRect(x: cDatum + 2, y: y + 3, width: wDatum, height: effectiveRowH), withAttributes: rAs)
                trip.from.draw(in: CGRect(x: cVon + 2, y: y + 3, width: wVon - 4, height: effectiveRowH), withAttributes: rA)
                trip.to.draw(in: CGRect(x: cNach + 2, y: y + 3, width: wNach - 4, height: effectiveRowH), withAttributes: rA)

                // Zweck: Art + optional Chip
                let artText = trip.art.rawValue
                artText.draw(at: CGPoint(x: cZweck + 2, y: y + 3), withAttributes: rAs)
                if hasPurpose {
                    let chipText = trip.purpose
                    let chipSize = (chipText as NSString).size(withAttributes: chipA)
                    let chipRect = CGRect(x: cZweck + 1, y: y + 13, width: chipSize.width + 8, height: 10)
                    UIColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1).setFill()
                    UIBezierPath(roundedRect: chipRect, cornerRadius: 3).fill()
                    chipText.draw(at: CGPoint(x: cZweck + 5, y: y + 14), withAttributes: chipA)
                }

                km(trip.km).draw(at: CGPoint(x: cStrecke + 2, y: y + 3), withAttributes: rAs)
                String(format: "€%.2f", store.kmRate).draw(at: CGPoint(x: cKmSatz + 2, y: y + 3), withAttributes: rAs)
                euro(trip.km * store.kmRate).draw(at: CGPoint(x: cBetrag + 2, y: y + 3), withAttributes: rAb)

                // Trennlinie
                UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1).setStroke()
                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: y + effectiveRowH))
                line.addLine(to: CGPoint(x: pageWidth - margin, y: y + effectiveRowH))
                line.lineWidth = 0.3; line.stroke()

                y += effectiveRowH
                rowIdx += 1
            }

            // Allgemeine Zeile für nicht-Fahrten-Einträge (Verpflegung etc.)
            func drawRow(date: String, desc: String, detail: String, betrag: Double,
                         highlight: Bool = false) {
                newPageIfNeeded(needed: rowH + 1)
                if rowIdx % 2 == 0 {
                    rowEven.setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: y, width: tableW, height: rowH)).fill()
                }
                if highlight {
                    UIColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1).setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: y, width: tableW, height: rowH)).fill()
                }
                let rA  = a(.systemFont(ofSize: 7.5), textPri)
                let rAs = a(.systemFont(ofSize: 7.5), textSec)
                date.draw(at: CGPoint(x: cDatum + 2, y: y + 3), withAttributes: rAs)
                desc.draw(in: CGRect(x: cVon + 2, y: y + 3, width: cZweck - cVon - 6, height: rowH), withAttributes: rA)
                detail.draw(in: CGRect(x: cZweck + 2, y: y + 3, width: cBetrag - cZweck - 4, height: rowH), withAttributes: rAs)
                euro(betrag).draw(at: CGPoint(x: cBetrag + 2, y: y + 3),
                                  withAttributes: a(.systemFont(ofSize: 7.5, weight: .semibold), textPri))
                y += rowH
                rowIdx += 1
            }

            // ── SEITE 1: Header ──────────────────────────────────────────────

            // Logo-Bereich / Titel
            accent.setFill()
            let headerHasProfile = !store.profilName.isEmpty || !store.profilKennzeichen.isEmpty
            let headerH: CGFloat = headerHasProfile ? 70 : 52
            UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: tableW, height: headerH),
                         cornerRadius: 8).fill()
            "Reisekostenabrechnung"
                .draw(at: CGPoint(x: margin + 16, y: y + 10),
                      withAttributes: a(.boldSystemFont(ofSize: 18), .white))
            "Zeitraum: \(zeitraum)"
                .draw(at: CGPoint(x: margin + 16, y: y + 32),
                      withAttributes: a(.systemFont(ofSize: 10), UIColor.white.withAlphaComponent(0.8)))
            if headerHasProfile {
                var profilParts: [String] = []
                if !store.profilName.isEmpty       { profilParts.append(store.profilName) }
                if !store.profilAdresse.isEmpty    { profilParts.append(store.profilAdresse) }
                if !store.profilKennzeichen.isEmpty { profilParts.append("Kfz: \(store.profilKennzeichen)") }
                profilParts.joined(separator: "  ·  ")
                    .draw(at: CGPoint(x: margin + 16, y: y + 50),
                          withAttributes: a(.systemFont(ofSize: 9), UIColor.white.withAlphaComponent(0.85)))
            }
            y += headerH + 8

            // Zusammenfassung-Kacheln
            let tileW = (tableW - 12) / 3
            let tiles: [(String, Double, UIColor)] = [
                ("Fahrten", tripTotal, accent),
                ("Verpflegung + Hotel", mealTotal + hotelTotal, UIColor(red: 0.12, green: 0.6, blue: 0.4, alpha: 1)),
                ("Gesamt (Erstattung)", grandTotal, UIColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1))
            ]
            for (i, tile) in tiles.enumerated() {
                let tx = margin + CGFloat(i) * (tileW + 6)
                tile.2.withAlphaComponent(0.10).setFill()
                UIBezierPath(roundedRect: CGRect(x: tx, y: y, width: tileW, height: 44),
                             cornerRadius: 6).fill()
                tile.2.setFill()
                UIBezierPath(roundedRect: CGRect(x: tx, y: y, width: 4, height: 44),
                             cornerRadius: 2).fill()
                tile.0.draw(at: CGPoint(x: tx + 10, y: y + 8),
                            withAttributes: a(.systemFont(ofSize: 8), tile.2))
                euro(tile.1).draw(at: CGPoint(x: tx + 10, y: y + 22),
                                  withAttributes: a(.boldSystemFont(ofSize: 12), tile.2))
            }
            y += 56

            // Trennlinie
            accent.withAlphaComponent(0.2).setStroke()
            let sep = UIBezierPath()
            sep.move(to: CGPoint(x: margin, y: y))
            sep.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            sep.lineWidth = 0.5; sep.stroke()
            y += 14

            drawTableHeader()

            // ── FAHRTEN ──────────────────────────────────────────────────────
            if !trips.isEmpty {
                drawSectionHeader(title: "Fahrten  (\(trips.count) Einträge)", subtotal: tripTotal)
                for trip in trips.sorted(by: { $0.date < $1.date }) {
                    drawTripRow(trip: trip)
                }
                y += 6
            }

            // ── VERPFLEGUNG ──────────────────────────────────────────────────
            if !meals.isEmpty {
                drawSectionHeader(title: "Verpflegung  (\(meals.count) Einträge)", subtotal: mealTotal)
                for meal in meals.sorted(by: { $0.date > $1.date }) {
                    let allowance = store.effectiveAllowance(for: meal)
                    let h = String(format: "%.1f h", meal.hours)
                    let detail = "\(meal.region.localizedName)  ·  \(h)"
                    drawRow(
                        date: meal.date.formatted(date: .numeric, time: .omitted),
                        desc: "Verpflegungspauschale",
                        detail: detail,
                        betrag: allowance,
                        highlight: allowance == 0
                    )
                }
                y += 6
            }

            // ── ÜBERNACHTUNGEN ───────────────────────────────────────────────
            if !hotels.isEmpty {
                drawSectionHeader(title: "Übernachtungen  (\(hotels.count) Einträge)", subtotal: hotelTotal)
                for hotel in hotels.sorted(by: { $0.date > $1.date }) {
                    let amt = hotel.amount(flat: store.hotelFlat)
                    let desc = [hotel.hotelName, hotel.city].filter { !$0.isEmpty }.joined(separator: ", ")
                    let detail = "\(hotel.numberOfNights) Nacht/Nächte  ·  \(String(format: "%.2f €/N", hotel.amountPerNight(flat: store.hotelFlat)))"
                    drawRow(
                        date: hotel.date.formatted(date: .numeric, time: .omitted),
                        desc: desc.isEmpty ? "Hotel" : desc,
                        detail: detail,
                        betrag: amt
                    )
                }
                y += 6
            }

            // ── REISESPESEN ──────────────────────────────────────────────────
            if !reiseSpesen.isEmpty {
                drawSectionHeader(title: "Reisespesen  (\(reiseSpesen.count) Einträge)", subtotal: spesenTotal)
                for spese in reiseSpesen.sorted(by: { $0.date > $1.date }) {
                    let desc = spese.title.isEmpty ? spese.kategorie.localizedName : spese.title
                    drawRow(
                        date: spese.date.formatted(date: .numeric, time: .omitted),
                        desc: desc,
                        detail: spese.kategorie.localizedName,
                        betrag: spese.amount
                    )
                }
                y += 6
            }

            // ── KFZ-KOSTEN ───────────────────────────────────────────────────
            if !vehicleCosts.isEmpty {
                drawSectionHeader(title: "KFZ-Kosten  (\(vehicleCosts.count) Einträge)", subtotal: vehicleTotal)
                for cost in vehicleCosts.sorted(by: { $0.date > $1.date }) {
                    drawRow(
                        date: cost.date.formatted(date: .numeric, time: .omitted),
                        desc: cost.title.isEmpty ? cost.category.localizedName : cost.title,
                        detail: cost.category.localizedName,
                        betrag: cost.amount
                    )
                }
                y += 6
            }

            // ── PRIVATE AUSGABEN ─────────────────────────────────────────────
            if !privateExpenses.isEmpty {
                drawSectionHeader(title: "Private Ausgaben  (\(privateExpenses.count) Einträge)", subtotal: privateTotal)
                for exp in privateExpenses.sorted(by: { $0.date > $1.date }) {
                    drawRow(
                        date: exp.date.formatted(date: .numeric, time: .omitted),
                        desc: exp.title.isEmpty ? "Ausgabe" : exp.title,
                        detail: exp.note,
                        betrag: exp.amount
                    )
                }
                y += 6
            }

            // ── GESAMTZEILE ──────────────────────────────────────────────────
            newPageIfNeeded(needed: 60)
            y += 8
            accent.withAlphaComponent(0.2).setStroke()
            let totalSep = UIBezierPath()
            totalSep.move(to: CGPoint(x: margin, y: y))
            totalSep.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            totalSep.lineWidth = 0.5; totalSep.stroke()
            y += 10

            accent.setFill()
            UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: tableW, height: 32),
                         cornerRadius: 5).fill()
            "Gesamterstattung (Fahrten + Verpflegung + Hotel)"
                .draw(at: CGPoint(x: margin + 12, y: y + 9),
                      withAttributes: a(.boldSystemFont(ofSize: 10), .white))
            let total = euro(grandTotal)
            let totalW = (total as NSString).size(withAttributes: a(.boldSystemFont(ofSize: 13))).width
            total.draw(at: CGPoint(x: pageWidth - margin - totalW - 12, y: y + 8),
                       withAttributes: a(.boldSystemFont(ofSize: 13), .white))
            y += 40

            // Hinweis
            let hinweis = "* KFZ-Kosten und private Ausgaben sind in der Gesamterstattung nicht enthalten."
            hinweis.draw(at: CGPoint(x: margin, y: y),
                         withAttributes: a(.systemFont(ofSize: 7.5), textSec))

            drawPageFooter()
        }

        return data
    }
}

// MARK: - PDF Vorschau View
struct PDFPreviewView: View {
    let pdfData: Data
    let filename: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitView(data: pdfData)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(filename)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(
                            item: pdfFileURL(data: pdfData, name: filename),
                            preview: SharePreview(filename, image: Image(systemName: "doc.richtext"))
                        ) {
                            Label("Teilen / Exportieren", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }

    private func pdfFileURL(data: Data, name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }
}

// MARK: - PDFKit View Wrapper
struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .white
        // Asynchron laden: Sheet ist beim makeUIView-Aufruf noch nicht vollständig
        // präsentiert → synchrones Setzen des Dokuments kann ein schwarzes Frame erzeugen
        DispatchQueue.main.async {
            pdfView.document = PDFDocument(data: data)
        }
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Nur neu setzen wenn sich das Dokument wirklich geändert hat
        if pdfView.document == nil {
            pdfView.document = PDFDocument(data: data)
        }
    }
}

// MARK: - CSV Export
struct CSVExportService {
    static func generate(
        store: DataStore,
        trips: [Trip],
        meals: [MealEntry],
        hotels: [HotelEntry],
        vehicleCosts: [VehicleCost],
        reiseSpesen: [ReiseSpese],
        privateExpenses: [PrivateExpense]
    ) -> String {
        var csv = "Datum;Kategorie;Von;Nach;Kilometer;Spritpreis €/L;Verbrauch L/100km;Verbrauchte Liter;Erstattung €;Notiz\n"

        // Fahrten
        for trip in trips.sorted(by: { $0.date > $1.date }) {
            let from = PDFExportService.cityOnly(from: trip.from)
            let to   = PDFExportService.cityOnly(from: trip.to)
            let erstattung = trip.km * store.kmRate
            let spritpreis = trip.fuelPricePerLiter.map { String(format: "%.3f", $0) } ?? ""
            let verbrauch  = trip.fuelConsumption.map { String(format: "%.1f", $0) } ?? ""
            let liter: String
            if let cons = trip.fuelConsumption, let preis = trip.fuelPricePerLiter, cons > 0, preis > 0 {
                liter = String(format: "%.2f", (trip.km / 100.0) * cons)
            } else { liter = "" }
            let date = trip.date.formatted(date: .numeric, time: .omitted)
            csv += "\(date);Fahrt;\(from);\(to);\(String(format: "%.1f", trip.km));\(spritpreis);\(verbrauch);\(liter);\(String(format: "%.2f", erstattung));\(trip.note)\n"
        }

        // Verpflegung
        for meal in meals.sorted(by: { $0.date > $1.date }) {
            let amt = store.effectiveAllowance(for: meal)
            let date = meal.date.formatted(date: .numeric, time: .omitted)
            csv += "\(date);Verpflegung;\(meal.region.localizedName);;;;;;;;\(String(format: "%.2f", amt));\(meal.note)\n"
        }

        // Hotels
        for hotel in hotels.sorted(by: { $0.date > $1.date }) {
            let amt = hotel.amount(flat: store.hotelFlat)
            let date = hotel.date.formatted(date: .numeric, time: .omitted)
            csv += "\(date);Hotel;\(hotel.city);\(hotel.hotelName);;;;;;;\(String(format: "%.2f", amt));\n"
        }

        // KFZ-Kosten
        for cost in vehicleCosts.sorted(by: { $0.date > $1.date }) {
            let date = cost.date.formatted(date: .numeric, time: .omitted)
            csv += "\(date);KFZ-Kosten;\(cost.category.localizedName);\(cost.title);;;;;;;\(String(format: "%.2f", cost.amount));\(cost.note)\n"
        }

        // Reisespesen
        for spese in reiseSpesen.sorted(by: { $0.date > $1.date }) {
            let date = spese.date.formatted(date: .numeric, time: .omitted)
            csv += "\(date);Reisespesen;\(spese.kategorie.localizedName);\(spese.title);;;;;;;\(String(format: "%.2f", spese.amount));\(spese.note)\n"
        }

        // Private Ausgaben
        for exp in privateExpenses.sorted(by: { $0.date > $1.date }) {
            let date = exp.date.formatted(date: .numeric, time: .omitted)
            csv += "\(date);Privat;;\(exp.title);;;;;;;\(String(format: "%.2f", exp.amount));\(exp.note)\n"
        }

        return csv
    }

    static func fileURL(content: String, zeitraum: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let name = "Fahrtkosten_\(zeitraum)_\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
