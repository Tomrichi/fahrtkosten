import Foundation
import CryptoKit
import Security

// MARK: - Hardware-gesicherte Signatur (Fahrtenbuchmodus, Baustein 1)
/// Signiert jeden Hash der Änderungsprotokoll-Kette mit einem geräte­gebundenen Schlüssel,
/// der die Hardware nie als Klartext verlässt. Verhindert, dass jemand die lokale
/// Datenbank löscht, neu aufbaut und die Hash-Kette einfach neu berechnet – die Signatur
/// kann ohne den (nicht extrahierbaren) privaten Schlüssel dieses Geräts nicht erzeugt werden.
enum FahrtenbuchSigner {
    private static let keychainService = "de.tommwagner.fahrtkosten.fahrtenbuch.signingkey"
    private static let keychainAccount = "signingkey"

    /// Liefert die hex-kodierte ECDSA-Signatur über den SHA256-Hex-String eines Log-Eintrags.
    /// Erzeugt und speichert bei Bedarf einmalig einen neuen Schlüssel.
    static func sign(_ hashHex: String) -> String {
        let data = Data(hashHex.utf8)
        if SecureEnclave.isAvailable {
            guard let key = loadOrCreateSecureEnclaveKey() else { return "" }
            guard let signature = try? key.signature(for: data) else { return "" }
            return signature.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        } else {
            // Simulator / Geräte ohne Secure Enclave: Software-Schlüssel als Fallback,
            // damit die Funktion testbar bleibt und nicht hart auf echte Hardware angewiesen ist.
            guard let key = loadOrCreateSoftwareKey() else { return "" }
            guard let signature = try? key.signature(for: data) else { return "" }
            return signature.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        }
    }

    private static func loadOrCreateSecureEnclaveKey() -> SecureEnclave.P256.Signing.PrivateKey? {
        if let data = readKeychain(), let key = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data) {
            return key
        }
        guard let newKey = try? SecureEnclave.P256.Signing.PrivateKey() else { return nil }
        writeKeychain(newKey.dataRepresentation)
        return newKey
    }

    private static func loadOrCreateSoftwareKey() -> P256.Signing.PrivateKey? {
        if let data = readKeychain(), let key = try? P256.Signing.PrivateKey(rawRepresentation: data) {
            return key
        }
        let newKey = P256.Signing.PrivateKey()
        writeKeychain(newKey.rawRepresentation)
        return newKey
    }

    private static func readKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func writeKeychain(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}

// MARK: - Rollback-Schutz (Fahrtenbuchmodus, Baustein 1)
/// Spiegelt den jeweils letzten Ketten-Stand (seq + Hash) zusätzlich in der Keychain
/// (geräte­gebunden, von iCloud-/iTunes-Backups ausgeschlossen). Wird ein altes Backup der
/// App eingespielt, landet eine ÄLTERE changeLog auf dem Gerät – die Keychain "weiß" aber
/// noch vom späteren Stand, und der Mismatch ist erkennbar.
enum RollbackGuard {
    private static let keychainService = "de.tommwagner.fahrtkosten.fahrtenbuch.rollbackguard"
    private static let seqAccount = "lastSeq"
    private static let hashAccount = "lastHash"

    /// true, wenn der in der Keychain gespeicherte Stand weiter fortgeschritten ist als die
    /// aktuell geladene Kette – Hinweis auf ein eingespieltes altes Backup.
    static func checkForRollback(currentChainCount: Int) -> Bool {
        guard let lastSeq = readInt(account: seqAccount) else { return false }
        return lastSeq > currentChainCount
    }

    static func record(seq: Int, hash: String) {
        writeString(String(seq), account: seqAccount)
        writeString(hash, account: hashAccount)
    }

    /// Nur für Unit-Tests: die Keychain-Einträge sind geräteweit und überleben einzelne
    /// `DataStore()`-Instanzen – ohne Reset würde ein früherer Testlauf (oder die App selbst)
    /// einen falschen Rollback für den nächsten Testlauf vortäuschen.
    static func resetForTesting() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService]
        SecItemDelete(query as CFDictionary)
    }

    private static func readInt(account: String) -> Int? {
        guard let str = readString(account: account) else { return nil }
        return Int(str)
    }

    private static func readString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeString(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
