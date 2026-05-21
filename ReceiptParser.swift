import Vision
import UIKit

//// MARK: - Einzelne Beleg-Position (für KFZ-Kosten Multi-Erkennung)
struct ReceiptLineItem {
    var description      : String
    var amount           : Double
    var suggestedCategory: VehicleCostCategory
}

// MARK: - Scan Result
struct ReceiptScanResult {
    var rawText         : String
    var suggestedAmount : Double?
    var suggestedDate   : Date?
    var suggestedName   : String?
    var suggestedCity   : String?
    var suggestedNights : Int?
    var lineItems       : [ReceiptLineItem]?   // Einzelpositionen für KFZ-Kosten
    var image           : UIImage
}

// MARK: - Receipt Parser (Vision OCR)
struct ReceiptParser {

    static func parse(image: UIImage, completion: @escaping (ReceiptScanResult?) -> Void) {
        guard let cgImage = image.cgImage else { completion(nil); return }

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil); return
            }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let fullText = lines.joined(separator: "\n")

            let items = extractLineItems(from: lines)
            let result = ReceiptScanResult(
                rawText:          fullText,
                suggestedAmount:  extractTotalAmount(from: lines),
                suggestedDate:    extractDate(from: lines),
                suggestedName:    extractName(from: lines),
                suggestedCity:    extractCity(from: lines),
                suggestedNights:  extractNights(from: lines),
                lineItems:        items.count >= 2 ? items : nil,
                image:            image
            )
            completion(result)
        }
        request.recognitionLevel      = .accurate
        request.recognitionLanguages  = ["de-DE", "de-AT", "de-CH", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }


    // MARK: - Multi-Seiten OCR (für PDF-Import)
    /// Verarbeitet mehrere Seiten (PDF-Seiten als UIImages) und kombiniert die Ergebnisse
    static func parseMultiPage(images: [UIImage], completion: @escaping (ReceiptScanResult?) -> Void) {
        guard !images.isEmpty else { completion(nil); return }

        var allLines: [String] = []
        let group = DispatchGroup()

        for image in images {
            guard let cgImage = image.cgImage else { continue }
            group.enter()
            let request = VNRecognizeTextRequest { req, err in
                defer { group.leave() }
                guard err == nil,
                      let observations = req.results as? [VNRecognizedTextObservation] else { return }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                allLines.append(contentsOf: lines)
            }
            request.recognitionLevel      = .accurate
            request.recognitionLanguages  = ["de-DE", "de-AT", "de-CH", "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            guard !allLines.isEmpty else { completion(nil); return }
            // Nutze das erste Bild als Repräsentationsbild für das Ergebnis
            let representative = images[0]
            let items = extractLineItems(from: allLines)
            let result = ReceiptScanResult(
                rawText:         allLines.joined(separator: "\n"),
                suggestedAmount: extractTotalAmount(from: allLines),
                suggestedDate:   extractDate(from: allLines),
                suggestedName:   extractName(from: allLines),
                suggestedCity:   extractCity(from: allLines),
                suggestedNights: extractNights(from: allLines),
                lineItems:       items.count >= 2 ? items : nil,
                image:           representative
            )
            completion(result)
        }
    }

    // MARK: - Gesamtbetrag inkl. MwSt
    private static func extractTotalAmount(from lines: [String]) -> Double? {

        // ── Priorität 1: "Rechnungsbetrag" – explizit der Brutto-Endbetrag ──────
        // Muster: "Rechnungsbetrag 21,00€" oder "Rechnungsbetrag 21,00 €"
        let p1patterns = [
            #"rechnungsbetrag[\s:]*(\d{1,5}[.,]\d{2})\s*€?"#,
            #"rechnungsbetrag[\s:]*€?\s*(\d{1,5}[.,]\d{2})"#,
        ]
        for pattern in p1patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            for line in lines {
                let ns = NSRange(line.startIndex..., in: line)
                if let m = regex.firstMatch(in: line, range: ns),
                   let r = Range(m.range(at: 1), in: line) {
                    if let v = parseAmount(String(line[r])), v > 0 { return v }
                }
            }
        }

        // ── Priorität 2: Andere explizite Brutto/Gesamt-Label ────────────────────
        // WICHTIG: "netto", "nettobetrag", "mwst", "ust" explizit AUSSCHLIESSEN
        let p2patterns = [
            #"(?:gesamtbetrag|endbetrag|zu zahlen|zahlbetrag|summe|total|gesamt)[:\s]*(?:eur|€)?\s*(\d{1,5}[.,]\d{2})"#,
            #"(?:gesamtbetrag|endbetrag|zu zahlen|zahlbetrag|summe|total|gesamt)[:\s]*(\d{1,5}[.,]\d{2})\s*(?:eur|€)"#,
        ]
        for pattern in p2patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            for line in lines {
                // Zeilen mit Netto/MwSt überspringen
                let lower = line.lowercased()
                if lower.contains("netto") || lower.contains("mwst") ||
                   lower.contains("ust.") || lower.contains("steuer") { continue }
                let ns = NSRange(line.startIndex..., in: line)
                if let m = regex.firstMatch(in: line, range: ns),
                   let r = Range(m.range(at: 1), in: line) {
                    if let v = parseAmount(String(line[r])), v > 0 { return v }
                }
            }
        }

        // ── Priorität 3: Betrag in gleicher Zeile wie "Rechnungsbetrag" (mehrspaltig) ──
        // Manchmal steht das Label in einer Zeile und der Betrag in der nächsten
        for (i, line) in lines.enumerated() {
            if line.lowercased().contains("rechnungsbetrag") {
                // Suche in dieser und den nächsten 2 Zeilen nach einem Betrag
                let searchLines = lines[i...min(i+2, lines.count-1)]
                for sLine in searchLines {
                    let amtPattern = #"(\d{1,5}[.,]\d{2})\s*€?"#
                    if let regex = try? NSRegularExpression(pattern: amtPattern),
                       let m = regex.firstMatch(in: sLine, range: NSRange(sLine.startIndex..., in: sLine)),
                       let r = Range(m.range(at: 1), in: sLine),
                       let v = parseAmount(String(sLine[r])), v > 0 {
                        return v
                    }
                }
            }
        }

        // ── Priorität 4: Fallback – größter Betrag, aber NICHT aus Netto-Zeilen ──
        var amounts: [Double] = []
        let fallbackRx = try? NSRegularExpression(pattern: #"(\d{1,5}[.,]\d{2})"#)
        for line in lines {
            let lower = line.lowercased()
            // Netto-, MwSt-, Steuer-Zeilen überspringen
            if lower.contains("netto") || lower.contains("mwst") ||
               lower.contains("ust.") || lower.contains("steuer") ||
               lower.contains("iban") || lower.contains("bic") { continue }
            let ns = NSRange(line.startIndex..., in: line)
            for m in (fallbackRx?.matches(in: line, range: ns) ?? []) {
                if let r = Range(m.range(at: 1), in: line),
                   let v = parseAmount(String(line[r])), v > 1, v < 10_000 {
                    amounts.append(v)
                }
            }
        }
        return amounts.max()
    }

    private static func parseAmount(_ s: String) -> Double? {
        // Komma als Dezimaltrenner: "21,00" → 21.0
        // Punkt als Tausendertrenner: "1.234,56" → 1234.56
        var clean = s.trimmingCharacters(in: .whitespaces)
        if clean.contains(",") {
            // Deutschen Format: Punkte entfernen, Komma → Punkt
            clean = clean.replacingOccurrences(of: ".", with: "")
                         .replacingOccurrences(of: ",", with: ".")
        }
        // Nur Ziffern und Punkt behalten
        clean = clean.filter { $0.isNumber || $0 == "." }
        return Double(clean)
    }

    // MARK: - Datum
    private static func extractDate(from lines: [String]) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        let patterns: [(String)] = [
            #"(\d{1,2})[.\-/](\d{1,2})[.\-/](20\d{2})"#,
            #"(20\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})"#,
        ]
        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                      let dateRange = Range(m.range, in: line) else { continue }
                let ds = String(line[dateRange])
                    .replacingOccurrences(of: "/", with: ".")
                    .replacingOccurrences(of: "-", with: ".")
                let parts = ds.split(separator: ".")
                if parts.count == 3 {
                    fmt.dateFormat = parts[0].count == 4 ? "yyyy.MM.dd" : "dd.MM.yyyy"
                }
                if let d = fmt.date(from: ds),
                   d > Date(timeIntervalSinceNow: -5 * 365 * 24 * 3600),
                   d <= Date() { return d }
            }
        }
        return nil
    }

    // MARK: - Hotelname
    private static func extractName(from lines: [String]) -> String? {
        let keywords = ["hotel", "gasthof", "pension", "motel", "inn", "lodge",
                        "resort", "ibis", "hilton", "marriott", "novotel", "mercure",
                        "radisson", "sheraton", "hyatt", "accor", "steigenberger",
                        "ringhotel", "ramada", "holiday inn", "best western", "nh ",
                        "dorint", "meininger", "a&o", "cocoon", "wombat"]
        for line in lines {
            let lower = line.lowercased()
            for kw in keywords where lower.contains(kw) {
                let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if (3...80).contains(cleaned.count) { return cleaned }
            }
        }

        // Fallback: erste Zeilen die wie ein Name aussehen –
        // aber Adressen (Straße, PLZ, Firmensuffixe allein) ausschließen
        // Zeile überspringen wenn sie:
        //   - Ziffern enthält (PLZ, Hausnummer, Preise)
        //   - typische Adress-Wörter enthält (Straße, Str., Weg, Platz, etc.)
        //   - nur ein Firmensuffix ist (GmbH, AG, KG, e.K. etc.)
        //   - typische Rechnungs-Wörter enthält
        let addressRx = try? NSRegularExpression(
            pattern: #"(?i)(str\.|straße|strasse|weg|platz|allee|gasse|ring|damm|chaussee|avenue|boulevard)"#
        )
        let invoiceRx = try? NSRegularExpression(
            pattern: #"(?i)(rechnung|invoice|datum|mwst|ust|steuer|gesamt|total|betrag|konto|iban|bic|tel\.|fax|www\.|@|mailto)"#
        )
        let suffixOnlyRx = try? NSRegularExpression(
            pattern: #"^(?:GmbH|AG|KG|OHG|e\.K\.|e\.V\.|mbH|Inc\.|Ltd\.|Co\.|\s)+$"#
        )
        let nameRx = try? NSRegularExpression(
            pattern: #"^[A-Za-zÄÖÜäöüß\s&\.,\'''\-]{4,60}$"#
        )
        let ns = { (s: String) in NSRange(s.startIndex..., in: s) }

        for line in lines.prefix(8) {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            // Ziffern → überspringen
            guard !t.contains(where: { $0.isNumber }) else { continue }
            // Adress-Wörter → überspringen
            if let rx = addressRx, rx.firstMatch(in: t, range: ns(t)) != nil { continue }
            // Rechnungs-Wörter → überspringen
            if let rx = invoiceRx, rx.firstMatch(in: t, range: ns(t)) != nil { continue }
            // Nur Firmensuffix → überspringen
            if let rx = suffixOnlyRx, rx.firstMatch(in: t, range: ns(t)) != nil { continue }
            // Passt Name-Pattern?
            if let rx = nameRx, rx.firstMatch(in: t, range: ns(t)) != nil { return t }
        }
        return nil
    }

    // MARK: - Stadt
    private static func extractCity(from lines: [String]) -> String? {
        let rx = try? NSRegularExpression(
            pattern: #"(?:[A-Z]{1,2}[- ])?\d{4,5}\s+([A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß\s\-]{1,35})"#
        )
        for line in lines {
            guard let regex = rx,
                  let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let r = Range(m.range(at: 1), in: line) else { continue }
            let city = String(line[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            if (2...40).contains(city.count) { return city }
        }
        return nil
    }

    // MARK: - Anzahl Nächte (NEU)
    private static func extractNights(from lines: [String]) -> Int? {

        // ── Priorität 1: Anzahl direkt in "Übernachtung"-Zeile ──────────────────
        // z.B. "13.04.2026 Übernachtung 7% 3 104,20 312,60 €"  → 3
        for line in lines {
            let lower = line.lowercased()
            guard lower.contains("übernachtung") else { continue }

            // Strategie A: Zahl NACH einem MwSt-Prozentsatz (z.B. "7% 3")
            // Das ist die Anzahl-Spalte in typischen Hotelrechnungen
            let afterPctRx = try? NSRegularExpression(pattern: #"\d+%\s+(\d{1,2})\b"#)
            let ns = NSRange(lower.startIndex..., in: lower)
            if let m = afterPctRx?.firstMatch(in: lower, range: ns),
               let r = Range(m.range(at: 1), in: lower),
               let n = Int(String(lower[r])), (1...30).contains(n) {
                return n
            }

            // Strategie B: Zahl die NICHT von % . , gefolgt wird und NICHT % vorangeht
            // Überspringt MwSt-Prozentsätze wie "7%", "19%"
            let cleanRx = try? NSRegularExpression(pattern: #"(?<![%\d])(\b\d{1,2}\b)(?![%.,\d])"#)
            for m in (cleanRx?.matches(in: lower, range: ns) ?? []) {
                if let r = Range(m.range(at: 1), in: lower),
                   let n = Int(String(lower[r])), (1...30).contains(n) {
                    return n
                }
            }
        }

        // ── Priorität 2: Explizite Nächte-Angabe ────────────────────────────────
        // "3 Nächte", "Nächte: 3", "3 nights"
        let nightPatterns = [
            #"\b(\d{1,2})\s*(?:nächte|nacht|übernachtungen|nights?)"#,
            #"(?:nächte|nacht|nights?)[:\s]+(\d{1,2})\b"#,
        ]
        for pattern in nightPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            else { continue }
            for line in lines {
                let lower = line.lowercased()
                let ns = NSRange(lower.startIndex..., in: lower)
                if let m = regex.firstMatch(in: lower, range: ns),
                   let r = Range(m.range(at: 1), in: lower),
                   let n = Int(String(lower[r])), (1...30).contains(n) {
                    return n
                }
            }
        }

        // ── Priorität 3: Anreise/Abreise Zeilen – NUR diese beiden Daten ────────
        // Suche explizit nach "Anreise DD.MM.YYYY" und "Abreise DD.MM.YYYY"
        if let nights = extractNightsFromCheckinCheckout(lines: lines), nights > 0 { return nights }

        return nil
    }

    /// Extrahiert Nächte NUR aus expliziten Anreise/Abreise-Zeilen
    /// Unterstützt auch das Format wo Label und Datum auf getrennten Zeilen stehen
    private static func extractNightsFromCheckinCheckout(lines: [String]) -> Int? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "dd.MM.yyyy"
        let dateRx = try? NSRegularExpression(pattern: #"(\d{1,2})[.](\d{1,2})[.](20\d{2})"#)

        var checkIn: Date?
        var checkOut: Date?

        func findDate(in searchLines: [String]) -> Date? {
            for sl in searchLines {
                guard let regex = dateRx,
                      let m = regex.firstMatch(in: sl, range: NSRange(sl.startIndex..., in: sl)),
                      let r = Range(m.range, in: sl) else { continue }
                let ds = String(sl[r])
                if let d = fmt.date(from: ds),
                   d > Date(timeIntervalSinceNow: -10 * 365 * 24 * 3600),
                   d < Date(timeIntervalSinceNow:  5 * 365 * 24 * 3600) { return d }
            }
            return nil
        }

        for (i, line) in lines.enumerated() {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
            let isCheckIn  = lower == "anreise" || lower.hasPrefix("anreise") ||
                             lower.contains("check-in") || lower.contains("checkin")
            let isCheckOut = lower == "abreise" || lower.hasPrefix("abreise") ||
                             lower.contains("check-out") || lower.contains("checkout")
            guard isCheckIn || isCheckOut else { continue }

            // Datum auf dieser Zeile ODER der nächsten Zeile suchen
            let nextLine = i + 1 < lines.count ? lines[i + 1] : ""
            let searchLines = [line, nextLine]

            if let d = findDate(in: searchLines) {
                if isCheckIn  { checkIn  = d }
                if isCheckOut { checkOut = d }
            }
        }

        guard let ci = checkIn, let co = checkOut, co > ci else { return nil }
        let nights = Calendar.current.dateComponents([.day], from: ci, to: co).day
        return (nights ?? 0) > 0 ? nights : nil
    }

    // MARK: - Einzelpositionen für KFZ-Kosten
    /// Erkennt einzelne Rechnungspositionen (Beschreibung + Betrag pro Zeile).
    /// Gibt nur Positionen zurück, die eindeutig Produktzeilen sind (kein Gesamt/MwSt).
    static func extractLineItems(from lines: [String]) -> [ReceiptLineItem] {
        let skipTokens = ["gesamt", "summe", "total", "mwst", "ust.", "steuer",
                          "netto", "brutto", "rechnungsbetrag", "endbetrag",
                          "zahlbetrag", "zu zahlen", "iban", "bic",
                          "vielen dank", "danke", "quittung", "zwischensumme"]

        // Betrag am Zeilenende (ggf. mit €-Zeichen und Leerzeichen)
        guard let amountRx = try? NSRegularExpression(
            pattern: #"(\d{1,5}[.,]\d{2})\s*€?\s*$"#
        ) else { return [] }

        var items: [ReceiptLineItem] = []

        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.count >= 5 else { continue }
            let lower = t.lowercased()
            if skipTokens.contains(where: { lower.contains($0) }) { continue }

            let ns = NSRange(t.startIndex..., in: t)
            guard let match = amountRx.firstMatch(in: t, range: ns),
                  let r = Range(match.range(at: 1), in: t),
                  let amount = parseAmount(String(t[r])),
                  amount >= 1.0, amount < 9_999 else { continue }

            // Beschreibung: alles vor dem Betrag-Match
            let matchStart = match.range.lowerBound
            var desc = String(t.prefix(matchStart))
                .trimmingCharacters(in: .whitespaces)

            // Führende Positionsnummer entfernen: "01 ", "1. ", "A1 " etc.
            desc = desc
                .replacingOccurrences(of: #"^\d{1,3}[.\s]\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            // Abschließende Menge/Einzelpreis entfernen: "5,00  12,50" → "5,00"
            desc = desc
                .replacingOccurrences(of: #"\s+\d+[.,]\d+\s*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            guard desc.count >= 3,
                  desc.contains(where: { $0.isLetter }) else { continue }

            let cat = detectVehicleCategory(from: lower)
            items.append(ReceiptLineItem(description: desc, amount: amount, suggestedCategory: cat))
        }

        return items
    }

    private static func detectVehicleCategory(from lower: String) -> VehicleCostCategory {
        if lower.contains("öl") || lower.contains("inspektion") || lower.contains("reparatur") ||
           lower.contains("werkstatt") || lower.contains("filter") || lower.contains("bremsbelä") ||
           lower.contains("bremsscheib") || lower.contains("batterie") || lower.contains("zündkerz") ||
           lower.contains("kupplung") || lower.contains("stoßdämpf") || lower.contains("auspuff") ||
           lower.contains("zahnriemen") || lower.contains("glühlampe") || lower.contains("arbeitszeit") {
            return .werkstatt
        }
        if lower.contains("reifen") || lower.contains("bereifung") || lower.contains("felge") ||
           lower.contains("pneu") || lower.contains("montage") {
            return .reifen
        }
        if lower.contains("tüv") || lower.contains("hu ") || lower.contains("hauptuntersuchung") ||
           lower.contains("abgasuntersuchung") || lower.contains("au ") || lower.contains("dekra") {
            return .tuvHu
        }
        if lower.contains("versicherung") { return .versicherung }
        if lower.contains("leasing")      { return .leasing }
        if lower.contains("strom") || lower.contains("laden") || lower.contains("kwh") {
            return .strom
        }
        if lower.contains("wasch") || lower.contains("car wash") { return .fahrzeugwaesche }
        if lower.contains("steuer") { return .steuer }
        return .sonstiges
    }

    /// Gibt das Check-in Datum zurück (Anreise-Zeile oder nächste Zeile)
    static func extractCheckInDate(from lines: [String]) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "dd.MM.yyyy"
        let dateRx = try? NSRegularExpression(pattern: #"(\d{1,2})[.](\d{1,2})[.](20\d{2})"#)

        for (i, line) in lines.enumerated() {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
            guard lower == "anreise" || lower.hasPrefix("anreise") else { continue }
            let nextLine = i + 1 < lines.count ? lines[i + 1] : ""
            for sl in [line, nextLine] {
                guard let regex = dateRx,
                      let m = regex.firstMatch(in: sl, range: NSRange(sl.startIndex..., in: sl)),
                      let r = Range(m.range, in: sl),
                      let d = fmt.date(from: String(sl[r])) else { continue }
                return d
            }
        }
        return nil
    }
}
