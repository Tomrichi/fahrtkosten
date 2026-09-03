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
    private var updates: Task<Void, Never>? = nil

    init() {
        self.googleApiKey = UserDefaults.standard.string(forKey: "googleApiKey") ?? ""
        // Bestandskäufer (Festpreis-Käufer vor Freemium-Umstellung) immer freischalten
        if UserDefaults.standard.bool(forKey: "legacyPurchaser") {
            self.isPro = true
        }
        updates = listenForTransactions()
        Task { await refreshStatus() }
    }

    deinit { updates?.cancel() }

    // ── Kaufstatus laden ─────────────────────────────────────────────────────
    func refreshStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.productID == Self.productID {
                isPro = true
                return
            }
        }
        // Bestandskäufer-Flag bleibt erhalten
        if !UserDefaults.standard.bool(forKey: "legacyPurchaser") {
            isPro = false
        }
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
        defer { isLoading = false }
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
