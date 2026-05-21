import Foundation
import Combine

// MARK: - Log-Level
enum LogLevel: String {
    case info  = "INFO "
    case warn  = "WARN "
    case error = "ERROR"
    case gps   = "GPS  "
    case store = "DATA "
    case pro   = "PRO  "
    case scan  = "SCAN "
    case fuel  = "FUEL "
    case action = "TAP  "
    case input  = "INPUT"
    case nav    = "NAV  "
}

// MARK: - Log-Eintrag
struct LogEntry: Identifiable {
    let id    = UUID()
    let time  : Date
    let level : LogLevel
    let msg   : String

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var formatted: String {
        "[\(Self.fmt.string(from: time))][\(level.rawValue)] \(msg)"
    }
}

// MARK: - AppLogger
/// Rein In-Memory-Protokoll. Kein Schreibzugriff auf die Festplatte.
/// Wird bei jedem App-Neustart automatisch geleert.
/// Max. 500 Einträge – älteste Hälfte wird bei Überschreitung verworfen.
final class AppLogger: ObservableObject {
    static let shared = AppLogger()

    private let maxEntries = 500
    private var entries: [LogEntry] = []

    // Reaktiv für SwiftUI
    @Published private(set) var entryCount: Int = 0

    private init() {
        // Crash-Handler: letzte Chance, Fehler zu protokollieren
        NSSetUncaughtExceptionHandler { ex in
            let syms = ex.callStackSymbols.prefix(6).joined(separator: " | ")
            AppLogger.shared.log("CRASH \(ex.name.rawValue): \(ex.reason ?? "?") | \(syms)", level: .error)
        }
        log("App gestartet", level: .info)
    }

    // MARK: - Schreiben

    func log(_ msg: String, level: LogLevel = .info) {
        let entry = LogEntry(time: Date(), level: level, msg: msg)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(maxEntries / 2)
            entries.insert(LogEntry(time: Date(), level: .info,
                msg: "--- Log gekürzt (älteste \(maxEntries / 2) Einträge entfernt) ---"), at: 0)
        }
        DispatchQueue.main.async { self.entryCount = self.entries.count }
    }

    func logWarn(_ msg: String)  { log(msg, level: .warn)  }
    func logError(_ msg: String) { log(msg, level: .error) }
    func logGPS(_ msg: String)   { log(msg, level: .gps)   }
    func logData(_ msg: String)  { log(msg, level: .store) }
    func logPro(_ msg: String)   { log(msg, level: .pro)   }
    func logScan(_ msg: String)  { log(msg, level: .scan)  }
    func logFuel(_ msg: String)  { log(msg, level: .fuel)  }
    func logTap(_ element: String)                { log("Tap: \(element)", level: .action) }
    func logInput(_ field: String, value: String) { log("Eingabe '\(field)': \(value)", level: .input) }
    func logNav(_ destination: String)            { log("→ \(destination)", level: .nav) }

    // MARK: - Lesen

    /// Vollständiger Log-Text für Export / Anzeige
    var logContents: String {
        guard !entries.isEmpty else { return "Keine Protokolleinträge vorhanden." }
        let header = """
        Fahrtkosten App – Protokoll
        Erstellt: \(ISO8601DateFormatter().string(from: Date()))
        Einträge: \(entries.count)
        ──────────────────────────────────────
        
        """
        return header + entries.map(\.formatted).joined(separator: "\n")
    }

    /// Für Export als Data
    var logData: Data? { logContents.data(using: .utf8) }

    var hasEntries: Bool { !entries.isEmpty }

    var sizeText: String {
        let bytes = logContents.utf8.count
        return bytes < 1024 ? "\(bytes) B" : String(format: "%.1f KB", Double(bytes) / 1024)
    }

    // MARK: - Löschen (manuell durch Nutzer)
    func clearLog() {
        entries.removeAll()
        log("Protokoll manuell geleert", level: .info)
        DispatchQueue.main.async { self.entryCount = self.entries.count }
    }

    // MARK: - Rückwärtskompatibilität (FeedbackView nutzt diese)
    var logFileExists: Bool  { hasEntries }
    var logFileSizeText: String { sizeText }
    var logFileContents: String { logContents }
}
