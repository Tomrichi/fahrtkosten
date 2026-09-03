import SwiftUI
import Combine
import StoreKit

@MainActor
class ProManager: ObservableObject {
    @Published var isPro: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var googleApiKey: String {
        didSet { UserDefaults.standard.set(googleApiKey, forKey: "googleApiKey") }
    }

    nonisolated static let productID = "Thomas.Fahrtkosten.pro"

    // ── Grandfathering-Stichtag ─────────────────────────────────────────────
    // Alles, was VOR diesem Zeitpunkt aus dem App Store geladen wurde, war die
    // 8,99 €-Bezahlversion. Auf das Datum/Uhrzeit setzen, an dem 1.17.26 (Build 49)
    // im Store live ging. Lieber etwas später ansetzen als zu früh – ein
    // Neukunde, der versehentlich als Bestandskäufer durchgeht, kostet 6,99 €;
    // ein Bestandskäufer, der zahlen soll, kostet eine 1-Stern-Bewertung.
    private static let freemiumCutoffDate: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 3; c.hour = 23; c.minute = 59
        c.timeZone = TimeZone(identifier: "Europe/Berlin")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()
    // Erster Build mit In-App-Kauf. Auf iOS ist originalAppVersion die
    // CFBundleVersion (Build-Nummer), nicht die Marketing-Version.
    private static let firstFreemiumBuild = 49

    private static let legacyKey = "legacyPurchaser"
    private var updates: Task<Void, Never>? = nil

    init() {
        self.googleApiKey = UserDefaults.standard.string(forKey: "googleApiKey") ?? ""
        // Bestandskäufer (Festpreis-Käufer vor Freemium-Umstellung) immer freischalten
        if UserDefaults.standard.bool(forKey: Self.legacyKey) {
            self.isPro = true
        }
        updates = listenForTransactions()
        Task { await refreshStatus() }
    }

    deinit { updates?.cancel() }

    // ── Kaufstatus laden ─────────────────────────────────────────────────────
    func refreshStatus() async {
        // 1. Bestandskäufer über App-Store-Kaufbeleg erkennen
        if await checkLegacyPurchase() {
            isPro = true
            return
        }
        // 2. In-App-Kauf prüfen
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.productID == Self.productID {
                isPro = true
                return
            }
        }
        // 3. Weder noch – aber ein einmal gesetztes Legacy-Flag bleibt bestehen
        if !UserDefaults.standard.bool(forKey: Self.legacyKey) {
            isPro = false
        }
    }

    // ── Bestandskäufer-Prüfung (AppTransaction) ──────────────────────────────
    /// Liefert true, wenn der Nutzer die App als Bezahl-App gekauft hat.
    /// Ergebnis wird in UserDefaults gecacht, damit spätere Starts auch offline
    /// funktionieren.
    @discardableResult
    private func checkLegacyPurchase(refresh: Bool = false) async -> Bool {
        if UserDefaults.standard.bool(forKey: Self.legacyKey) { return true }

        do {
            let result = refresh
                ? try await AppTransaction.refresh()
                : try await AppTransaction.shared
            guard case .verified(let appTx) = result else { return false }

            let boughtBeforeCutoff = appTx.originalPurchaseDate < Self.freemiumCutoffDate
            let boughtOnOldBuild = (Int(appTx.originalAppVersion) ?? Int.max) < Self.firstFreemiumBuild

            if boughtBeforeCutoff || boughtOnOldBuild {
                UserDefaults.standard.set(true, forKey: Self.legacyKey)
                return true
            }
        } catch {
            // Kein Beleg verfügbar (z.B. offline beim allerersten Start) –
            // Nutzer wird NICHT gesperrt-markiert, Prüfung läuft beim nächsten
            // Start / bei "Wiederherstellen" erneut.
        }
        return false
    }

    // ── Kaufen ───────────────────────────────────────────────────────────────
    func purchase() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.productID])
            guard let product = products.first else {
                errorMessage = "Produkt nicht verfügbar."; return
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    isPro = true
                }
            case .userCancelled: break
            case .pending: errorMessage = "Zahlung ausstehend."
            @unknown default: break
            }
        } catch {
            errorMessage = "Kauf fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // ── Wiederherstellen ─────────────────────────────────────────────────────
    func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Zuerst Bestandskäufer-Prüfung mit frischem Beleg vom App Store
        if await checkLegacyPurchase(refresh: true) {
            isPro = true
            return
        }
        do {
            try await AppStore.sync()
            await refreshStatus()
            if !isPro { errorMessage = "Kein Kauf gefunden." }
        } catch {
            errorMessage = "Fehler: \(error.localizedDescription)"
        }
    }

    // ── Transaktions-Updates im Hintergrund ──────────────────────────────────
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let tx) = result, tx.productID == Self.productID {
                    await MainActor.run { self.isPro = true }
                    await tx.finish()
                }
            }
        }
    }
}
