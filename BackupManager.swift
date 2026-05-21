import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup-Datenstruktur
struct AppBackup: Codable {
    let version: Int
    let exportedAt: Date
    let trips: [Trip]
    let meals: [MealEntry]
    let hotels: [HotelEntry]
    let vehicleCosts: [VehicleCost]
    let reiseSpesen: [ReiseSpese]
    let privateExpenses: [PrivateExpense]
    let kmRate: Double
    let defaultFuelConsumption: Double
    let inlandMeal1to3: Double
    let inlandMeal3to6: Double
    let inlandMeal6plus: Double
    let swissMeal1to3: Double
    let swissMeal3to6: Double
    let swissMeal6plus: Double
    let abroadMeal1to3: Double
    let abroadMeal3to6: Double
    let abroadMeal6plus: Double
    let hotelFlat: Double
    let breakfastFlat: Double

    static let currentVersion = 2

    var totalEntries: Int {
        trips.count + meals.count + hotels.count + vehicleCosts.count + reiseSpesen.count + privateExpenses.count
    }
}

// MARK: - Gespeichertes Backup (lokal)
struct SavedBackupInfo: Identifiable {
    let id = UUID()
    let url: URL
    let filename: String
    let date: Date
    let fileSize: Int64

    var formattedSize: String {
        let kb = Double(fileSize) / 1024
        if kb >= 1024 { return String(format: "%.1f MB", kb / 1024) }
        return String(format: "%.0f KB", kb)
    }
}

// MARK: - BackupManager
@MainActor
class BackupManager: ObservableObject {
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastError: String?
    @Published var lastSuccess: String?
    @Published var savedBackups: [SavedBackupInfo] = []
    @Published var isLoadingBackups = false

    // App-eigener Dokumente-Ordner (in Dateien-App sichtbar unter "Auf meinem iPhone")
    private var backupDirectory: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Backup JSON erstellen
    func createBackupData(from store: DataStore) -> Data? {
        let backup = AppBackup(
            version: AppBackup.currentVersion,
            exportedAt: Date(),
            trips: store.trips,
            meals: store.meals,
            hotels: store.hotels,
            vehicleCosts: store.vehicleCosts,
            reiseSpesen: store.reiseSpesen,
            privateExpenses: store.privateExpenses,
            kmRate: store.kmRate,
            defaultFuelConsumption: store.defaultFuelConsumption,
            inlandMeal1to3: store.inlandMeal1to3,
            inlandMeal3to6: store.inlandMeal3to6,
            inlandMeal6plus: store.inlandMeal6plus,
            swissMeal1to3: store.swissMeal1to3,
            swissMeal3to6: store.swissMeal3to6,
            swissMeal6plus: store.swissMeal6plus,
            abroadMeal1to3: store.abroadMeal1to3,
            abroadMeal3to6: store.abroadMeal3to6,
            abroadMeal6plus: store.abroadMeal6plus,
            hotelFlat: store.hotelFlat,
            breakfastFlat: store.breakfastFlat
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }

    private func backupFilename() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm"
        return "Fahrtkosten_Backup_\(f.string(from: Date())).json"
    }

    // MARK: - Lokal speichern (Dateien-App)
    func saveLocally(from store: DataStore) {
        guard let dir = backupDirectory,
              let data = createBackupData(from: store) else {
            lastError = "Backup konnte nicht erstellt werden"
            return
        }
        let url = dir.appendingPathComponent(backupFilename())
        do {
            try data.write(to: url, options: .atomic)
            lastSuccess = "Backup gespeichert - abrufbar in der Dateien-App unter: Auf meinem iPhone → Fahrtkosten → Backups"
            loadSavedBackups()
            // Alte aufräumen
            cleanupOldBackups(in: dir, keepCount: 10)
        } catch {
            lastError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Share Sheet (AirDrop, iCloud Drive, Google Drive, etc.)
    func backupFileURL(from store: DataStore) -> URL? {
        guard let data = createBackupData(from: store) else {
            lastError = "Backup konnte nicht erstellt werden"
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(backupFilename())
        do {
            try data.write(to: url)
            return url
        } catch {
            lastError = "Datei konnte nicht erstellt werden"
            return nil
        }
    }

    // MARK: - Gespeicherte Backups laden
    func loadSavedBackups() {
        guard let dir = backupDirectory else { return }
        isLoadingBackups = true
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            savedBackups = files
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> SavedBackupInfo? in
                    let v = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                    return SavedBackupInfo(
                        url: url,
                        filename: url.lastPathComponent,
                        date: v?.creationDate ?? Date(),
                        fileSize: Int64(v?.fileSize ?? 0)
                    )
                }
                .sorted { $0.date > $1.date }
        } catch {
            savedBackups = []
        }
        isLoadingBackups = false
    }

    // MARK: - Backup löschen
    func deleteBackup(_ info: SavedBackupInfo) {
        try? FileManager.default.removeItem(at: info.url)
        loadSavedBackups()
    }

    // MARK: - Wiederherstellen
    func restore(from url: URL, into store: DataStore) -> Bool {
        do {
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(AppBackup.self, from: data)
            store.trips = backup.trips
            store.meals = backup.meals
            store.hotels = backup.hotels
            store.vehicleCosts = backup.vehicleCosts
            store.reiseSpesen = backup.reiseSpesen
            store.privateExpenses = backup.privateExpenses
            store.kmRate = backup.kmRate
            store.defaultFuelConsumption = backup.defaultFuelConsumption
            store.inlandMeal1to3 = backup.inlandMeal1to3
            store.inlandMeal3to6 = backup.inlandMeal3to6
            store.inlandMeal6plus = backup.inlandMeal6plus
            store.swissMeal1to3 = backup.swissMeal1to3
            store.swissMeal3to6 = backup.swissMeal3to6
            store.swissMeal6plus = backup.swissMeal6plus
            store.abroadMeal1to3 = backup.abroadMeal1to3
            store.abroadMeal3to6 = backup.abroadMeal3to6
            store.abroadMeal6plus = backup.abroadMeal6plus
            store.hotelFlat = backup.hotelFlat
            store.breakfastFlat = backup.breakfastFlat
            let dateStr = backup.exportedAt.formatted(date: .abbreviated, time: .shortened)
            lastSuccess = "Backup vom \(dateStr) wiederhergestellt (\(backup.totalEntries) Einträge)"
            return true
        } catch DecodingError.dataCorrupted(_) {
            lastError = "Ungültige Backup-Datei"
        } catch DecodingError.keyNotFound(let key, _) {
            lastError = "Backup unvollständig: '\(key.stringValue)' fehlt"
        } catch {
            lastError = "Fehler: \(error.localizedDescription)"
        }
        return false
    }

    // MARK: - Alte Backups aufräumen
    private func cleanupOldBackups(in dir: URL, keepCount: Int) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles
        ) else { return }
        let sorted = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> (URL, Date)? in
                let d = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                return d.map { (url, $0) }
            }
            .sorted { $0.1 > $1.1 }
        for (url, _) in sorted.dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Alle Einträge löschen
    func deleteAllEntries(in store: DataStore) {
        store.trips = []; store.meals = []; store.hotels = []
        store.vehicleCosts = []; store.reiseSpesen = []; store.privateExpenses = []
    }
}

// MARK: - Datei-Import Picker
struct BackupImportPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

extension UTType {
    static let fahrtkostenBackup = UTType(importedAs: "de.fahrtkosten.backup")
}
