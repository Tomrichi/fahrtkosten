import Foundation

// MARK: - RFC-3161-Zeitstempel ohne eigenen Server (Fahrtenbuchmodus, Baustein 2)
/// Holt für den Hash eines Änderungsprotokoll-Eintrags einen signierten, amtlichen
/// Zeitstempel von einer öffentlichen Time Stamping Authority. Beweist später, dass genau
/// dieser Hash (und damit die gesamte Kette bis zu diesem Punkt) bereits zu diesem
/// Zeitpunkt existiert hat – unabhängig von der (manipulierbaren) Systemzeit des Geräts.
/// Verifiziert gegen https://freetsa.org/tsr (kostenlos, öffentlich, per `openssl ts`
/// getestet) – es werden nur 32 Byte SHA-256-Hash übertragen, keine Fahrt- oder Ortsdaten.
enum TSAClient {
    private static let endpoint = URL(string: "https://freetsa.org/tsr")!

    /// Baut die DER-kodierte RFC-3161 TimeStampReq für einen SHA-256-Hash von Hand zusammen.
    /// Alle Felder dieser festen, kleinen Struktur bleiben < 128 Byte, daher reichen
    /// DER-Kurzform-Längen – keine zusätzliche ASN.1-Bibliothek nötig.
    ///
    /// TimeStampReq ::= SEQUENCE { version INTEGER(1), messageImprint MessageImprint,
    ///                             nonce INTEGER, certReq BOOLEAN(TRUE) }
    /// MessageImprint ::= SEQUENCE { hashAlgorithm AlgorithmIdentifier(SHA-256), hashedMessage OCTET STRING }
    static func buildTimeStampRequest(sha256Hash: Data) -> Data {
        precondition(sha256Hash.count == 32, "RFC 3161 erwartet einen 32-Byte SHA-256-Hash")

        let version: [UInt8] = [0x02, 0x01, 0x01]

        // AlgorithmIdentifier: SEQUENCE { OID 2.16.840.1.101.3.4.2.1 (SHA-256), NULL }
        let sha256OID: [UInt8] = [0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01]
        let nullParam: [UInt8] = [0x05, 0x00]
        let algIdContent = sha256OID + nullParam
        let algId: [UInt8] = [0x30, UInt8(algIdContent.count)] + algIdContent

        // hashedMessage: OCTET STRING (32 Byte)
        let hashedMessage: [UInt8] = [0x04, 0x20] + Array(sha256Hash)

        // messageImprint: SEQUENCE { algId, hashedMessage }
        let imprintContent = algId + hashedMessage
        let messageImprint: [UInt8] = [0x30, UInt8(imprintContent.count)] + imprintContent

        // nonce: INTEGER, 8 Zufallsbytes, höchstes Bit maskiert, damit die DER-Kodierung
        // ohne führendes Null-Byte als positive Zahl gültig bleibt.
        var nonceBytes = (0..<8).map { _ in UInt8.random(in: 0...255) }
        nonceBytes[0] &= 0x7F
        let nonce: [UInt8] = [0x02, UInt8(nonceBytes.count)] + nonceBytes

        // certReq: BOOLEAN TRUE
        let certReq: [UInt8] = [0x01, 0x01, 0xFF]

        let content = version + messageImprint + nonce + certReq
        let request: [UInt8] = [0x30, UInt8(content.count)] + content
        return Data(request)
    }

    /// Fragt freetsa.org nach einem Zeitstempel für den gegebenen SHA-256-Hash an.
    /// Gibt die rohen Antwort-Bytes (DER-kodiertes TimeStampResp) zurück – die App
    /// validiert/parst das Token nicht selbst, sondern speichert es nur base64-kodiert für
    /// eine spätere externe Prüfung. `nil` bei fehlendem Netz/Timeout – kein hartes Fehlschlagen.
    static func requestTimestamp(forHash hash: Data) async -> Data? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/timestamp-query", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildTimeStampRequest(sha256Hash: hash)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty else { return nil }
            return data
        } catch {
            return nil
        }
    }
}
