import SwiftUI
import WebKit

// MARK: - Versionshinweise View
struct VersionHistoryView: View {
    var body: some View {
        NavigationStack {
            HTMLWebView(html: versionHistoryHTML)
                .navigationTitle("Versionshinweise")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Datenschutz View
struct DatenschutzView: View {
    @EnvironmentObject var lm: LocalizationManager

    var body: some View {
        NavigationStack {
            HTMLWebView(html: datenschutzHTML(for: lm.language))
                .navigationTitle(lm.t("settings.privacy"))
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Impressum View
struct ImpressumView: View {
    var body: some View {
        NavigationStack {
            HTMLWebView(html: impressumHTML)
                .navigationTitle("Impressum")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Hilfe / App-Funktionen View
struct HilfeView: View {
    var body: some View {
        NavigationStack {
            HTMLWebView(html: hilfeHTML)
                .navigationTitle("App-Funktionen")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Bedienungshilfen View
struct BedienungshilfenView: View {
    var body: some View {
        NavigationStack {
            HTMLWebView(html: bedienungshilfenHTML)
                .navigationTitle("Bedienungshilfen")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - WebKit Wrapper
struct HTMLWebView: UIViewRepresentable {
    let html: String
    @Environment(\.colorScheme) var colorScheme

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.contentInset = .zero
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let scheme = colorScheme == .dark ? "dark" : "light"
        // data-scheme Attribut in <html> injizieren – wird sofort beim Laden gesetzt
        let patched = html.replacingOccurrences(
            of: "<html ",
            with: "<html data-scheme=\"\(scheme)\" "
        )
        webView.loadHTMLString(patched, baseURL: nil)

        webView.backgroundColor = colorScheme == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor.systemGroupedBackground
        webView.scrollView.backgroundColor = webView.backgroundColor
    }
}

// MARK: - Embedded HTML

// ─────────────────────────────────────────────────────────────────────────────
// IMPRESSUM
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// IMPRESSUM
// ─────────────────────────────────────────────────────────────────────────────
private let impressumHTML = #"""
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: -apple-system, sans-serif; font-size: 15px; line-height: 1.6;
         color: #1c1c1e; padding: 16px; max-width: 100%; word-break: break-word; }
  h1 { font-size: 20px; font-weight: 700; margin-top: 0; color: #ffffff; }
  h2 { font-size: 17px; font-weight: 600; margin-top: 24px; color: #ffffff; }
  h3 { font-size: 15px; font-weight: 600; margin-top: 16px; color: #3a3a3c; }
  p  { margin: 8px 0; }
  .box { background: #f2f2f7; border-radius: 10px; padding: 14px 16px; margin: 12px 0; }
  .hint { background: #fff3e0; border-left: 3px solid #ff9500;
          border-radius: 0 8px 8px 0; padding: 10px 14px; margin: 12px 0; font-size: 14px; }
  .meta { color: #636366; font-size: 13px; }
  a { color: #ffffff; text-decoration: none; }
  hr { border: none; border-top: 1px solid #e0e0e0; margin: 20px 0; }
  html[data-scheme="dark"] body { color: #f2f2f7; background: #1c1c1e; }
  html[data-scheme="dark"] h1 { color: #ffffff; }
  html[data-scheme="dark"] h2 { color: #ffffff; }
  html[data-scheme="dark"] h3 { color: #ebebf5; }
  html[data-scheme="dark"] .box { background: #2c2c2e; }
  html[data-scheme="dark"] .hint { background: #2a1a00; border-left-color: #ff9f0a; }
  html[data-scheme="dark"] hr { border-top-color: #3a3a3c; }
</style>
</head>
<body>

<h1>Impressum</h1>
<p class="meta">Angaben gemäß § 5 TMG (Telemediengesetz)</p>

<h2>Anbieter</h2>
<div class="box">
  <strong>Thomas Wagner</strong><br>
  Nebelhornstraße 12 A<br>
  86420 Diedorf<br>
  Deutschland
</div>

<h2>Kontakt</h2>
<div class="box">
  E-Mail: <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a>
</div>

<h2>Plattform &amp; Vertrieb</h2>
<p>Die App <strong>Fahrtkosten</strong> wird ausschließlich über den Apple App Store vertrieben.</p>
<p>App Store-Seite: <a href="https://apps.apple.com">apps.apple.com</a></p>
<p>Entwickler-Konto: Thomas Wagner</p>

<hr>

<h2>Umsatzsteuer</h2>
<p>Gemäß § 19 UStG wird keine Umsatzsteuer berechnet (Kleinunternehmerregelung).</p>

<hr>

<h2>Urheberrecht</h2>
<p>Die durch den App-Entwickler erstellten Inhalte und Werke dieser App unterliegen dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art der Verwertung außerhalb der Grenzen des Urheberrechts bedürfen der schriftlichen Zustimmung des jeweiligen Autors.</p>

<hr>

<h2>Haftungsausschluss</h2>

<h3>Haftung für Inhalte</h3>
<p>Die Inhalte dieser App wurden mit größtmöglicher Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der bereitgestellten Pauschalsätze und steuerlichen Informationen wird keine Gewähr übernommen. Die App ersetzt keine steuerliche oder rechtliche Beratung. Für eine verbindliche Auskunft wende dich an einen Steuerberater oder das zuständige Finanzamt.</p>

<h3>Haftung für Links</h3>
<p>Diese App enthält Links zu externen Webseiten Dritter, auf deren Inhalte kein Einfluss besteht. Für die Inhalte der verlinkten Seiten ist stets der jeweilige Anbieter oder Betreiber der Seiten verantwortlich.</p>

<hr>

<h2>Streitschlichtung</h2>
<p>Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS) bereit: <a href="https://ec.europa.eu/consumers/odr">ec.europa.eu/consumers/odr</a></p>
<p>Zur Teilnahme an einem Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle bin ich nicht verpflichtet und nicht bereit.</p>

<p class="meta" style="margin-top:32px;">Fahrtkosten · Version 1.16.11 · Thomas Wagner · 9. Juni 2026</p>

</body>
</html>
"""#

// ─────────────────────────────────────────────────────────────────────────────
// DATENSCHUTZERKLÄRUNG (DE · EN · PL · CS)
// ─────────────────────────────────────────────────────────────────────────────
private func datenschutzHTML(for lang: AppLanguage) -> String {
    switch lang {
    case .german:  return datenschutzHTML_de
    case .english: return datenschutzHTML_en
    case .polish:  return datenschutzHTML_pl
    case .czech:   return datenschutzHTML_cs
    }
}

private let datenschutzHTML_de = #"""
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: -apple-system, sans-serif; font-size: 15px; line-height: 1.6;
         color: #1c1c1e; padding: 16px; max-width: 100%; word-break: break-word; }
  h1 { font-size: 20px; font-weight: 700; margin-top: 0; color: #000000; }
  h2 { font-size: 17px; font-weight: 600; margin-top: 24px; color: #000000;
       border-bottom: 1px solid #e0e0e0; padding-bottom: 4px; }
  h3 { font-size: 15px; font-weight: 600; margin-top: 14px; color: #3a3a3c; }
  p  { margin: 8px 0; }
  .badge { display: inline-block; background: #e8f4fd; border-radius: 6px;
           padding: 4px 10px; font-size: 13px; margin: 3px 0; }
  .badge.ok   { background: #e6f7ec; }
  .badge.warn { background: #fff3e0; }
  .box { background: #f2f2f7; border-radius: 10px; padding: 12px 15px; margin: 10px 0; font-size: 14px; }
  .right { background: #eaf4ff; border-left: 3px solid #000000;
           border-radius: 0 8px 8px 0; padding: 10px 14px; margin: 8px 0; font-size: 14px; }
  .note { background: #fff3e0; border-left: 3px solid #ff9500;
          border-radius: 0 6px 6px 0; padding: 8px 12px; margin: 6px 0; font-size: 14px; }
  ul { padding-left: 20px; margin: 8px 0; }
  li { margin: 5px 0; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 13px; }
  th, td { border: 1px solid #c6c6c8; padding: 7px 9px; text-align: left; vertical-align: top; }
  th { background: #f2f2f7; font-weight: 600; }
  .meta { color: #636366; font-size: 13px; }
  .basis { color: #636366; font-size: 12px; font-style: italic; }
  a { color: #000000; }
  hr { border: none; border-top: 1px solid #e0e0e0; margin: 20px 0; }
  html[data-scheme="dark"] body { color: #f2f2f7; background: #1c1c1e; }
  html[data-scheme="dark"] h1 { color: #ffffff; }
  html[data-scheme="dark"] h2 { color: #ffffff; border-bottom-color: #3a3a3c; }
  html[data-scheme="dark"] h3 { color: #ebebf5; }
  html[data-scheme="dark"] .box { background: #2c2c2e; }
  html[data-scheme="dark"] .right { background: #1a2e40; border-left-color: #ffffff; }
  html[data-scheme="dark"] .note { background: #2a1a00; border-left-color: #ff9f0a; }
  html[data-scheme="dark"] .badge { background: #1c3a5a; }
  html[data-scheme="dark"] .badge.ok { background: #0d2e1a; }
  html[data-scheme="dark"] .badge.warn { background: #2a1a00; }
  html[data-scheme="dark"] th { background: #2c2c2e; }
  html[data-scheme="dark"] th, html[data-scheme="dark"] td { border-color: #3a3a3c; }
  html[data-scheme="dark"] hr { border-top-color: #3a3a3c; }
  html[data-scheme="dark"] a { color: #64acff; }
</style>
</head>
<body>

<h1>Datenschutzerklärung</h1>
<p class="meta">Fahrtkosten App · Version 1.16.11 · Stand 9. Juni 2026 · Build 21<br>
Entwickler: Thomas Wagner · info@wagner-fahrtkosten.de</p>

<h2>Auf einen Blick</h2>
<p><span class="badge ok">✅ Keine Registrierung oder Benutzerkonto erforderlich</span></p>
<p><span class="badge ok">✅ Alle Reise- und Kostendaten ausschließlich lokal auf deinem Gerät</span></p>
<p><span class="badge ok">✅ Kein Tracking, keine Werbung, keine Analyse-SDKs</span></p>
<p><span class="badge ok">✅ GPS-Rohdaten werden nicht dauerhaft gespeichert</span></p>
<p><span class="badge ok">✅ Keine Weitergabe deiner Daten an den Entwickler</span></p>
<p><span class="badge ok">✅ Belegscan (OCR) erfolgt vollständig lokal auf deinem Gerät – kein Cloud-Dienst</span></p>
<p><span class="badge ok">✅ Globale Suchfunktion arbeitet ausschließlich lokal – keine externen Abfragen</span></p>
<p><span class="badge warn">⚠️ Adressermittlung (Geocoding) über Apple MapKit</span></p>
<p><span class="badge warn">⚠️ Spritpreisabfrage sendet Standortkoordinaten an Tankerkönig API</span></p>

<hr>

<h2>1. Verantwortliche Stelle</h2>
<div class="box">
  Verantwortlich im Sinne der DSGVO (Art. 4 Nr. 7 DSGVO):<br><br>
  <strong>Thomas Wagner</strong><br>
  E-Mail: <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a>
</div>

<hr>

<h2>2. Grundsätze der Datenverarbeitung</h2>
<p>Die App verarbeitet personenbezogene Daten nach folgenden Grundsätzen (Art. 5 DSGVO):</p>
<ul>
  <li><strong>Zweckbindung:</strong> Daten werden ausschließlich für die Reisekostenabrechnung erhoben.</li>
  <li><strong>Datensparsamkeit:</strong> Es werden nur die für den jeweiligen Zweck notwendigen Daten verarbeitet.</li>
  <li><strong>Lokale Speicherung:</strong> Alle Daten verbleiben auf deinem Gerät und werden nicht an Server des Entwicklers übertragen.</li>
  <li><strong>Transparenz:</strong> Diese Erklärung beschreibt vollständig, welche Daten wie verarbeitet werden.</li>
</ul>

<hr>

<h2>3. Erhobene und verarbeitete Daten</h2>

<h3>3.1 Fahrten &amp; Reisedaten (lokal)</h3>
<p>Die App speichert folgende Daten ausschließlich lokal auf deinem Gerät (iOS Data Protection, vollverschlüsselt):</p>
<ul>
  <li><strong>Fahrten:</strong> Datum, Start- und Zielort, Kilometer, Abfahrts- und Ankunftszeit, berechnete Fahrzeit, Kraftstoffart, Spritpreis, Kraftstoffverbrauch, berechnete Erstattung, Notiz</li>
  <li><strong>Arbeitszeit &amp; Spesen:</strong> Datum, Region (Inland / Schweiz / Ausland), Arbeitszeit (Start/Ende), Pausenminuten, Verpflegungspauschalstufe, Abzüge für Drittmahlzeiten, eigenes Frühstück, „Am Werk gearbeitet"-Kennzeichen für die Monteurszulage, Notiz</li>
  <li><strong>Übernachtungen:</strong> Check-in- und Check-out-Datum, Anzahl Nächte, Stadt, Hotelname, Betrag (Pauschale oder tatsächlich)</li>
  <li><strong>KFZ-Kosten:</strong> Datum, Kategorie, Betrag, Notiz, optionaler Kilometerstand</li>
  <li><strong>Reisespesen:</strong> Datum, Kategorie, Betrag, Notiz</li>
  <li><strong>Private Ausgaben:</strong> Datum, Bezeichnung, Betrag – separat erfasst, nicht erstattungsfähig</li>
  <li><strong>Einstellungen:</strong> Pauschalsätze, Antriebsart mit Preis &amp; Verbrauch, Sprachauswahl, Wischgesten-Konfiguration</li>
</ul>
<p class="basis">Rechtsgrundlage: Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung / Bereitstellung der App-Funktionalität)</p>

<h3>3.2 Standortdaten (GPS-Aufzeichnung)</h3>
<p>Die GPS-Funktion ist <strong>optional</strong> und wird nur auf ausdrückliche Aktivierung genutzt.</p>
<ul>
  <li>GPS-Koordinaten werden <strong>ausschließlich im Arbeitsspeicher (RAM)</strong> verarbeitet und nach Abschluss der Fahrt sofort verworfen.</li>
  <li>Dauerhaft gespeichert werden nur: die berechneten <strong>Kilometer</strong>, die tatsächliche <strong>Fahrzeit</strong> sowie die per Geocoding ermittelten <strong>Adressen</strong> (Text).</li>
  <li>Ein Bewegungsprofil wird <strong>nicht</strong> angelegt.</li>
  <li>Intelligente Pause-Logik: Stillstand über 5 Minuten → Aufzeichnung pausiert automatisch; nach 30 Minuten Stillstand → automatischer Stopp.</li>
</ul>
<p><strong>Berechtigungen:</strong> Für die Hintergrundaufzeichnung ist „Standort immer erlauben" erforderlich. Du kannst den Standortzugriff jederzeit unter <em>iPhone-Einstellungen → Datenschutz &amp; Sicherheit → Ortungsdienste → Fahrtkosten</em> widerrufen.</p>
<p class="basis">Rechtsgrundlage: Art. 6 Abs. 1 lit. a DSGVO (ausdrückliche Einwilligung durch Aktivierung der GPS-Funktion)</p>

<h3>3.3 Belegscan &amp; Texterkennung (OCR)</h3>
<p>Die Texterkennung erfolgt ausschließlich mithilfe des <strong>Apple Vision Frameworks</strong> – vollständig lokal auf deinem Gerät. Belegfotos verlassen das Gerät zu keinem Zeitpunkt.</p>
<p class="basis">Rechtsgrundlage: Art. 6 Abs. 1 lit. a DSGVO (Einwilligung durch aktive Nutzung der Scan-Funktion)</p>

<h3>3.4 Spritpreisabfrage – Tankerkönig API</h3>
<p>Beim Anlegen einer neuen Fahrt können auf Wunsch aktuelle Kraftstoffpreise in der Nähe abgerufen werden. Dafür werden deine aktuellen <strong>Standortkoordinaten</strong> sowie die gewählte Kraftstoffart einmalig an die <strong>Tankerkönig API</strong> übermittelt.</p>
<div class="box">
  <strong>Dienstanbieter:</strong> Tankerkönig-World GmbH, Deutschland<br>
  <strong>Übermittelte Daten:</strong> Geografische Koordinaten, Kraftstoffart, Suchradius (5 km)<br>
  <strong>Übertragung:</strong> Verschlüsselt via HTTPS · Drittland-Übermittlung: Keine (Server DE/EU)
</div>
<p class="basis">Rechtsgrundlage: Art. 6 Abs. 1 lit. a DSGVO (Einwilligung durch aktive Nutzung der Funktion)</p>

<h3>3.5 Globale Suche</h3>
<p>Die Suchfunktion durchsucht ausschließlich die lokal gespeicherten Einträge aller Kategorien (Fahrten, Arbeitszeit, Übernachtungen, KFZ-Kosten, Reisespesen). Es findet keinerlei externe Übertragung oder Abfrage statt – die Suche läuft vollständig auf deinem Gerät.</p>
<p class="basis">Rechtsgrundlage: Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung)</p>

<h3>3.6 Apple MapKit (Adressermittlung)</h3>
<p>Nach Abschluss einer GPS-Fahrt wird der Endpunkt zur Adressermittlung über CLGeocoder an Apple-Server übertragen. Apple verknüpft diese Anfragen laut eigenen Angaben nicht mit deiner Apple ID. Mehr Infos: <a href="https://www.apple.com/legal/privacy/de-ww/">apple.com/legal/privacy</a></p>
<p class="basis">Rechtsgrundlage: Art. 6 Abs. 1 lit. f DSGVO (berechtigtes Interesse an nutzerfreundlicher Adressanzeige)</p>

<h3>3.7 App-Kauf (Einmalkauf)</h3>
<p>Fahrtkosten ist ein Einmalkauf im Apple App Store. Der Kaufvorgang wird ausschließlich über Apple abgewickelt. Die App verarbeitet <strong>keine Zahlungsdaten</strong>.</p>
<p class="basis">Rechtsgrundlage: Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung)</p>

<h3>3.8 Fehlerprotokolle</h3>
<p>Die App führt ein lokales Fehlerprotokoll, das ausschließlich auf deinem Gerät gespeichert wird. Du kannst es auf freiwilliger Basis per E-Mail an den Entwickler senden.</p>
<p class="basis">Rechtsgrundlage: Art. 6 Abs. 1 lit. a DSGVO (Einwilligung durch freiwilliges Versenden)</p>

<hr>

<h2>4. Übersicht der verarbeiteten Daten</h2>
<table>
  <tr>
    <th>Datenkategorie</th><th>Speicherort</th><th>Weitergabe</th><th>Rechtsgrundlage</th>
  </tr>
  <tr><td>Reise- und Kostendaten</td><td>Lokal (iOS, verschlüsselt)</td><td>Keine</td><td>Art. 6 I b</td></tr>
  <tr><td>GPS-Koordinaten (Aufzeichnung)</td><td>Nur RAM (nicht dauerhaft)</td><td>Keine</td><td>Art. 6 I a</td></tr>
  <tr><td>Belegfotos (OCR-Scan)</td><td>Nur RAM (nicht dauerhaft)</td><td>Keine (lokal via Vision)</td><td>Art. 6 I a</td></tr>
  <tr><td>GPS-Koordinaten (Spritpreisabfrage)</td><td>Temporär (nur API-Abfrage)</td><td>Tankerkönig API (DE/EU)</td><td>Art. 6 I a</td></tr>
  <tr><td>Adressen (Geocoding)</td><td>Lokal (nach Fahrt als Text)</td><td>Kurzzeitig an Apple MapKit</td><td>Art. 6 I f</td></tr>
  <tr><td>Suchanfragen</td><td>Nur Arbeitsspeicher</td><td>Keine</td><td>Art. 6 I b</td></tr>
  <tr><td>Private Ausgaben</td><td>Lokal (iOS, verschlüsselt)</td><td>Keine</td><td>Art. 6 I b</td></tr>
  <tr><td>Kaufstatus (Einmalkauf)</td><td>Lokal (UserDefaults)</td><td>Keine</td><td>Art. 6 I b</td></tr>
  <tr><td>Fehlerprotokoll</td><td>Lokal (iOS)</td><td>Optional per E-Mail</td><td>Art. 6 I a</td></tr>
</table>

<hr>

<h2>5. Datensicherheit</h2>
<ul>
  <li><strong>iOS Data Protection:</strong> Alle lokal gespeicherten Daten sind durch hardwarebasierte Verschlüsselung (AES-256) geschützt.</li>
  <li><strong>Kein eigener Server:</strong> Deine Reisedaten werden nicht an Server des Entwicklers übertragen.</li>
  <li><strong>HTTPS-Übertragung:</strong> Alle externen API-Abfragen erfolgen ausschließlich verschlüsselt über HTTPS/TLS.</li>
  <li><strong>GPS-Rohdaten nicht persistiert:</strong> Nach der Aufzeichnung werden nur aggregierte Werte gespeichert.</li>
</ul>

<hr>

<h2>6. Speicherdauer</h2>
<p>Daten werden so lange gespeichert, wie du die App nutzt. Du kannst einzelne Einträge jederzeit per Wischen löschen oder alle Daten unter <em>Einstellungen → Daten löschen</em> entfernen. Vollständige Löschung aller Daten inkl. Einstellungen durch Deinstallation der App.</p>

<hr>

<h2>7. Deine Rechte (Art. 15–22 DSGVO)</h2>
<p>Da alle Daten lokal auf deinem Gerät gespeichert sind, hast du jederzeit die volle Kontrolle.</p>
<div class="right"><strong>Auskunft (Art. 15)</strong> – Alle Daten sind direkt in der App einsehbar. Anfragen an info@wagner-fahrtkosten.de.</div>
<div class="right"><strong>Berichtigung (Art. 16)</strong> – Alle Einträge können jederzeit in der App bearbeitet werden.</div>
<div class="right"><strong>Löschung (Art. 17)</strong> – Per Wischen einzeln, oder alle Einträge unter Einstellungen → Daten löschen.</div>
<div class="right"><strong>Datenübertragbarkeit (Art. 20)</strong> – Export als CSV oder PDF über Tab Übersicht → Teilen-Symbol.</div>
<div class="right"><strong>Widerruf der Einwilligung (Art. 7 Abs. 3)</strong> – GPS-Zugriff jederzeit unter iPhone-Einstellungen → Datenschutz → Ortungsdienste → Fahrtkosten widerrufen.</div>
<div class="right"><strong>Beschwerde (Art. 77)</strong> – Beim Bayerischen Landesamt für Datenschutzaufsicht (BayLDA): <a href="https://www.lda.bayern.de">lda.bayern.de</a></div>

<hr>

<h2>8. Änderungen dieser Datenschutzerklärung</h2>
<p>Diese Datenschutzerklärung kann bei App-Updates aktualisiert werden. Die aktuelle Version ist stets in der App unter <em>Einstellungen → Info &amp; Datenschutz → Datenschutzerklärung</em> einsehbar.</p>

<hr>

<h2>9. Kontakt</h2>
<div class="box">
  <strong>Thomas Wagner</strong><br>
  E-Mail: <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a><br>
  Anfragen werden innerhalb von 30 Tagen beantwortet.
</div>

<p class="meta" style="margin-top:32px;">Fahrtkosten · Version 1.16.11 · Thomas Wagner · 9. Juni 2026</p>

</body>
</html>
"""#

// ── ENGLISH ──────────────────────────────────────────────────────────────────
private let datenschutzHTML_en = #"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: -apple-system, sans-serif; font-size: 15px; line-height: 1.6;
         color: #1c1c1e; padding: 16px; max-width: 100%; word-break: break-word; }
  h1 { font-size: 20px; font-weight: 700; margin-top: 0; color: #000000; }
  h2 { font-size: 17px; font-weight: 600; margin-top: 24px; color: #000000;
       border-bottom: 1px solid #e0e0e0; padding-bottom: 4px; }
  h3 { font-size: 15px; font-weight: 600; margin-top: 14px; color: #3a3a3c; }
  p  { margin: 8px 0; }
  .badge { display: inline-block; background: #e8f4fd; border-radius: 6px;
           padding: 4px 10px; font-size: 13px; margin: 3px 0; }
  .badge.ok   { background: #e6f7ec; }
  .badge.warn { background: #fff3e0; }
  .box { background: #f2f2f7; border-radius: 10px; padding: 12px 15px; margin: 10px 0; font-size: 14px; }
  .right { background: #eaf4ff; border-left: 3px solid #000000;
           border-radius: 0 8px 8px 0; padding: 10px 14px; margin: 8px 0; font-size: 14px; }
  .note { background: #fff3e0; border-left: 3px solid #ff9500;
          border-radius: 0 6px 6px 0; padding: 8px 12px; margin: 6px 0; font-size: 14px; }
  ul { padding-left: 20px; margin: 8px 0; }
  li { margin: 5px 0; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 13px; }
  th, td { border: 1px solid #c6c6c8; padding: 7px 9px; text-align: left; vertical-align: top; }
  th { background: #f2f2f7; font-weight: 600; }
  .meta { color: #636366; font-size: 13px; }
  .basis { color: #636366; font-size: 12px; font-style: italic; }
  a { color: #000000; }
  hr { border: none; border-top: 1px solid #e0e0e0; margin: 20px 0; }
  html[data-scheme="dark"] body { color: #f2f2f7; background: #1c1c1e; }
  html[data-scheme="dark"] h1 { color: #ffffff; }
  html[data-scheme="dark"] h2 { color: #ffffff; border-bottom-color: #3a3a3c; }
  html[data-scheme="dark"] h3 { color: #ebebf5; }
  html[data-scheme="dark"] .box { background: #2c2c2e; }
  html[data-scheme="dark"] .right { background: #1a2e40; border-left-color: #ffffff; }
  html[data-scheme="dark"] .note { background: #2a1a00; border-left-color: #ff9f0a; }
  html[data-scheme="dark"] .badge { background: #1c3a5a; }
  html[data-scheme="dark"] .badge.ok { background: #0d2e1a; }
  html[data-scheme="dark"] .badge.warn { background: #2a1a00; }
  html[data-scheme="dark"] th { background: #2c2c2e; }
  html[data-scheme="dark"] th, html[data-scheme="dark"] td { border-color: #3a3a3c; }
  html[data-scheme="dark"] hr { border-top-color: #3a3a3c; }
  html[data-scheme="dark"] a { color: #64acff; }
</style>
</head>
<body>

<h1>Privacy Policy</h1>
<p class="meta">Fahrtkosten App · Version 1.16.11 · June 9, 2026<br>
Developer: Thomas Wagner · info@wagner-fahrtkosten.de</p>

<h2>At a Glance</h2>
<p><span class="badge ok">✅ No registration or user account required</span></p>
<p><span class="badge ok">✅ All travel and cost data stored exclusively on your device</span></p>
<p><span class="badge ok">✅ No tracking, no ads, no analytics SDKs</span></p>
<p><span class="badge ok">✅ Raw GPS data is not permanently stored</span></p>
<p><span class="badge ok">✅ No data shared with the developer</span></p>
<p><span class="badge ok">✅ Receipt scan (OCR) runs entirely locally – no cloud service</span></p>
<p><span class="badge ok">✅ Global search works locally only – no external queries</span></p>
<p><span class="badge warn">⚠️ Address lookup (geocoding) via Apple MapKit</span></p>
<p><span class="badge warn">⚠️ Fuel price query sends location coordinates to Tankerkönig API</span></p>

<hr>

<h2>1. Data Controller</h2>
<div class="box">
  Responsible under GDPR (Art. 4 No. 7 GDPR):<br><br>
  <strong>Thomas Wagner</strong><br>
  E-Mail: <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a>
</div>

<hr>

<h2>2. Principles of Data Processing</h2>
<p>The app processes personal data according to the following principles (Art. 5 GDPR):</p>
<ul>
  <li><strong>Purpose limitation:</strong> Data is collected exclusively for travel expense accounting.</li>
  <li><strong>Data minimisation:</strong> Only data necessary for the respective purpose is processed.</li>
  <li><strong>Local storage:</strong> All data remains on your device and is not transmitted to developer servers.</li>
  <li><strong>Transparency:</strong> This policy fully describes what data is processed and how.</li>
</ul>

<hr>

<h2>3. Data Collected and Processed</h2>

<h3>3.1 Trip &amp; Travel Data (local)</h3>
<p>The app stores the following data exclusively locally on your device (iOS Data Protection, fully encrypted):</p>
<ul>
  <li><strong>Trips:</strong> Date, origin and destination, kilometres, departure and arrival time, calculated travel time, fuel type, fuel price, consumption, calculated reimbursement, note</li>
  <li><strong>Working hours &amp; subsistence:</strong> Date, region (domestic / Switzerland / abroad), working hours (start/end), break minutes, meal allowance level, deductions for employer-provided meals, note</li>
  <li><strong>Accommodation:</strong> Check-in and check-out date, number of nights, city, hotel name, amount (flat rate or actual)</li>
  <li><strong>Vehicle costs:</strong> Date, category, amount, note, optional mileage</li>
  <li><strong>Travel expenses:</strong> Date, category, amount, note</li>
  <li><strong>Private expenses:</strong> Date, description, amount – recorded separately, not reimbursable</li>
  <li><strong>Settings:</strong> Flat rates, drive type with price &amp; consumption, language selection, swipe gesture configuration</li>
</ul>
<p class="basis">Legal basis: Art. 6(1)(b) GDPR (performance of contract / provision of app functionality)</p>

<h3>3.2 Location Data (GPS Recording)</h3>
<p>The GPS feature is <strong>optional</strong> and only activated on explicit request.</p>
<ul>
  <li>GPS coordinates are processed <strong>exclusively in RAM</strong> and discarded immediately after the trip ends.</li>
  <li>Only the following are stored permanently: the calculated <strong>kilometres</strong>, the actual <strong>travel time</strong>, and the <strong>addresses</strong> determined via geocoding (as text).</li>
  <li>No movement profile is created.</li>
  <li>Smart pause logic: standstill over 5 minutes → recording pauses automatically; after 30 minutes → automatic stop.</li>
</ul>
<p><strong>Permissions:</strong> Background recording requires "Always allow" location. You can revoke access at any time under <em>iPhone Settings → Privacy &amp; Security → Location Services → Fahrtkosten</em>.</p>
<p class="basis">Legal basis: Art. 6(1)(a) GDPR (explicit consent through activation of the GPS feature)</p>

<h3>3.3 Receipt Scan &amp; OCR</h3>
<p>Text recognition is performed exclusively using the <strong>Apple Vision Framework</strong> – entirely locally on your device. Receipt photos never leave the device.</p>
<p class="basis">Legal basis: Art. 6(1)(a) GDPR (consent through active use of the scan feature)</p>

<h3>3.4 Fuel Price Query – Tankerkönig API</h3>
<p>When creating a new trip, you can optionally retrieve current fuel prices nearby. Your current <strong>location coordinates</strong> and selected fuel type are transmitted once to the <strong>Tankerkönig API</strong>.</p>
<div class="box">
  <strong>Service provider:</strong> Tankerkönig-World GmbH, Germany<br>
  <strong>Data transmitted:</strong> Geographic coordinates, fuel type, search radius (5 km)<br>
  <strong>Transfer:</strong> Encrypted via HTTPS · Third-country transfer: None (servers DE/EU)
</div>
<p class="basis">Legal basis: Art. 6(1)(a) GDPR (consent through active use of the feature)</p>

<h3>3.5 Global Search</h3>
<p>The search function searches only locally stored entries across all categories. No external transmission takes place – the search runs entirely on your device.</p>
<p class="basis">Legal basis: Art. 6(1)(b) GDPR (performance of contract)</p>

<h3>3.6 Apple MapKit (Address Lookup)</h3>
<p>After completing a GPS trip, the endpoint is transmitted to Apple servers for address lookup via CLGeocoder. According to Apple, these requests are not linked to your Apple ID. More info: <a href="https://www.apple.com/legal/privacy/en-ww/">apple.com/legal/privacy</a></p>
<p class="basis">Legal basis: Art. 6(1)(f) GDPR (legitimate interest in user-friendly address display)</p>

<h3>3.7 App Purchase (One-Time)</h3>
<p>Fahrtkosten is a one-time purchase in the Apple App Store. The purchase is handled exclusively by Apple. The app does <strong>not</strong> process any payment data.</p>
<p class="basis">Legal basis: Art. 6(1)(b) GDPR (performance of contract)</p>

<h3>3.8 Error Logs</h3>
<p>The app maintains a local error log stored exclusively on your device. You can optionally send it by e-mail to the developer.</p>
<p class="basis">Legal basis: Art. 6(1)(a) GDPR (consent through voluntary submission)</p>

<hr>

<h2>4. Data Overview</h2>
<table>
  <tr>
    <th>Data Category</th><th>Storage</th><th>Sharing</th><th>Legal Basis</th>
  </tr>
  <tr><td>Travel &amp; cost data</td><td>Local (iOS, encrypted)</td><td>None</td><td>Art. 6(1)(b)</td></tr>
  <tr><td>GPS coordinates (recording)</td><td>RAM only (not permanent)</td><td>None</td><td>Art. 6(1)(a)</td></tr>
  <tr><td>Receipt photos (OCR scan)</td><td>RAM only (not permanent)</td><td>None (local via Vision)</td><td>Art. 6(1)(a)</td></tr>
  <tr><td>GPS coordinates (fuel query)</td><td>Temporary (API call only)</td><td>Tankerkönig API (DE/EU)</td><td>Art. 6(1)(a)</td></tr>
  <tr><td>Addresses (geocoding)</td><td>Local (text after trip)</td><td>Briefly via Apple MapKit</td><td>Art. 6(1)(f)</td></tr>
  <tr><td>Search queries</td><td>RAM only</td><td>None</td><td>Art. 6(1)(b)</td></tr>
  <tr><td>Private expenses</td><td>Local (iOS, encrypted)</td><td>None</td><td>Art. 6(1)(b)</td></tr>
  <tr><td>Purchase status</td><td>Local (UserDefaults)</td><td>None</td><td>Art. 6(1)(b)</td></tr>
  <tr><td>Error log</td><td>Local (iOS)</td><td>Optional by e-mail</td><td>Art. 6(1)(a)</td></tr>
</table>

<hr>

<h2>5. Data Security</h2>
<ul>
  <li><strong>iOS Data Protection:</strong> All locally stored data is protected by hardware-based encryption (AES-256).</li>
  <li><strong>No own server:</strong> Your travel data is not transmitted to developer servers.</li>
  <li><strong>HTTPS transfer:</strong> All external API calls are exclusively encrypted via HTTPS/TLS.</li>
  <li><strong>Raw GPS data not persisted:</strong> Only aggregated values are stored after recording.</li>
</ul>

<hr>

<h2>6. Retention</h2>
<p>Data is stored as long as you use the app. You can delete individual entries at any time by swiping, or remove all data under <em>Settings → Delete Data</em>. Complete deletion including settings is achieved by uninstalling the app.</p>

<hr>

<h2>7. Your Rights (Art. 15–22 GDPR)</h2>
<p>Since all data is stored locally on your device, you have full control at all times.</p>
<div class="right"><strong>Access (Art. 15)</strong> – All data is directly visible in the app. Enquiries to info@wagner-fahrtkosten.de.</div>
<div class="right"><strong>Rectification (Art. 16)</strong> – All entries can be edited at any time in the app.</div>
<div class="right"><strong>Erasure (Art. 17)</strong> – Delete individually by swiping, or all entries under Settings → Delete Data.</div>
<div class="right"><strong>Data Portability (Art. 20)</strong> – Export as CSV or PDF via Overview tab → Share icon.</div>
<div class="right"><strong>Withdrawal of Consent (Art. 7(3))</strong> – GPS access can be revoked at any time under iPhone Settings → Privacy → Location Services → Fahrtkosten.</div>
<div class="right"><strong>Complaint (Art. 77)</strong> – To the Bavarian Data Protection Authority (BayLDA): <a href="https://www.lda.bayern.de">lda.bayern.de</a></div>

<hr>

<h2>8. Changes to This Privacy Policy</h2>
<p>This privacy policy may be updated with app updates. The current version is always available in the app under <em>Settings → Info &amp; Legal → Privacy Policy</em>.</p>

<hr>

<h2>9. Contact</h2>
<div class="box">
  <strong>Thomas Wagner</strong><br>
  E-Mail: <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a><br>
  Enquiries will be answered within 30 days.
</div>

<p class="meta" style="margin-top:32px;">Fahrtkosten · Version 1.15.4 · Thomas Wagner · May 26, 2026</p>

</body>
</html>
"""#

// ── POLSKI ───────────────────────────────────────────────────────────────────
private let datenschutzHTML_pl = #"""
<!DOCTYPE html>
<html lang="pl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: -apple-system, sans-serif; font-size: 15px; line-height: 1.6;
         color: #1c1c1e; padding: 16px; max-width: 100%; word-break: break-word; }
  h1 { font-size: 20px; font-weight: 700; margin-top: 0; color: #000000; }
  h2 { font-size: 17px; font-weight: 600; margin-top: 24px; color: #000000;
       border-bottom: 1px solid #e0e0e0; padding-bottom: 4px; }
  h3 { font-size: 15px; font-weight: 600; margin-top: 14px; color: #3a3a3c; }
  p  { margin: 8px 0; }
  .badge { display: inline-block; background: #e8f4fd; border-radius: 6px;
           padding: 4px 10px; font-size: 13px; margin: 3px 0; }
  .badge.ok   { background: #e6f7ec; }
  .badge.warn { background: #fff3e0; }
  .box { background: #f2f2f7; border-radius: 10px; padding: 12px 15px; margin: 10px 0; font-size: 14px; }
  .right { background: #eaf4ff; border-left: 3px solid #000000;
           border-radius: 0 8px 8px 0; padding: 10px 14px; margin: 8px 0; font-size: 14px; }
  ul { padding-left: 20px; margin: 8px 0; }
  li { margin: 5px 0; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 13px; }
  th, td { border: 1px solid #c6c6c8; padding: 7px 9px; text-align: left; vertical-align: top; }
  th { background: #f2f2f7; font-weight: 600; }
  .meta { color: #636366; font-size: 13px; }
  .basis { color: #636366; font-size: 12px; font-style: italic; }
  a { color: #000000; }
  hr { border: none; border-top: 1px solid #e0e0e0; margin: 20px 0; }
  html[data-scheme="dark"] body { color: #f2f2f7; background: #1c1c1e; }
  html[data-scheme="dark"] h1 { color: #ffffff; }
  html[data-scheme="dark"] h2 { color: #ffffff; border-bottom-color: #3a3a3c; }
  html[data-scheme="dark"] h3 { color: #ebebf5; }
  html[data-scheme="dark"] .box { background: #2c2c2e; }
  html[data-scheme="dark"] .right { background: #1a2e40; border-left-color: #ffffff; }
  html[data-scheme="dark"] .badge { background: #1c3a5a; }
  html[data-scheme="dark"] .badge.ok { background: #0d2e1a; }
  html[data-scheme="dark"] .badge.warn { background: #2a1a00; }
  html[data-scheme="dark"] th { background: #2c2c2e; }
  html[data-scheme="dark"] th, html[data-scheme="dark"] td { border-color: #3a3a3c; }
  html[data-scheme="dark"] hr { border-top-color: #3a3a3c; }
  html[data-scheme="dark"] a { color: #64acff; }
</style>
</head>
<body>

<h1>Polityka prywatności</h1>
<p class="meta">Fahrtkosten App · Wersja 1.16.11 · 9 Cze 2026<br>
Deweloper: Thomas Wagner · info@wagner-fahrtkosten.de</p>

<h2>W skrócie</h2>
<p><span class="badge ok">✅ Nie wymagana rejestracja ani konto użytkownika</span></p>
<p><span class="badge ok">✅ Wszystkie dane podróży i kosztów wyłącznie na Twoim urządzeniu</span></p>
<p><span class="badge ok">✅ Brak śledzenia, reklam i analitycznych SDK</span></p>
<p><span class="badge ok">✅ Surowe dane GPS nie są trwale przechowywane</span></p>
<p><span class="badge ok">✅ Żadne dane nie są przekazywane deweloperowi</span></p>
<p><span class="badge ok">✅ Skanowanie paragonów (OCR) odbywa się lokalnie – brak usługi chmurowej</span></p>
<p><span class="badge ok">✅ Globalne wyszukiwanie działa wyłącznie lokalnie</span></p>
<p><span class="badge warn">⚠️ Wyszukiwanie adresów (geokodowanie) przez Apple MapKit</span></p>
<p><span class="badge warn">⚠️ Zapytanie o ceny paliwa wysyła współrzędne lokalizacji do API Tankerkönig</span></p>

<hr>

<h2>1. Administrator danych</h2>
<div class="box">
  Administrator w rozumieniu RODO (art. 4 pkt 7 RODO):<br><br>
  <strong>Thomas Wagner</strong><br>
  E-Mail: <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a>
</div>

<hr>

<h2>2. Zasady przetwarzania danych</h2>
<p>Aplikacja przetwarza dane osobowe zgodnie z następującymi zasadami (art. 5 RODO):</p>
<ul>
  <li><strong>Ograniczenie celu:</strong> Dane są zbierane wyłącznie do rozliczania kosztów podróży.</li>
  <li><strong>Minimalizacja danych:</strong> Przetwarzane są tylko dane niezbędne dla danego celu.</li>
  <li><strong>Przechowywanie lokalne:</strong> Wszystkie dane pozostają na Twoim urządzeniu i nie są przesyłane na serwery dewelopera.</li>
  <li><strong>Przejrzystość:</strong> Niniejsza polityka w pełni opisuje, jakie dane są przetwarzane i w jaki sposób.</li>
</ul>

<hr>

<h2>3. Zbierane i przetwarzane dane</h2>

<h3>3.1 Dane podróży i kosztów (lokalne)</h3>
<p>Aplikacja przechowuje następujące dane wyłącznie lokalnie na Twoim urządzeniu (iOS Data Protection, pełne szyfrowanie):</p>
<ul>
  <li><strong>Podróże:</strong> Data, miejsce wyjazdu i docelowe, kilometry, godzina wyjazdu i przyjazdu, czas podróży, rodzaj paliwa, cena paliwa, zużycie, obliczony zwrot, notatka</li>
  <li><strong>Czas pracy i diety:</strong> Data, region (kraj / Szwajcaria / zagranica), godziny pracy (start/koniec), minuty przerwy, poziom diety, potrącenia za posiłki służbowe, notatka</li>
  <li><strong>Noclegi:</strong> Data zameldowania i wymeldowania, liczba nocy, miasto, nazwa hotelu, kwota (ryczałt lub rzeczywista)</li>
  <li><strong>Koszty pojazdu:</strong> Data, kategoria, kwota, notatka, opcjonalny przebieg</li>
  <li><strong>Wydatki podróżne:</strong> Data, kategoria, kwota, notatka</li>
  <li><strong>Wydatki prywatne:</strong> Data, opis, kwota – rejestrowane oddzielnie, niepodlegające zwrotowi</li>
  <li><strong>Ustawienia:</strong> Stawki ryczałtowe, typ napędu z ceną i zużyciem, wybór języka, konfiguracja gestów</li>
</ul>
<p class="basis">Podstawa prawna: art. 6 ust. 1 lit. b RODO (wykonanie umowy / świadczenie funkcjonalności aplikacji)</p>

<h3>3.2 Dane lokalizacji (nagrywanie GPS)</h3>
<p>Funkcja GPS jest <strong>opcjonalna</strong> i aktywowana wyłącznie na wyraźne żądanie.</p>
<ul>
  <li>Współrzędne GPS są przetwarzane <strong>wyłącznie w pamięci RAM</strong> i usuwane natychmiast po zakończeniu podróży.</li>
  <li>Trwale przechowywane są tylko: obliczone <strong>kilometry</strong>, rzeczywisty <strong>czas podróży</strong> oraz <strong>adresy</strong> uzyskane przez geokodowanie (jako tekst).</li>
  <li>Profil ruchu <strong>nie</strong> jest tworzony.</li>
  <li>Inteligentna pauza: postój ponad 5 minut → nagrywanie pauzuje automatycznie; po 30 minutach → automatyczne zatrzymanie.</li>
</ul>
<p><strong>Uprawnienia:</strong> Nagrywanie w tle wymaga „Zawsze zezwalaj" na lokalizację. Dostęp do lokalizacji możesz cofnąć w dowolnym momencie w <em>Ustawieniach iPhone → Prywatność → Usługi lokalizacji → Fahrtkosten</em>.</p>
<p class="basis">Podstawa prawna: art. 6 ust. 1 lit. a RODO (wyraźna zgoda przez aktywację funkcji GPS)</p>

<h3>3.3 Skanowanie paragonów i OCR</h3>
<p>Rozpoznawanie tekstu odbywa się wyłącznie przy użyciu <strong>Apple Vision Framework</strong> – całkowicie lokalnie na Twoim urządzeniu. Zdjęcia paragonów nigdy nie opuszczają urządzenia.</p>
<p class="basis">Podstawa prawna: art. 6 ust. 1 lit. a RODO (zgoda przez aktywne korzystanie z funkcji skanowania)</p>

<h3>3.4 Zapytanie o ceny paliwa – API Tankerkönig</h3>
<p>Przy tworzeniu nowej podróży możesz opcjonalnie pobrać aktualne ceny paliwa w pobliżu. Twoje bieżące <strong>współrzędne lokalizacji</strong> i wybrany rodzaj paliwa są jednorazowo przesyłane do <strong>API Tankerkönig</strong>.</p>
<div class="box">
  <strong>Usługodawca:</strong> Tankerkönig-World GmbH, Niemcy<br>
  <strong>Przesyłane dane:</strong> Współrzędne geograficzne, rodzaj paliwa, promień wyszukiwania (5 km)<br>
  <strong>Przesyłanie:</strong> Szyfrowane przez HTTPS · Transfer do państw trzecich: Brak (serwery DE/UE)
</div>
<p class="basis">Podstawa prawna: art. 6 ust. 1 lit. a RODO (zgoda przez aktywne korzystanie z funkcji)</p>

<h3>3.5 Globalne wyszukiwanie</h3>
<p>Funkcja wyszukiwania przeszukuje wyłącznie lokalne wpisy we wszystkich kategoriach. Żadna zewnętrzna transmisja danych nie ma miejsca – wyszukiwanie działa całkowicie na Twoim urządzeniu.</p>
<p class="basis">Podstawa prawna: art. 6 ust. 1 lit. b RODO (wykonanie umowy)</p>

<h3>3.6 Apple MapKit (wyszukiwanie adresów)</h3>
<p>Po zakończeniu podróży GPS punkt końcowy jest przesyłany do serwerów Apple w celu wyszukania adresu przez CLGeocoder. Według Apple te żądania nie są powiązane z Twoim Apple ID. Więcej informacji: <a href="https://www.apple.com/legal/privacy/pl-ww/">apple.com/legal/privacy</a></p>
<p class="basis">Podstawa prawna: art. 6 ust. 1 lit. f RODO (uzasadniony interes – przyjazne wyświetlanie adresów)</p>

<h3>3.7 Zakup aplikacji (jednorazowy)</h3>
<p>Fahrtkosten to jednorazowy zakup w Apple App Store. Transakcja jest realizowana wyłącznie przez Apple. Aplikacja <strong>nie</strong> przetwarza żadnych danych płatniczych.</p>
<p class="basis">Podstawa prawna: art. 6 ust. 1 lit. b RODO (wykonanie umowy)</p>

<h3>3.8 Dzienniki błędów</h3>
<p>Aplikacja prowadzi lokalny dziennik błędów przechowywany wyłącznie na Twoim urządzeniu. Możesz go opcjonalnie wysłać e-mailem do dewelopera.</p>
<p class="basis">Podstawa prawna: art. 6 ust. 1 lit. a RODO (zgoda przez dobrowolne przesłanie)</p>

<hr>

<h2>4. Przegląd przetwarzanych danych</h2>
<table>
  <tr>
    <th>Kategoria danych</th><th>Przechowywanie</th><th>Udostępnianie</th><th>Podstawa prawna</th>
  </tr>
  <tr><td>Dane podróży i kosztów</td><td>Lokalnie (iOS, zaszyfrowane)</td><td>Brak</td><td>Art. 6(1)(b)</td></tr>
  <tr><td>Współrzędne GPS (nagrywanie)</td><td>Tylko RAM (nietrwałe)</td><td>Brak</td><td>Art. 6(1)(a)</td></tr>
  <tr><td>Zdjęcia paragonów (OCR)</td><td>Tylko RAM (nietrwałe)</td><td>Brak (lokalnie przez Vision)</td><td>Art. 6(1)(a)</td></tr>
  <tr><td>Współrzędne GPS (ceny paliwa)</td><td>Tymczasowo (tylko zapytanie API)</td><td>Tankerkönig API (DE/UE)</td><td>Art. 6(1)(a)</td></tr>
  <tr><td>Adresy (geokodowanie)</td><td>Lokalnie (tekst po podróży)</td><td>Krótko przez Apple MapKit</td><td>Art. 6(1)(f)</td></tr>
  <tr><td>Zapytania wyszukiwania</td><td>Tylko RAM</td><td>Brak</td><td>Art. 6(1)(b)</td></tr>
  <tr><td>Wydatki prywatne</td><td>Lokalnie (iOS, zaszyfrowane)</td><td>Brak</td><td>Art. 6(1)(b)</td></tr>
  <tr><td>Status zakupu</td><td>Lokalnie (UserDefaults)</td><td>Brak</td><td>Art. 6(1)(b)</td></tr>
  <tr><td>Dziennik błędów</td><td>Lokalnie (iOS)</td><td>Opcjonalnie e-mailem</td><td>Art. 6(1)(a)</td></tr>
</table>

<hr>

<h2>5. Bezpieczeństwo danych</h2>
<ul>
  <li><strong>iOS Data Protection:</strong> Wszystkie lokalnie przechowywane dane są chronione sprzętowym szyfrowaniem (AES-256).</li>
  <li><strong>Brak własnego serwera:</strong> Dane podróży nie są przesyłane na serwery dewelopera.</li>
  <li><strong>Przesyłanie HTTPS:</strong> Wszystkie zewnętrzne wywołania API są szyfrowane przez HTTPS/TLS.</li>
  <li><strong>Surowe dane GPS nie są zapisywane:</strong> Po nagraniu zapisywane są tylko zagregowane wartości.</li>
</ul>

<hr>

<h2>6. Okres przechowywania</h2>
<p>Dane są przechowywane tak długo, jak korzystasz z aplikacji. Możesz usunąć pojedyncze wpisy w dowolnym momencie przez przesunięcie lub wszystkie dane w <em>Ustawienia → Usuń dane</em>. Pełne usunięcie danych i ustawień następuje przez odinstalowanie aplikacji.</p>

<hr>

<h2>7. Twoje prawa (art. 15–22 RODO)</h2>
<p>Ponieważ wszystkie dane są przechowywane lokalnie na Twoim urządzeniu, masz nad nimi pełną kontrolę.</p>
<div class="right"><strong>Dostęp (art. 15)</strong> – Wszystkie dane są bezpośrednio widoczne w aplikacji. Zapytania na adres info@wagner-fahrtkosten.de.</div>
<div class="right"><strong>Sprostowanie (art. 16)</strong> – Wszystkie wpisy można edytować w dowolnym momencie w aplikacji.</div>
<div class="right"><strong>Usunięcie (art. 17)</strong> – Usuń przez przesunięcie lub wszystkie wpisy w Ustawienia → Usuń dane.</div>
<div class="right"><strong>Przeniesienie danych (art. 20)</strong> – Eksport jako CSV lub PDF przez zakładkę Przegląd → ikona Udostępnij.</div>
<div class="right"><strong>Cofnięcie zgody (art. 7 ust. 3)</strong> – Dostęp GPS możesz cofnąć w Ustawieniach iPhone → Prywatność → Usługi lokalizacji → Fahrtkosten.</div>
<div class="right"><strong>Skarga (art. 77)</strong> – Do Bawarskiego Urzędu Ochrony Danych (BayLDA): <a href="https://www.lda.bayern.de">lda.bayern.de</a></div>

<hr>

<h2>8. Zmiany niniejszej polityki prywatności</h2>
<p>Niniejsza polityka prywatności może być aktualizowana wraz z aktualizacjami aplikacji. Aktualna wersja jest zawsze dostępna w aplikacji w <em>Ustawienia → Informacje i prawo → Polityka prywatności</em>.</p>

<hr>

<h2>9. Kontakt</h2>
<div class="box">
  <strong>Thomas Wagner</strong><br>
  E-Mail: <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a><br>
  Zapytania będą odpowiedzone w ciągu 30 dni.
</div>

<p class="meta" style="margin-top:32px;">Fahrtkosten · Wersja 1.15.4 · Thomas Wagner · 26 Maj 2026</p>

</body>
</html>
"""#

// ── ČEŠTINA ──────────────────────────────────────────────────────────────────
private let datenschutzHTML_cs = #"""
<!DOCTYPE html>
<html lang="cs">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: -apple-system, sans-serif; font-size: 15px; line-height: 1.6;
         color: #1c1c1e; padding: 16px; max-width: 100%; word-break: break-word; }
  h1 { font-size: 20px; font-weight: 700; margin-top: 0; color: #000000; }
  h2 { font-size: 17px; font-weight: 600; margin-top: 24px; color: #000000;
       border-bottom: 1px solid #e0e0e0; padding-bottom: 4px; }
  h3 { font-size: 15px; font-weight: 600; margin-top: 14px; color: #3a3a3c; }
  p  { margin: 8px 0; }
  .badge { display: inline-block; background: #e8f4fd; border-radius: 6px;
           padding: 4px 10px; font-size: 13px; margin: 3px 0; }
  .badge.ok   { background: #e6f7ec; }
  .badge.warn { background: #fff3e0; }
  .box { background: #f2f2f7; border-radius: 10px; padding: 12px 15px; margin: 10px 0; font-size: 14px; }
  .right { background: #eaf4ff; border-left: 3px solid #000000;
           border-radius: 0 8px 8px 0; padding: 10px 14px; margin: 8px 0; font-size: 14px; }
  ul { padding-left: 20px; margin: 8px 0; }
  li { margin: 5px 0; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 13px; }
  th, td { border: 1px solid #c6c6c8; padding: 7px 9px; text-align: left; vertical-align: top; }
  th { background: #f2f2f7; font-weight: 600; }
  .meta { color: #636366; font-size: 13px; }
  .basis { color: #636366; font-size: 12px; font-style: italic; }
  a { color: #000000; }
  hr { border: none; border-top: 1px solid #e0e0e0; margin: 20px 0; }
  html[data-scheme="dark"] body { color: #f2f2f7; background: #1c1c1e; }
  html[data-scheme="dark"] h1 { color: #ffffff; }
  html[data-scheme="dark"] h2 { color: #ffffff; border-bottom-color: #3a3a3c; }
  html[data-scheme="dark"] h3 { color: #ebebf5; }
  html[data-scheme="dark"] .box { background: #2c2c2e; }
  html[data-scheme="dark"] .right { background: #1a2e40; border-left-color: #ffffff; }
  html[data-scheme="dark"] .badge { background: #1c3a5a; }
  html[data-scheme="dark"] .badge.ok { background: #0d2e1a; }
  html[data-scheme="dark"] .badge.warn { background: #2a1a00; }
  html[data-scheme="dark"] th { background: #2c2c2e; }
  html[data-scheme="dark"] th, html[data-scheme="dark"] td { border-color: #3a3a3c; }
  html[data-scheme="dark"] hr { border-top-color: #3a3a3c; }
  html[data-scheme="dark"] a { color: #64acff; }
</style>
</head>
<body>

<h1>Zásady ochrany osobních údajů</h1>
<p class="meta">Fahrtkosten App · Verze 1.16.11 · 9. června 2026<br>
Vývojář: Thomas Wagner · info@wagner-fahrtkosten.de</p>

<h2>Stručný přehled</h2>
<p><span class="badge ok">✅ Není vyžadována registrace ani uživatelský účet</span></p>
<p><span class="badge ok">✅ Veškerá data cest a nákladů výhradně na Vašem zařízení</span></p>
<p><span class="badge ok">✅ Žádné sledování, reklamy ani analytické SDK</span></p>
<p><span class="badge ok">✅ Surová GPS data nejsou trvale ukládána</span></p>
<p><span class="badge ok">✅ Žádná data nejsou sdílena s vývojářem</span></p>
<p><span class="badge ok">✅ Skenování účtenek (OCR) probíhá zcela lokálně – bez cloudové služby</span></p>
<p><span class="badge ok">✅ Globální vyhledávání pracuje výhradně lokálně</span></p>
<p><span class="badge warn">⚠️ Vyhledávání adres (geokódování) přes Apple MapKit</span></p>
<p><span class="badge warn">⚠️ Dotaz na ceny paliva odesílá souřadnice polohy do API Tankerkönig</span></p>

<hr>

<h2>1. Správce osobních údajů</h2>
<div class="box">
  Správce ve smyslu GDPR (čl. 4 odst. 7 GDPR):<br><br>
  <strong>Thomas Wagner</strong><br>
  E-Mail: <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a>
</div>

<hr>

<h2>2. Zásady zpracování údajů</h2>
<p>Aplikace zpracovává osobní údaje v souladu s následujícími zásadami (čl. 5 GDPR):</p>
<ul>
  <li><strong>Omezení účelu:</strong> Údaje jsou shromažďovány výhradně pro účtování cestovních nákladů.</li>
  <li><strong>Minimalizace údajů:</strong> Zpracovávají se pouze údaje nezbytné pro daný účel.</li>
  <li><strong>Lokální úložiště:</strong> Veškerá data zůstávají na Vašem zařízení a nejsou přenášena na servery vývojáře.</li>
  <li><strong>Transparentnost:</strong> Tyto zásady plně popisují, jaké údaje jsou zpracovávány a jakým způsobem.</li>
</ul>

<hr>

<h2>3. Shromažďované a zpracovávané údaje</h2>

<h3>3.1 Údaje o cestách a nákladech (lokální)</h3>
<p>Aplikace ukládá následující údaje výhradně lokálně na Vašem zařízení (iOS Data Protection, plné šifrování):</p>
<ul>
  <li><strong>Cesty:</strong> Datum, místo odjezdu a cíl, kilometry, čas odjezdu a příjezdu, vypočítaná doba jízdy, druh paliva, cena paliva, spotřeba, vypočítaná náhrada, poznámka</li>
  <li><strong>Pracovní doba a diety:</strong> Datum, region (tuzemsko / Švýcarsko / zahraničí), pracovní doba (začátek/konec), minuty přestávky, úroveň stravného, srážky za jídla třetích stran, poznámka</li>
  <li><strong>Ubytování:</strong> Datum příjezdu a odjezdu, počet nocí, město, název hotelu, částka (paušál nebo skutečná)</li>
  <li><strong>Náklady na vozidlo:</strong> Datum, kategorie, částka, poznámka, volitelný stav km</li>
  <li><strong>Cestovní výdaje:</strong> Datum, kategorie, částka, poznámka</li>
  <li><strong>Soukromé výdaje:</strong> Datum, popis, částka – zaznamenány odděleně, nepodléhají náhradě</li>
  <li><strong>Nastavení:</strong> Paušální sazby, typ pohonu s cenou a spotřebou, výběr jazyka, konfigurace gest přejetí</li>
</ul>
<p class="basis">Právní základ: čl. 6 odst. 1 písm. b) GDPR (plnění smlouvy / poskytování funkcí aplikace)</p>

<h3>3.2 Údaje o poloze (nahrávání GPS)</h3>
<p>Funkce GPS je <strong>volitelná</strong> a aktivuje se výhradně na výslovnou žádost.</p>
<ul>
  <li>Souřadnice GPS jsou zpracovávány <strong>výhradně v paměti RAM</strong> a po ukončení cesty jsou okamžitě vymazány.</li>
  <li>Trvale jsou ukládány pouze: vypočítané <strong>kilometry</strong>, skutečná <strong>doba jízdy</strong> a <strong>adresy</strong> zjištěné geokódováním (jako text).</li>
  <li>Profil pohybu <strong>není</strong> vytvářen.</li>
  <li>Inteligentní pauza: stání déle než 5 minut → nahrávání se automaticky pozastaví; po 30 minutách → automatické zastavení.</li>
</ul>
<p><strong>Oprávnění:</strong> Nahrávání na pozadí vyžaduje „Vždy povolit" polohu. Přístup k poloze můžete kdykoli zrušit v <em>Nastavení iPhone → Soukromí → Poloha → Fahrtkosten</em>.</p>
<p class="basis">Právní základ: čl. 6 odst. 1 písm. a) GDPR (výslovný souhlas aktivací funkce GPS)</p>

<h3>3.3 Skenování účtenek a OCR</h3>
<p>Rozpoznávání textu probíhá výhradně pomocí <strong>Apple Vision Framework</strong> – zcela lokálně na Vašem zařízení. Fotografie účtenek nikdy neopustí zařízení.</p>
<p class="basis">Právní základ: čl. 6 odst. 1 písm. a) GDPR (souhlas aktivním použitím funkce skenování)</p>

<h3>3.4 Dotaz na ceny paliva – API Tankerkönig</h3>
<p>Při vytváření nové cesty můžete volitelně načíst aktuální ceny paliva v okolí. Vaše aktuální <strong>souřadnice polohy</strong> a vybraný druh paliva jsou jednorázově odeslány do <strong>API Tankerkönig</strong>.</p>
<div class="box">
  <strong>Poskytovatel služby:</strong> Tankerkönig-World GmbH, Německo<br>
  <strong>Přenášená data:</strong> Zeměpisné souřadnice, druh paliva, poloměr vyhledávání (5 km)<br>
  <strong>Přenos:</strong> Šifrovaně přes HTTPS · Přenos do třetích zemí: Žádný (servery DE/EU)
</div>
<p class="basis">Právní základ: čl. 6 odst. 1 písm. a) GDPR (souhlas aktivním použitím funkce)</p>

<h3>3.5 Globální vyhledávání</h3>
<p>Funkce vyhledávání prohledává pouze lokálně uložené záznamy ve všech kategoriích. Neprobíhá žádný externí přenos dat – vyhledávání běží zcela na Vašem zařízení.</p>
<p class="basis">Právní základ: čl. 6 odst. 1 písm. b) GDPR (plnění smlouvy)</p>

<h3>3.6 Apple MapKit (vyhledávání adres)</h3>
<p>Po ukončení GPS cesty je koncový bod přenesen na servery Apple pro vyhledání adresy přes CLGeocoder. Podle Apple nejsou tyto požadavky propojeny s Vaším Apple ID. Více informací: <a href="https://www.apple.com/legal/privacy/cs-ww/">apple.com/legal/privacy</a></p>
<p class="basis">Právní základ: čl. 6 odst. 1 písm. f) GDPR (oprávněný zájem – uživatelsky přívětivé zobrazení adresy)</p>

<h3>3.7 Nákup aplikace (jednorázový)</h3>
<p>Fahrtkosten je jednorázový nákup v Apple App Store. Nákup zajišťuje výhradně Apple. Aplikace <strong>nezpracovává</strong> žádné platební údaje.</p>
<p class="basis">Právní základ: čl. 6 odst. 1 písm. b) GDPR (plnění smlouvy)</p>

<h3>3.8 Protokoly chyb</h3>
<p>Aplikace vede lokální protokol chyb uložený výhradně na Vašem zařízení. Volitelně jej můžete zaslat e-mailem vývojáři.</p>
<p class="basis">Právní základ: čl. 6 odst. 1 písm. a) GDPR (souhlas dobrovolným zasláním)</p>

<hr>

<h2>4. Přehled zpracovávaných údajů</h2>
<table>
  <tr>
    <th>Kategorie údajů</th><th>Úložiště</th><th>Sdílení</th><th>Právní základ</th>
  </tr>
  <tr><td>Data cest a nákladů</td><td>Lokálně (iOS, šifrovaně)</td><td>Žádné</td><td>Čl. 6(1)(b)</td></tr>
  <tr><td>GPS souřadnice (nahrávání)</td><td>Pouze RAM (netrvalé)</td><td>Žádné</td><td>Čl. 6(1)(a)</td></tr>
  <tr><td>Fotografie účtenek (OCR)</td><td>Pouze RAM (netrvalé)</td><td>Žádné (lokálně přes Vision)</td><td>Čl. 6(1)(a)</td></tr>
  <tr><td>GPS souřadnice (ceny paliva)</td><td>Dočasně (pouze API dotaz)</td><td>Tankerkönig API (DE/EU)</td><td>Čl. 6(1)(a)</td></tr>
  <tr><td>Adresy (geokódování)</td><td>Lokálně (text po cestě)</td><td>Krátce přes Apple MapKit</td><td>Čl. 6(1)(f)</td></tr>
  <tr><td>Vyhledávací dotazy</td><td>Pouze RAM</td><td>Žádné</td><td>Čl. 6(1)(b)</td></tr>
  <tr><td>Soukromé výdaje</td><td>Lokálně (iOS, šifrovaně)</td><td>Žádné</td><td>Čl. 6(1)(b)</td></tr>
  <tr><td>Stav nákupu</td><td>Lokálně (UserDefaults)</td><td>Žádné</td><td>Čl. 6(1)(b)</td></tr>
  <tr><td>Protokol chyb</td><td>Lokálně (iOS)</td><td>Volitelně e-mailem</td><td>Čl. 6(1)(a)</td></tr>
</table>

<hr>

<h2>5. Zabezpečení dat</h2>
<ul>
  <li><strong>iOS Data Protection:</strong> Veškerá lokálně uložená data jsou chráněna hardwarovým šifrováním (AES-256).</li>
  <li><strong>Žádný vlastní server:</strong> Vaše cestovní data nejsou přenášena na servery vývojáře.</li>
  <li><strong>Přenos HTTPS:</strong> Veškerá volání externích API jsou šifrována přes HTTPS/TLS.</li>
  <li><strong>Surová GPS data nejsou ukládána:</strong> Po nahrávání jsou uloženy pouze souhrnné hodnoty.</li>
</ul>

<hr>

<h2>6. Doba uchovávání</h2>
<p>Data jsou uchovávána po dobu, kdy aplikaci používáte. Jednotlivé záznamy můžete kdykoli smazat přejetím nebo všechna data v <em>Nastavení → Smazat data</em>. Úplné smazání dat včetně nastavení provedete odinstalováním aplikace.</p>

<hr>

<h2>7. Vaše práva (čl. 15–22 GDPR)</h2>
<p>Protože veškerá data jsou uložena lokálně na Vašem zařízení, máte nad nimi plnou kontrolu.</p>
<div class="right"><strong>Přístup (čl. 15)</strong> – Veškerá data jsou přímo viditelná v aplikaci. Dotazy na info@wagner-fahrtkosten.de.</div>
<div class="right"><strong>Oprava (čl. 16)</strong> – Všechny záznamy lze kdykoli upravit v aplikaci.</div>
<div class="right"><strong>Výmaz (čl. 17)</strong> – Smazat přejetím nebo vše v Nastavení → Smazat data.</div>
<div class="right"><strong>Přenositelnost (čl. 20)</strong> – Export jako CSV nebo PDF přes záložku Přehled → ikona Sdílet.</div>
<div class="right"><strong>Odvolání souhlasu (čl. 7 odst. 3)</strong> – Přístup GPS lze kdykoli zrušit v Nastavení iPhone → Soukromí → Poloha → Fahrtkosten.</div>
<div class="right"><strong>Stížnost (čl. 77)</strong> – Bavorskému úřadu pro ochranu údajů (BayLDA): <a href="https://www.lda.bayern.de">lda.bayern.de</a></div>

<hr>

<h2>8. Změny těchto zásad</h2>
<p>Tyto zásady ochrany osobních údajů mohou být aktualizovány s aktualizacemi aplikace. Aktuální verze je vždy dostupná v aplikaci v <em>Nastavení → Info a právní → Zásady ochrany osobních údajů</em>.</p>

<hr>

<h2>9. Kontakt</h2>
<div class="box">
  <strong>Thomas Wagner</strong><br>
  E-Mail: <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a><br>
  Dotazy budou zodpovězeny do 30 dnů.
</div>

<p class="meta" style="margin-top:32px;">Fahrtkosten · Verze 1.15.4 · Thomas Wagner · 26. května 2026</p>

</body>
</html>
"""#

// ─────────────────────────────────────────────────────────────────────────────
// APP-FUNKTIONEN & ANLEITUNG
// ─────────────────────────────────────────────────────────────────────────────
private let hilfeHTML = #"""
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: -apple-system, sans-serif; font-size: 15px; line-height: 1.6;
         color: #1c1c1e; padding: 16px; max-width: 100%; word-break: break-word; }
  h1 { font-size: 22px; font-weight: 700; margin-top: 0; }
  h2 { font-size: 17px; font-weight: 600; margin-top: 28px; border-bottom: 1px solid #e0e0e0; padding-bottom: 4px; }
  h3 { font-size: 15px; font-weight: 600; margin-top: 14px; }
  p  { margin: 8px 0; }
  .subtitle { font-size: 16px; color: #636366; margin-top: -4px; margin-bottom: 16px; }
  .version { display: inline-block; background: #e8f4fd; border-radius: 6px;
             padding: 3px 10px; font-size: 13px; font-weight: 600; color: #0055bb; }
  .feature { padding: 5px 0; margin: 3px 0; font-size: 14px; line-height: 1.5; }
  .note { background: #fff3e0; border-left: 3px solid #ff9500;
          border-radius: 0 6px 6px 0; padding: 8px 12px; margin: 8px 0; font-size: 14px; }
  .tip  { background: #eaf4ff; border-left: 3px solid #007aff;
          border-radius: 0 6px 6px 0; padding: 8px 12px; margin: 8px 0; font-size: 14px; }
  ul { padding-left: 20px; margin: 8px 0; }
  li { margin: 5px 0; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 13px; }
  th, td { border: 1px solid #c6c6c8; padding: 7px 9px; text-align: left; }
  th { background: #f2f2f7; font-weight: 600; }
  .meta { color: #636366; font-size: 13px; }
  a { color: #007aff; }
  hr { border: none; border-top: 1px solid #e0e0e0; margin: 24px 0; }
  details.faq { background: #ffffff; border-radius: 12px; margin-bottom: 10px;
                overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.07); }
  details.faq summary { list-style: none; cursor: pointer; padding: 13px 16px;
                         display: flex; align-items: center; justify-content: space-between;
                         gap: 10px; font-weight: 600; font-size: 14px; user-select: none; }
  details.faq summary::-webkit-details-marker { display: none; }
  details.faq summary:hover { background: #f8f8f8; }
  details.faq[open] summary { border-bottom: 1px solid #e5e5ea; }
  .faq-chevron { font-size: 12px; color: #8e8e93; transition: transform 0.2s; flex-shrink: 0; }
  details.faq[open] .faq-chevron { transform: rotate(90deg); }
  .faq-body { padding: 12px 16px 14px; font-size: 14px; line-height: 1.6; }
  html[data-scheme="dark"] body { color: #f2f2f7; background: #1c1c1e; }
  html[data-scheme="dark"] h1, html[data-scheme="dark"] h2 { color: #ffffff; }
  html[data-scheme="dark"] h2 { border-bottom-color: #3a3a3c; }
  html[data-scheme="dark"] .version { background: #1c3a5a; color: #4da3ff; }
  html[data-scheme="dark"] .note { background: #2a1a00; border-left-color: #ff9f0a; }
  html[data-scheme="dark"] .tip  { background: #0a1e38; border-left-color: #4da3ff; }
  html[data-scheme="dark"] th { background: #2c2c2e; }
  html[data-scheme="dark"] th, html[data-scheme="dark"] td { border-color: #3a3a3c; }
  html[data-scheme="dark"] hr { border-top-color: #3a3a3c; }
  html[data-scheme="dark"] a { color: #4da3ff; }
  html[data-scheme="dark"] details.faq { background: #2c2c2e; box-shadow: 0 1px 3px rgba(0,0,0,0.3); }
  html[data-scheme="dark"] details.faq summary:hover { background: #3a3a3c; }
  html[data-scheme="dark"] details.faq[open] summary { border-bottom-color: #3a3a3c; }
  html[data-scheme="dark"] .faq-body { color: #f2f2f7; }
</style>
</head>
<body>

<h1>Fahrtkosten</h1>
<p class="subtitle">Dienstreisen professionell, korrekt &amp; steuerkonform abrechnen.</p>
<p><span class="version">Version 1.16.11</span></p>

<p>Fahrtkosten ist dein digitaler Reisekostenassistent für iPhone, iPad und Mac. Die App erfasst alle erstattungsfähigen Kosten einer Dienstreise – Fahrten, Verpflegung, Übernachtungen und Fahrzeugkosten – an einem Ort, berechnet alles automatisch nach den aktuellen gesetzlichen Pauschalsätzen und erstellt auf Knopfdruck eine fertige Abrechnung.</p>

<h2>Verfügbare Plattformen</h2>
<div class="feature">📱 <strong>iPhone &amp; iPad</strong> – Vollständiger Funktionsumfang inkl. GPS-Aufzeichnung, Live Activity, CarPlay und Apple Watch-Verbindung. Erfordert iOS 17 oder neuer.</div>
<div class="feature">💻 <strong>Mac (Apple Silicon)</strong> – Fahrtkosten läuft als „Designed for iPad" nativ auf Macs mit M1 oder neuer (macOS 14+). Alle Datenverwaltungsfunktionen verfügbar. GPS-Aufzeichnung, Live Activity, Dynamic Island und CarPlay sind iPhone-spezifisch und auf dem Mac nicht verfügbar.</div>
<div class="feature">⌚ <strong>Apple Watch</strong> – GPS-Fahrten direkt vom Handgelenk starten und stoppen. Erfordert watchOS 10 oder neuer.</div>

<hr>

<h2>Alle Features auf einen Blick</h2>
<div class="feature">🚗 <strong>Fahrten &amp; Kilometerpauschale</strong> – automatisch berechnet nach § 9 EStG (0,30 €/km, anpassbar)</div>
<div class="feature">🕐 <strong>Abfahrts- &amp; Ankunftszeit</strong> – pro Fahrt erfassbar, fließt in Verpflegungspauschale ein</div>
<div class="feature">📍 <strong>GPS-Streckenaufzeichnung</strong> – Hintergrundtracking mit intelligenter Pause- und Stopp-Automatik</div>
<div class="feature">🗺️ <strong>Apple Maps Integration</strong> – Kilometerzahl per Adresseingabe automatisch berechnen</div>
<div class="feature">🚘 <strong>CarPlay-Integration</strong> – GPS starten/stoppen, laufende Fahrt und Monatsübersicht direkt am Fahrzeugdisplay</div>
<div class="feature">⛽ <strong>5 Antriebsarten</strong> – Super E5, E10, Diesel, Elektro, Hybrid; Preis &amp; Verbrauch je Antriebsart getrennt gespeichert</div>
<div class="feature">⚡ <strong>Elektro &amp; Hybrid</strong> – Verbrauch in kWh/100 km; Hybrid berechnet Strom- und Benzinkosten getrennt</div>
<div class="feature">🔋 <strong>Live-Spritpreise</strong> – günstigster Preis in der Nähe via Tankerkönig API (Benzin/Diesel)</div>
<div class="feature">🍽️ <strong>Verpflegungspauschale</strong> – Fahrzeit + Arbeitszeit kombiniert, 3 Regionen (Inland, Schweiz, Ausland)</div>
<div class="feature">🔧 <strong>Monteurszulage</strong> – Lohnbestandteil, separat von der Verpflegungspauschale erfasst: 12 € Inland/am Werk, 50 € Ausland/Schweiz außerhalb des Werks; Sätze und Werk-Standort frei einstellbar</div>
<div class="feature">⏸️ <strong>Pausenzeit</strong> – abziehbare Pause pro Arbeitszeiterfassung einstellbar (0–120 min, 15-min-Schritte)</div>
<div class="feature">☕ <strong>Frühstück-Abrechnung</strong> – Verpflegung von Dritten abziehbar; eigenes bezahltes Frühstück addierbar</div>
<div class="feature">🏨 <strong>Übernachtungen</strong> – Pauschale oder tatsächliche Kosten; Check-in/Check-out mit automatischer Nächteberechnung</div>
<div class="feature">🔧 <strong>KFZ-Kosten</strong> – 9 Kategorien: Werkstatt · Leasing · Versicherung · TÜV/HU · KFZ-Steuer · Reifen · Strom/Laden · Fahrzeugwäsche · Sonstiges</div>
<div class="feature">📋 <strong>Reisespesen</strong> – 8 Kategorien: Werkstatt · Leasing · Vignette/Maut · Benzin · Strom/Laden · KFZ-Steuer · KFZ-Versicherung · Sonstiges</div>
<div class="feature">🔒 <strong>Private Ausgaben</strong> – separat erfasst, nicht in Gesamterstattung eingerechnet</div>
<div class="feature">🔍 <strong>Globale Suche</strong> – Freitextsuche und Datumsfilter über alle Kategorien gleichzeitig; Treffer werden direkt hervorgehoben</div>
<div class="feature">⌚ <strong>Apple Watch</strong> – Fahrten direkt am Handgelenk starten/stoppen; GPS-Fahrten per Watch-GPS; Monatsübersicht auf der Watch</div>
<div class="feature">📷 <strong>Belegscan</strong> – OCR per Kamera, Foto oder PDF; Betrag, Datum und Name automatisch erkannt; bei KFZ-Belegen werden alle Einzelpositionen separat erfasst</div>
<div class="feature">📊 <strong>Gesamtübersicht</strong> – Zeitraum-Filter (Woche · Monat · Jahr), aufklappbare Kacheln je Kategorie</div>
<div class="feature">📤 <strong>Export als CSV und PDF</strong> – inkl. Kilometer, Start- und Zielort, alle Kategorien</div>
<div class="feature">💾 <strong>Backup &amp; Wiederherstellen</strong> – lokal in der Dateien-App speichern oder per AirDrop/E-Mail/Cloud teilen</div>
<div class="feature">📋 <strong>Einträge duplizieren</strong> – Fahrten, Arbeitszeit und Übernachtungen per Swipe oder Langdruck kopieren</div>
<div class="feature">👆 <strong>Konfigurierbare Wischgesten</strong> – Aktion und Farbe für Swipe links/rechts frei wählbar</div>
<div class="feature">🌐 <strong>Mehrsprachig</strong> – Deutsch 🇩🇪 · Englisch 🇬🇧 · Polnisch 🇵🇱 · Tschechisch 🇨🇿</div>
<div class="feature">⚙️ <strong>Alle Pauschalsätze anpassbar</strong> – oder per Knopfdruck auf gesetzliche Standardwerte zurücksetzen</div>
<div class="feature">🔒 <strong>Keine Registrierung, kein Konto</strong> – alle Daten bleiben ausschließlich auf deinem Gerät</div>

<hr>

<h2>Tab Fahrten</h2>
<p>Erfasse dienstliche Fahrten mit Datum, Start- und Zielort und Kilometerzahl. Die Erstattung berechnet sich sofort: <em>Kilometer × Kilometerpauschale</em>. Abfahrts- und Ankunftszeit werden per Uhrzeit-Picker erfasst und fließen automatisch in die Verpflegungspauschale des Tages ein.</p>
<p>Antriebsart, Preis und Verbrauch sind in den Einstellungen dauerhaft voreinstellbar – pro Kraftstoffart getrennt gespeichert. Start- und Zieladresse können direkt eingegeben werden, die Kilometer werden via Apple Maps automatisch berechnet.</p>
<div class="tip">💡 <strong>Elektro &amp; Hybrid:</strong> Bei Elektrofahrzeugen wird der Verbrauch in kWh/100 km und der Preis in €/kWh erfasst. Hybrid berechnet Strom- und Benzinkosten getrennt und summiert sie automatisch.</div>
<div class="tip">💡 Einträge per Swipe oder Langdruck duplizieren – praktisch für regelmäßige Strecken.</div>

<h2>GPS-Aufzeichnung</h2>
<p>Starte die Live-Aufzeichnung über die GPS-Kachel in der Fahrten-Ansicht. Die App zeichnet die Strecke präzise im Hintergrund auf – auch wenn du das iPhone weglegest oder der Bildschirm gesperrt ist. Nach dem Stopp werden Kilometer und Fahrzeit automatisch ins Fahrtformular übernommen.</p>
<div class="note">ℹ️ Für die Hintergrundaufzeichnung ist der Standortzugriff „Immer erlauben" erforderlich: Einstellungen → Datenschutz → Ortungsdienste → Fahrtkosten.</div>
<div class="note">ℹ️ GPS-Aufzeichnung, Live Activity und CarPlay sind iPhone-spezifische Funktionen und auf dem Mac nicht verfügbar.</div>
<div class="tip">💡 Intelligente Automatik: Stillstand über 5 Minuten → Aufzeichnung pausiert. Nach 30 Minuten Stillstand → Aufzeichnung stoppt automatisch.</div>
<div class="tip">🚘 CarPlay-Nutzer sehen den Aufzeichnungsstatus direkt im Fahrzeugdisplay.</div>

<h2>Spritpreisabfrage</h2>
<p>Beim Anlegen einer neuen Fahrt tippst du auf den orangenen Kreis neben dem Spritpreisfeld. Nach einer Bestätigung, dass dein aktueller Standort verwendet wird, fragt die App die <strong>Tankerkönig API</strong> ab und trägt automatisch den aktuellen Preis im Umkreis von 50 km ein – für Benzin (E5/E10) und Diesel. Bei Elektroantrieb wird der in den Einstellungen gespeicherte Strompreis verwendet.</p>

<h2>Tab Arbeitszeit &amp; Verpflegung</h2>
<p>Erfasse die Arbeitszeit eines Tages mit Start- und Endzeit. Die App erkennt automatisch alle Fahrten des gleichen Tages und addiert Fahrzeit + Arbeitszeit zur <strong>Gesamtarbeitszeit</strong>. Optional kannst du eine <strong>Pausenzeit</strong> in 15-Minuten-Schritten (bis zu 120 min) abziehen.</p>
<table>
  <tr><th>Region</th><th>unter 3h</th><th>3 – 6h</th><th>ab 6h</th></tr>
  <tr><td>Inland (Deutschland)</td><td>0 €</td><td>14 €</td><td>28 €</td></tr>
  <tr><td>Schweiz</td><td>0 €</td><td>20 €</td><td>35 €</td></tr>
  <tr><td>Ausland</td><td>0 €</td><td>20 €</td><td>35 €</td></tr>
</table>
<p>Zusätzlich kann eine <strong>Monteurszulage</strong> erfasst werden: 12 € bei Region Inland, 18 € bei Region Schweiz, 50 € bei Region Ausland (jeweils außerhalb des Werks). Wird bei Region Schweiz/Ausland am Werk (Standort in den Einstellungen hinterlegt, z. B. Steffisburg) gearbeitet, gilt statt der Auslands-/Schweiz- die Inlands-Zulage. Die Monteurszulage wird üblicherweise über den Lohn ausbezahlt (steuer- und sozialversicherungspflichtiger Arbeitslohn) und ist deshalb <strong>nicht</strong> Teil der steuerfreien Verpflegungspauschale/Erstattung – sie wird in Liste, Formular, PDF- und CSV-Export klar getrennt als eigene Position ausgewiesen.</p>

<h2>Tab Übernachtung</h2>
<p>Erfasse Hotelübernachtungen mit Check-in- und Check-out-Datum – die Anzahl der Nächte wird automatisch berechnet. Wähle zwischen <strong>Pauschale</strong> oder <strong>tatsächlichen Kosten</strong>. Belege per Kamera oder Foto-Import scannen – OCR erkennt Betrag, Datum und Hotelname automatisch.</p>

<h2>Apple Watch</h2>
<p>Die Fahrtkosten Watch-App läuft eigenständig auf der Apple Watch und bietet zwei Möglichkeiten:</p>
<ul>
  <li><strong>Manuelle Fahrt:</strong> Start- und Zielort direkt auf der Watch eingeben – die Fahrt wird ans iPhone übertragen.</li>
  <li><strong>GPS-Fahrt:</strong> Fahrt per Tippen starten – die Watch nutzt ihren eigenen GPS-Chip und zeichnet die Strecke auf. Nach dem Stopp werden Kilometer, Start- und Zielort automatisch ans iPhone übergeben und als Fahrt gespeichert.</li>
</ul>
<p>Zusätzlich zeigt die Watch die aktuelle Monatsübersicht mit Gesamterstattung. Ein Langdruck öffnet das Kontextmenü zum manuellen Aktualisieren.</p>
<div class="tip">💡 Die GPS-Fahrt funktioniert auch ohne iPhone in der Nähe – Daten werden übertragen, sobald die Verbindung wieder besteht.</div>

<h2>Tab KFZ-Kosten</h2>
<p>Erfasse alle fahrzeugbezogenen Ausgaben in <strong>9 Kategorien</strong>: Werkstatt, Leasing, Versicherung, TÜV/HU, KFZ-Steuer, Reifen, Strom/Laden, Fahrzeugwäsche, Sonstiges. Der <strong>Zeitfilter</strong> (Woche / Monat / Jahr) filtert alle Kategorien gleichzeitig.</p>
<p>Belege per Kamera oder Foto-Import scannen – bei Werkstattrechnungen mit mehreren Positionen erkennt die App alle Einzelposten automatisch. In einem Überprüfungs-Sheet kannst du Kategorie, Bezeichnung und Betrag vor dem Speichern anpassen.</p>
<div class="note">ℹ️ KFZ-Kosten fließen nicht in die Gesamterstattung ein. Sie dienen der persönlichen Fahrzeugkostenübersicht.</div>

<h2>Tab Übersicht</h2>
<p>Alle Posten auf einen Blick: <strong>Gesamterstattung</strong> oben als dunkle Kachel (Fahrten + Verpflegung + Übernachtung), darunter aufklappbare Detailkacheln. Zeitraum-Filter (Woche · Monat · Jahr) oben. Export als CSV oder PDF über das Menü oben rechts.</p>

<h2>Tab Suche (NEU in 1.14.1)</h2>
<p>Die neue globale Suchfunktion durchsucht <strong>alle Kategorien gleichzeitig</strong> – Fahrten, Arbeitszeit, Übernachtungen, KFZ-Kosten und Reisespesen. Du kannst nach beliebigem Text suchen (Orte, Notizen, Hotelnamen, Kategorien) oder ein bestimmtes Datum auswählen. Kombiniere Text und Datum für präzise Ergebnisse.</p>
<ul>
  <li>Suchergebnisse sind nach Kategorie gruppiert mit Trefferanzahl</li>
  <li>Gefundene Textpassagen werden orange hervorgehoben</li>
  <li>Antippen eines Treffers öffnet direkt das Bearbeitungsformular</li>
  <li>Datumsfilter per Kalender-Button oben rechts</li>
</ul>
<div class="tip">💡 Tipp: Suche nach einem Datum ohne Textbegriff – so findest du alle Einträge eines bestimmten Tages kategorienübergreifend.</div>

<h2>Einstellungen</h2>
<p>Alle Pauschalsätze individuell anpassbar: Kilometerpauschale (Standard: 0,30 €/km), Verpflegungssätze (3 Stufen für Inland, Schweiz, Ausland), Monteurszulage (12 € Inland / 50 € Ausland, Werk-Standort frei einstellbar), Übernachtung/Frühstück, Antriebsart &amp; Kraftstoffpreise. Wischgesten, Backup und Protokoll sind als aufklappbare Menüs zusammengefasst.</p>

<h2>Backup &amp; Wiederherstellen</h2>
<p>Alle Daten lassen sich als JSON-Backup sichern. Über <strong>Lokal speichern</strong> wird das Backup in der Dateien-App abgelegt. Über <strong>Teilen</strong> kannst du es per AirDrop, E-Mail oder in Cloud-Dienste exportieren. Es werden maximal 10 lokale Backups aufbewahrt.</p>
<div class="tip">💡 Vor dem Löschen aller Daten immer ein Backup erstellen! Die Aktion kann nicht rückgängig gemacht werden.</div>

<hr>

<h2>Häufige Fragen (FAQ)</h2>

<details class="faq">
  <summary>Warum stimmt meine Verpflegungspauschale nicht?<span class="faq-chevron">›</span></summary>
  <div class="faq-body">
    Die Verpflegungspauschale ergibt sich aus der <strong>Gesamtarbeitszeit des Tages</strong> – also Fahrzeit aller Fahrten des gleichen Datums plus der eingetragenen Arbeitszeit. Prüfe ob Abfahrts- und Ankunftszeit bei deinen Fahrten korrekt eingetragen sind. Weniger als 3h Gesamtzeit ergibt 0 €.
  </div>
</details>

<details class="faq">
  <summary>Wie nutze ich die neue Suchfunktion?<span class="faq-chevron">›</span></summary>
  <div class="faq-body">
    Tippe auf den Tab <strong>Suche</strong> in der unteren Leiste. Gib einen Suchbegriff ein (z.B. Ortsname, Hotelname, Notiz) oder wähle über den Kalender-Button ein Datum. Treffer werden in allen Kategorien gleichzeitig gesucht und nach Kategorie gruppiert angezeigt. Tippe auf einen Eintrag um ihn direkt zu bearbeiten.
  </div>
</details>

<details class="faq">
  <summary>Wie erfasse ich ein Elektro- oder Hybridfahrzeug?<span class="faq-chevron">›</span></summary>
  <div class="faq-body">
    Wähle beim Anlegen einer Fahrt unter „Antriebsart" den Typ <strong>Elektro</strong> oder <strong>Hybrid</strong>. Bei Elektro gibst du Verbrauch in kWh/100 km und Preis in €/kWh ein. Hybrid berechnet Strom- und Benzinkosten getrennt und summiert automatisch. Standardwerte dauerhaft in den Einstellungen vorbelegen.
  </div>
</details>

<details class="faq">
  <summary>Wie funktioniert die GPS-Aufzeichnung im Hintergrund?<span class="faq-chevron">›</span></summary>
  <div class="faq-body">
    Starte die Aufzeichnung über die GPS-Kachel im Fahrten-Tab. Der Standortzugriff muss auf „Immer erlauben" gesetzt sein (Einstellungen → Datenschutz → Ortungsdienste → Fahrtkosten). Die Aufzeichnung pausiert automatisch nach 5 Minuten Stillstand und stoppt nach 30 Minuten.
  </div>
</details>

<details class="faq">
  <summary>Was ist der Unterschied zwischen KFZ-Kosten und Reisespesen?<span class="faq-chevron">›</span></summary>
  <div class="faq-body">
    <strong>KFZ-Kosten</strong> sind laufende Fahrzeugkosten (Werkstatt, Leasing, Versicherung, TÜV, Steuern, Reifen, Wäsche). Sie dienen der persönlichen Kostenübersicht und fließen nicht in die Erstattung ein.<br><br>
    <strong>Reisespesen</strong> sind reisebezogene Ausgaben (Benzin, Maut, Vignette etc.) die direkt mit einer Dienstreise zusammenhängen und in der Gesamtübersicht ausgewiesen werden.
  </div>
</details>

<details class="faq">
  <summary>Wie erstelle ich ein Backup und stelle es wieder her?<span class="faq-chevron">›</span></summary>
  <div class="faq-body">
    Gehe zu <strong>Einstellungen → Backup &amp; Wiederherstellen</strong>. Tippe auf „Backup lokal speichern" oder „Teilen" für Export per AirDrop/E-Mail/Cloud. Zum Wiederherstellen tippe auf „Backup wiederherstellen" und wähle die Datei. Achtung: Alle aktuellen Daten werden dabei ersetzt.
  </div>
</details>

<details class="faq">
  <summary>Wie exportiere ich meine Abrechnung als PDF oder CSV?<span class="faq-chevron">›</span></summary>
  <div class="faq-body">
    Im Tab <strong>Übersicht</strong> oben rechts auf das Teilen-Symbol tippen. Wähle „CSV exportieren" für eine tabellarische Auswertung oder „PDF Vorschau &amp; Export" für eine druckfertige Abrechnung. Der Export enthält alle Einträge des aktuell gewählten Zeitraums.
  </div>
</details>

<details class="faq">
  <summary>Werden meine Daten in die Cloud übertragen?<span class="faq-chevron">›</span></summary>
  <div class="faq-body">
    Nein. Alle Daten bleiben ausschließlich lokal auf deinem Gerät. Externe Dienste werden nur auf direkte Aktion genutzt: Tankerkönig für aktuelle Spritpreise und Apple MapKit für die Kilometerberechnung per Adresse. Die neue Suchfunktion arbeitet ebenfalls vollständig lokal.
  </div>
</details>

<details class="faq">
  <summary>Kann ich die Wischgesten anpassen?<span class="faq-chevron">›</span></summary>
  <div class="faq-body">
    Ja. Unter <strong>Einstellungen → Wischgesten</strong> kannst du für Swipe links und Swipe rechts jeweils eine Aktion (Löschen, Bearbeiten, Duplizieren) und eine Farbe frei wählen. Die Einstellung gilt für Fahrten, Arbeitszeiten und Übernachtungen.
  </div>
</details>

<details class="faq">
  <summary>Wie ändere ich die Sprache der App?<span class="faq-chevron">›</span></summary>
  <div class="faq-body">
    Unter <strong>Einstellungen → Sprache</strong> kannst du zwischen Deutsch, Englisch, Polnisch und Tschechisch wählen. Die Änderung wird sofort ohne Neustart übernommen.
  </div>
</details>

<p class="meta" style="margin-top:32px;">Fahrtkosten · Version 1.16.11 · Thomas Wagner · 9. Juni 2026<br>
Kontakt: <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a></p>

</body>
</html>
"""#

// ─────────────────────────────────────────────────────────────────────────────
// VERSIONSHINWEISE
// ─────────────────────────────────────────────────────────────────────────────
private let versionHistoryHTML = #"""
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body {
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
    font-size: 15px; line-height: 1.55; margin: 0;
    padding: 16px 18px 40px; background: #f2f2f7; color: #1c1c1e;
  }
  html[data-scheme="dark"] body { background: #1c1c1e; color: #f2f2f7; }
  html[data-scheme="dark"] details { background: #2c2c2e; box-shadow: 0 1px 3px rgba(0,0,0,0.3); }
  html[data-scheme="dark"] details summary { background: #2c2c2e; }
  html[data-scheme="dark"] details summary:hover { background: #3a3a3c; }
  html[data-scheme="dark"] details[open] summary { background: #2c2c2e; border-bottom: 1px solid #3a3a3c; }
  html[data-scheme="dark"] .detail-content { color: #f2f2f7; }
  html[data-scheme="dark"] .version-title { color: #f2f2f7; }
  html[data-scheme="dark"] .preview-text { color: #ebebf599; }
  html[data-scheme="dark"] .build-info { color: #8e8e93; }
  html[data-scheme="dark"] .chevron { color: #8e8e93; }
  html[data-scheme="dark"] li { color: #f2f2f7; }
  html[data-scheme="dark"] li strong { color: #ffffff; }
  html[data-scheme="dark"] .badge-new    { background: #0d2e1a; color: #30d158; }
  html[data-scheme="dark"] .badge-fix    { background: #2a1a00; color: #ff9f0a; }
  html[data-scheme="dark"] .badge-change { background: #1a1a2e; color: #64acff; }
  html[data-scheme="dark"] .current-badge { background: #0d2e1a; color: #30d158; }
  html[data-scheme="dark"] .meta { color: #8e8e93; }
  html[data-scheme="dark"] hr { border-top-color: #3a3a3c; }
  h1 { font-size: 22px; font-weight: 700; margin-bottom: 4px; }
  .meta { font-size: 13px; color: #6e6e73; margin-bottom: 20px; }
  details {
    background: #ffffff; border-radius: 14px; margin-bottom: 12px;
    overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  }
  details summary {
    list-style: none; cursor: pointer; padding: 14px 16px;
    display: flex; align-items: center; gap: 10px;
    user-select: none; background: #ffffff;
  }
  details summary::-webkit-details-marker { display: none; }
  details summary:hover { background: #f8f8f8; }
  details[open] summary { border-bottom: 1px solid #e5e5ea; }
  .summary-inner { flex: 1; display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .version-title { font-size: 15px; font-weight: 600; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
  .preview-text { font-size: 12px; color: #6e6e73; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .build-info { font-size: 12px; color: #8e8e93; white-space: nowrap; }
  .chevron { font-size: 12px; color: #8e8e93; transition: transform 0.2s; flex-shrink: 0; }
  details[open] .chevron { transform: rotate(90deg); }
  .detail-content { padding: 12px 16px 16px; }
  ul { margin: 0; padding-left: 18px; }
  li { margin-bottom: 7px; }
  .badge-new, .badge-fix, .badge-change, .current-badge {
    display: inline-block; border-radius: 5px; padding: 1px 7px;
    font-size: 11px; font-weight: 700; vertical-align: middle;
    margin-right: 2px; white-space: nowrap;
  }
  .badge-new    { background: #e6f7ec; color: #1a7a3c; }
  .badge-fix    { background: #fff3e0; color: #c0620a; }
  .badge-change { background: #e8f0ff; color: #2251cc; }
  .current-badge { background: #e6f7ec; color: #1a7a3c; font-size: 11px; }
</style>
</head>
<body>

<h1>Versionshinweise</h1>
<p class="meta">Fahrtkosten · Thomas Wagner</p>

<!-- 1.17.6 – aktuell -->
<details open>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.17.6
        <span class="current-badge">● Aktuell</span>
      </div>
      <div class="preview-text">Verpflegung &amp; Monteurszulage Schweiz jetzt korrekt in CHF</div>
    </div>
    <span class="build-info">15. Juli 2026 · Build 33</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-fix">FIX</span> <strong>Schweiz-Beträge in CHF statt €:</strong> Verpflegungspauschale (65 CHF ab 3 Stunden) und Monteurszulage (18 CHF) für Region Schweiz werden jetzt korrekt in CHF geführt.</li>
      <li><span class="badge-new">NEU</span> <strong>CHF-Kurs:</strong> Neuer, frei einstellbarer Wechselkurs unter Einstellungen → Verpflegungspauschalen – rechnet Schweiz-Beträge automatisch in € um, damit Gesamterstattung und Export stimmen.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.17.5 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.17.5
      </div>
      <div class="preview-text">Neu: Monteurszulage jetzt auch separat für die Schweiz einstellbar</div>
    </div>
    <span class="build-info">15. Juli 2026 · Build 32</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Monteurszulage – eigener Schweiz-Satz:</strong> Die Zulage bei Region Schweiz (außerhalb des Werks) nutzt jetzt einen eigenen, frei einstellbaren Satz statt des Auslands-Satzes. Damit gilt jeweils ein eigener Satz für Inland, Schweiz und Ausland.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.17.4 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.17.4
      </div>
      <div class="preview-text">Monteurszulage-Stundenregel · CarPlay-Fix ohne App-Start</div>
    </div>
    <span class="build-info">14. Juli 2026 · Build 31</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Monteurszulage – Stundenregel:</strong> Die Zulage wird jetzt nach der tatsächlichen Einsatzdauer gestaffelt – unter 3 Stunden keine Zulage, 3–6 Stunden 50 % der Pauschale, ab 6 Stunden volle Zulage.</li>
      <li><span class="badge-fix">FIX</span> <strong>CarPlay:</strong> GPS-Fahrt starten/stoppen funktioniert jetzt zuverlässig auch ohne die App vorher am iPhone geöffnet zu haben.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.17.2 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.17.2
      </div>
      <div class="preview-text">Neu: Monteurszulage (12 € Inland / 50 € Ausland)</div>
    </div>
    <span class="build-info">8. Juli 2026 · Build 30</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Monteurszulage:</strong> Pauschale Zulage – 12 € bei Region Inland (bzw. bei Arbeit am Werk), 50 € bei Region Schweiz/Ausland außerhalb des Werks. Werk-Standort, Inlands- und Auslandssatz sind unter Einstellungen → Monteurszulage frei einstellbar.</li>
      <li><span class="badge-new">NEU</span> <strong>„Am Werk gearbeitet"-Schalter:</strong> Beim Erfassen eines Verpflegungs-/Spesen-Eintrags mit Region Schweiz oder Ausland lässt sich angeben, ob am Werk (z. B. Steffisburg) gearbeitet wurde – dann gilt automatisch die Inlands-Zulage statt der Auslands-Zulage.</li>
      <li><span class="badge-change">INFO</span> Die Monteurszulage wird über den Lohn ausbezahlt und ist daher nicht Teil der Verpflegungspauschale/Erstattung – sie erscheint in Spesen-Liste, Formular, PDF- und CSV-Export als klar getrennte, eigene Position.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.16.12 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.16.12
      </div>
      <div class="preview-text">Beleg-Scanner runderneuert · Chronologische Sortierung</div>
    </div>
    <span class="build-info">1. Juli 2026 · Build 28</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Beleg-Scanner runderneuert:</strong> Automatischer Zuschnitt &amp; Entzerrung beim Fotografieren (Dokumentenscanner statt einfachem Foto), deutlich zuverlässigere Erkennung von Datum, Betrag und Name, auch bei mehrspaltigen Rechnungen.</li>
      <li><span class="badge-new">NEU</span> Fahrten und Arbeitszeiten werden beim Erfassen automatisch chronologisch sortiert.</li>
      <li><span class="badge-new">NEU</span> App merkt sich beim Schließen den zuletzt gewählten Tab und Zeitraum-Filter und öffnet wieder genau dort.</li>
      <li><span class="badge-change">VERBESSERUNG</span> PDF-Export sauberer strukturiert – Tabellenkopf wiederholt sich auf jeder Seite, mit Seitenzahlen.</li>
      <li><span class="badge-change">VERBESSERUNG</span> Übersicht erweitert – Verpflegungsausgaben und private Ausgaben lassen sich jetzt direkt dort erfassen.</li>
      <li><span class="badge-change">VERBESSERUNG</span> KFZ-Bereich aufgeräumt und übersichtlicher.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.16.11 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.16.11
      </div>
      <div class="preview-text">CarPlay Fixes · GPS-Übergabe bei Trennung · Titelkorrektur</div>
    </div>
    <span class="build-info">9. Juni 2026 · Build 21</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-fix">FIX</span> <strong>CarPlay Titel:</strong> Während der GPS-Aufzeichnung wird im CarPlay-Dashboard nun korrekt „GPS · Fahrt" angezeigt (zuvor „GPS · Fahrtkosten").</li>
      <li><span class="badge-new">NEU</span> <strong>Automatische GPS-Übergabe bei CarPlay-Trennung:</strong> Wird das iPhone vom Fahrzeug getrennt während eine GPS-Aufzeichnung läuft, stoppt die App die Aufzeichnung automatisch und öffnet das GPS-Sheet – so können Strecke und Daten direkt in der App geprüft und gespeichert werden.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.16.10 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.16.10
      </div>
      <div class="preview-text">CarPlay · GPS via Display · Geschäftlich/Privat · Arbeitszeit + Fahrten</div>
    </div>
    <span class="build-info">6. Juni 2026 · Build 20</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>CarPlay-Integration:</strong> GPS-Aufzeichnung starten und stoppen direkt am Fahrzeugdisplay – ohne das iPhone anfassen zu müssen. Das Dashboard zeigt laufende Fahrt, Fahrzeit, geschätzte Erstattung und Monatsübersicht.</li>
      <li><span class="badge-new">NEU</span> <strong>Geschäftlich / Privat:</strong> Beim Erfassen einer Fahrt kann nun zwischen Geschäftlich und Privat gewählt werden. Private Fahrten werden nicht in Erstattungen, Verpflegungspauschalen oder Arbeitszeit eingerechnet und sind in der Liste mit einem farbigen Icon gekennzeichnet.</li>
      <li><span class="badge-new">NEU</span> <strong>Arbeitszeit zeigt Fahrten automatisch:</strong> Geschäftliche Fahrten erscheinen nun automatisch im Arbeitszeit-Tab – auch wenn kein separater Arbeitszeit-Eintrag vorhanden ist. Fahrten und Arbeitszeit desselben Tages werden zusammengeführt und aufklappbar angezeigt.</li>
      <li><span class="badge-new">NEU</span> <strong>Verpflegungspauschale für Fahrt-only Tage:</strong> Ist nur eine Fahrt ohne Arbeitszeit-Eintrag vorhanden, berechnet die App die Verpflegungspauschale automatisch aus der Fahrtdauer – inkl. Heimfahrt-Regelung (halbe Pauschale vor 19:30 Uhr).</li>
      <li><span class="badge-new">NEU</span> <strong>Fahrtzeiten in der Fahrtenliste:</strong> Start- und Endzeit einer Fahrt werden nun direkt in der Fahrtenliste angezeigt (z. B. 08:00–09:00).</li>
      <li><span class="badge-new">NEU</span> <strong>Arbeitszeit gezielt löschen:</strong> Bei kombinierten Einträgen (Fahrt + Arbeitszeit) kann die Arbeitszeit über einen Mülleimer-Button einzeln gelöscht werden, ohne die Fahrt zu entfernen.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.15.4 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.16.10
      </div>
      <div class="preview-text">Mac-Unterstützung · Bedienungshilfen-Seite in App · Plattform-Info</div>
    </div>
    <span class="build-info">26. Mai 2026 · Build 13 (ersetzt durch 1.16.10)</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Mac-Verfügbarkeit:</strong> Fahrtkosten läuft als „Designed for iPad" nativ auf Macs mit Apple Silicon (M1+, macOS 14+).</li>
      <li><span class="badge-new">NEU</span> <strong>Bedienungshilfen-Seite in der App:</strong> Unter Einstellungen → Info → Bedienungshilfen gibt es jetzt eine eigene Seite mit Erklärungen zu VoiceOver, Reduzierter Bewegung, Dynamic Type und weiteren iOS-Bedienungshilfen.</li>
      <li><span class="badge-change">INFO</span> <strong>Plattformen:</strong> iPhone &amp; iPad (iOS 17+) · Mac mit Apple Silicon (macOS 14+) · Apple Watch (watchOS 10+).</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.15.2 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.15.2
      </div>
      <div class="preview-text">Bedienungshilfen · VoiceOver · Reduzierte Bewegung · Sprachsteuerung</div>
    </div>
    <span class="build-info">26. Mai 2026 · Build 10</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>VoiceOver-Unterstützung:</strong> Alle wichtigen Elemente der App – Fahrten, Statistik, Übersicht, KFZ-Kosten, Verpflegung, Übernachtungen u.&nbsp;v.&nbsp;m. – sind jetzt vollständig mit VoiceOver-Labels, Hinweisen und Rollen ausgestattet.</li>
      <li><span class="badge-new">NEU</span> <strong>Reduzierte Bewegung:</strong> Alle Animationen der App respektieren jetzt die iOS-Einstellung „Bewegung reduzieren" (Einstellungen → Bedienungshilfen). Wer auf Bewegungseffekte sensibel reagiert, kann sie damit deaktivieren.</li>
      <li><span class="badge-new">NEU</span> <strong>Sprachsteuerung (Voice Control):</strong> Alle Schaltflächen und interaktiven Elemente sind korrekt benannt – die App lässt sich vollständig per Sprachbefehl steuern.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.15.1 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.15.1
      </div>
      <div class="preview-text">Watch Geschwindigkeit · iCloud-Sync · Siri App Intents · Live Activity</div>
    </div>
    <span class="build-info">23. Mai 2026 · Build 8</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Apple Watch – Durchschnittsgeschwindigkeit:</strong> Die Watch zeigt während einer GPS-Fahrt jetzt Live-Geschwindigkeit und Durchschnittsgeschwindigkeit an.</li>
      <li><span class="badge-new">NEU</span> <strong>Watch GPS ohne iPhone:</strong> GPS-Fahrten auf der Watch funktionieren jetzt auch wenn das iPhone nicht in Reichweite ist. Die Daten werden automatisch übertragen sobald die Verbindung wiederhergestellt ist.</li>
      <li><span class="badge-new">NEU</span> <strong>iCloud-Sync für wiederkehrende Fahrten &amp; Favoriten:</strong> Wiederkehrende Fahrten und Favoriten werden automatisch über iCloud auf allen deinen Apple-Geräten synchronisiert.</li>
      <li><span class="badge-new">NEU</span> <strong>Menü-Shortcut für wiederkehrende Fahrten:</strong> Über das ⋯-Menü in der Hauptliste kannst du wiederkehrende Fahrten jetzt direkt aufrufen.</li>
      <li><span class="badge-new">NEU</span> <strong>Siri App Intents:</strong> „Hey Siri, starte eine Fahrt", „Wie viel km habe ich diesen Monat?" – die App unterstützt jetzt Siri-Kurzbefehle. In den Systemeinstellungen unter Kurzbefehle auffindbar.</li>
      <li><span class="badge-new">NEU</span> <strong>Live Activity:</strong> Während einer laufenden Fahrt wird eine Live Activity im Sperrbildschirm und in der Dynamic Island angezeigt.</li>
      <li><span class="badge-fix">FIX</span> <strong>Siri Intents – Datenzugriff:</strong> Siri-Kurzbefehle hatten keinen Zugriff auf App-Daten (falscher UserDefaults-Container). Jetzt vollständig behoben.</li>
      <li><span class="badge-fix">FIX</span> <strong>Watch – Haptisches Feedback:</strong> Die Watch gibt jetzt ein deutliches haptisches Signal wenn eine GPS-Fahrt gestartet oder gestoppt wird.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Build-Nummer vereinheitlicht:</strong> Widget und Share Extension verwenden jetzt dieselbe Build-Nummer wie die Haupt-App (Build 8).</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.14.5 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.14.5
      </div>
      <div class="preview-text">Watch GPS · KFZ-Belege · Mehrsprachiger Datenschutz · Übersicht</div>
    </div>
    <span class="build-info">Mai 2026 · Build 1</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Apple Watch – GPS-Fahrten:</strong> Fahrten direkt auf der Watch per GPS starten und stoppen. Die Watch nutzt ihren eigenen GPS-Chip. Nach dem Stopp werden Strecke, Start- und Zielort automatisch ans iPhone übertragen und gespeichert.</li>
      <li><span class="badge-new">NEU</span> <strong>Apple Watch – Kontextmenü:</strong> Langdruck auf die Watch-Hauptansicht öffnet ein Menü mit der Aktualisieren-Funktion.</li>
      <li><span class="badge-new">NEU</span> <strong>Datenschutzerklärung mehrsprachig:</strong> Die Datenschutzerklärung ist jetzt in Deutsch, Englisch, Polnisch und Tschechisch verfügbar – passt sich automatisch an die gewählte App-Sprache an.</li>
      <li><span class="badge-fix">FIX</span> <strong>KFZ-Kosten – Beleg speichern:</strong> Nach dem Scannen eines Belegs wurden keine Daten gespeichert – behoben.</li>
      <li><span class="badge-fix">FIX</span> <strong>KFZ-Kosten – Mehrere Artikel:</strong> Belege mit mehreren Positionen wurden nur als ein Eintrag erkannt. Jetzt werden alle Einzelpositionen erkannt und in einem Überprüfungs-Sheet angezeigt, wo Kategorie, Bezeichnung und Betrag vor dem Speichern angepasst werden können.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Übersicht – Badges entfernt:</strong> Die Kennzeichnungen „Ausgabe", „nicht erstattbar" und „privat" wurden aus den Kacheln entfernt.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.14.4 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.14.4
      </div>
      <div class="preview-text">Apple Watch · Widget · Bugfixes · E-Mail aktualisiert</div>
    </div>
    <span class="build-info">Mai 2026 · Build 1</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Apple Watch App:</strong> Fahrten direkt am Handgelenk starten und stoppen. Monatsübersicht und aktuelle Erstattung auf der Watch. Synchronisation über WatchConnectivity.</li>
      <li><span class="badge-new">NEU</span> <strong>Home Screen Widget:</strong> Monatssumme, Kilometeranzahl und Jahresvergleich direkt auf dem Homescreen – in drei Größen (klein, mittel, groß). Aktualisierung alle 30 Minuten.</li>
      <li><span class="badge-new">NEU</span> <strong>CarPlay-Unterstützung:</strong> Fahrtkosten ist jetzt über CarPlay erreichbar.</li>
      <li><span class="badge-fix">FIX</span> <strong>Watch App:</strong> Startbildschirm zeigte fälschlicherweise "Hello World" statt der korrekten Oberfläche – behoben.</li>
      <li><span class="badge-fix">FIX</span> <strong>GPS-Erkennung:</strong> Start- und Zielort zeigen nun nur noch die Stadt, keine vollständige Straßenadresse.</li>
      <li><span class="badge-fix">FIX</span> <strong>Spritpreisabfrage:</strong> Tankerkönig-API liefert nun zuverlässig aktuelle Kraftstoffpreise. Suchradius erweitert, verbesserte Fehlermeldungen.</li>
      <li><span class="badge-fix">FIX</span> <strong>Xcode-Warnungen:</strong> Asset Catalog Watch-Symbole korrekt zugeordnet, keine Build-Warnungen mehr.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Kontakt-E-Mail:</strong> Neue offizielle Support-Adresse info@wagner-fahrtkosten.de in der gesamten App.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Backup & Export:</strong> Verbesserter PDF-Export mit Vorschau, CSV Excel-kompatibel mit Semikolon-Trenner.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.14.3 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.14.3
      </div>
      <div class="preview-text">iCloud-Sync · Siri Shortcuts · Statistiken · Widget</div>
    </div>
    <span class="build-info">Mai 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>iCloud-Synchronisation:</strong> Alle Fahrtenbuch-Daten synchronisieren automatisch zwischen iPhone, iPad und Mac. Kein manueller Schritt nötig – Merge-Logik verhindert Datenverlust.</li>
      <li><span class="badge-new">NEU</span> <strong>Siri Shortcuts:</strong> Fahrten per Sprachbefehl starten und stoppen, Monatssumme abfragen oder Eintrag diktieren. Shortcuts erscheinen automatisch in der iOS Shortcuts-App. Laufende Fahrt wird als roter Banner in der App angezeigt.</li>
      <li><span class="badge-new">NEU</span> <strong>Statistiken & Auswertungen:</strong> Neuer Statistik-Tab in der Übersicht mit Monatschart, häufigsten Strecken und Jahres-Steuerauswertung für die Anlage N.</li>
      <li><span class="badge-new">NEU</span> <strong>Home Screen Widget:</strong> Monatssumme, Kilometeranzahl und Jahresvergleich direkt auf dem Homescreen – in drei Größen (klein, mittel, groß). Aktualisierung alle 30 Minuten.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Übersicht:</strong> Segment-Picker für schnellen Wechsel zwischen Dashboard und Statistik. Icon aktualisiert.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.14.2 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">
        Version 1.14.2
      </div>
      <div class="preview-text">Spritpreisabfrage · PDF-Vorschau · Bugfixes</div>
    </div>
    <span class="build-info">Mai 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-fix">FIX</span> <strong>Spritpreisabfrage:</strong> Tankerkönig-API liefert nun zuverlässig aktuelle Kraftstoffpreise. Suchradius auf 50 km erweitert, auch geschlossene Tankstellen werden als Fallback berücksichtigt.</li>
      <li><span class="badge-new">NEU</span> <strong>Standort-Bestätigung:</strong> Vor der Spritpreisabfrage erscheint eine Bestätigung, dass der aktuelle Standort verwendet wird.</li>
      <li><span class="badge-fix">FIX</span> <strong>PDF-Vorschau:</strong> Die Vorschau öffnet sich jetzt zuverlässig beim ersten Antippen – kein schwarzer Bildschirm mehr.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Copyright:</strong> Copyright-Hinweis am Ende der Einstellungen ergänzt.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.14.1 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">Version 1.14.1</div>
      <div class="preview-text">Globale Suche · Eigene Tab-Leiste · Verbesserungen</div>
    </div>
    <span class="build-info">Mai 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Globale Suchfunktion:</strong> Neuer Tab „Suche" durchsucht alle Kategorien gleichzeitig – Fahrten, Arbeitszeit, Übernachtungen, KFZ-Kosten und Reisespesen. Freitextsuche und Datumsfilter kombinierbar.</li>
      <li><span class="badge-new">NEU</span> <strong>Eigene Tab-Leiste:</strong> Alle 6 Tabs direkt sichtbar – kein „More"-Menü mehr.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Tab-Labels auf Deutsch:</strong> Vollständig deutsche Bezeichnungen in der Tab-Leiste.</li>
      <li><span class="badge-fix">FIX</span> <strong>Doppelte ContentView-Einträge:</strong> Korrekte Target Membership bei Xcode-Projektstruktur.</li>
    </ul>
  </div>
</details>

<hr>

<!-- 1.13.3 -->
<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">Version 1.13.3</div>
      <div class="preview-text">Zeitfilter · Splash Screen · Bugfixes</div>
    </div>
    <span class="build-info">Mai 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-fix">FIX</span> <strong>Zeitfilter KFZ Kosten:</strong> Fahrzeugwäsche und Private Ausgaben werden jetzt korrekt nach Woche / Monat / Jahr gefiltert.</li>
      <li><span class="badge-fix">FIX</span> <strong>Private Ausgaben Detail:</strong> Das Detail-Sheet zeigt jetzt ebenfalls nur Einträge des gewählten Zeitraums.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Splash Screen:</strong> App-Symbol, Titel und Tagline vergrößert. Wellen-Animation verstärkt. Anzeigedauer verlängert.</li>
    </ul>
  </div>
</details>

<hr>

<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">Version 1.13.2</div>
      <div class="preview-text">Übersicht · Einstellungen · KFZ Kosten</div>
    </div>
    <span class="build-info">Mai 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Übersicht – keine Doppeleinträge mehr:</strong> Alle Kategorien erscheinen nur noch einmal als aufklappbare Karte.</li>
      <li><span class="badge-new">NEU</span> <strong>Zeitfilter in KFZ Kosten:</strong> Woche / Monat / Jahr – Kacheln und Summen reagieren auf die Auswahl.</li>
      <li><span class="badge-new">NEU</span> <strong>Einträge direkt im Kategorie-Sheet bearbeiten:</strong> + Button oben links, Kategorie wird automatisch vorausgewählt.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Einstellungen kompakter:</strong> Aufklappbare Menüs für Wischgesten, Backup, Info &amp; Datenschutz sowie Protokoll.</li>
    </ul>
  </div>
</details>

<hr>

<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">Version 1.13.0</div>
      <div class="preview-text">iCloud Backup · Übersicht · Wischgesten</div>
    </div>
    <span class="build-info">April 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>iCloud Backup:</strong> Backups automatisch in iCloud Drive sichern – max. 10 Backups.</li>
      <li><span class="badge-new">NEU</span> <strong>Wischgesten mit Farbwahl:</strong> Aktion und Farbe für Swipe links/rechts individuell wählbar.</li>
      <li><span class="badge-new">NEU</span> <strong>Einträge duplizieren:</strong> Fahrten, Arbeitszeit und Übernachtungen per Swipe oder Langdruck kopieren.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Übersicht komplett überarbeitet:</strong> Gesamterstattung und Gesamtausgaben als aufklappbare dunkle Kacheln.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Zeitfilter als Chips:</strong> Woche · Monat · Jahr einheitlich in allen Tabs.</li>
    </ul>
  </div>
</details>

<hr>

<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">Version 1.12.25</div>
      <div class="preview-text">Elektro &amp; Hybrid · Strompreis · Einmalkauf</div>
    </div>
    <span class="build-info">April 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Elektrofahrzeug &amp; Hybrid:</strong> Antriebsart E5, E10, Diesel, Elektro oder Hybrid wählbar.</li>
      <li><span class="badge-new">NEU</span> <strong>Strompreis:</strong> Standardwert 0,30 €/kWh, in den Einstellungen dauerhaft anpassbar.</li>
      <li><span class="badge-change">ÄNDERUNG</span> <strong>Einmalkauf:</strong> Alle Funktionen dauerhaft freigeschaltet, kein Abonnement.</li>
    </ul>
  </div>
</details>

<hr>

<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">Version 1.12.24</div>
      <div class="preview-text">Fahrzeit &amp; Arbeitszeit · Live-Spritpreise · Belege</div>
    </div>
    <span class="build-info">April 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Fahrzeit &amp; Arbeitszeit kombiniert:</strong> Verpflegungspauschale basiert auf der Gesamtarbeitszeit.</li>
      <li><span class="badge-new">NEU</span> <strong>Live-Spritpreise:</strong> Aktuelle Kraftstoffpreise via Tankerkönig API.</li>
      <li><span class="badge-new">NEU</span> <strong>Belege scannen:</strong> OCR erkennt Betrag, Datum und Hotelname vollständig lokal.</li>
      <li><span class="badge-new">NEU</span> <strong>Private Ausgaben:</strong> Separat erfasst, nicht in Gesamterstattung eingerechnet.</li>
    </ul>
  </div>
</details>

<hr>

<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">Version 1.12.23</div>
      <div class="preview-text">OCR · KFZ-Kosten · CarPlay · Übernachtungen</div>
    </div>
    <span class="build-info">April 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>Belege scannen (OCR):</strong> Datum, Betrag und Name automatisch erkannt.</li>
      <li><span class="badge-new">NEU</span> <strong>Tab KFZ-Kosten:</strong> Neuer dedizierter Tab mit Kategorie-Kacheln.</li>
      <li><span class="badge-new">NEU</span> <strong>CarPlay-Integration:</strong> Aufzeichnungsstatus direkt im Fahrzeugdisplay.</li>
      <li><span class="badge-new">NEU</span> <strong>Datumsbereich für Übernachtungen:</strong> Nächteanzahl automatisch berechnet.</li>
    </ul>
  </div>
</details>

<hr>

<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">Version 1.10 – 1.11</div>
      <div class="preview-text">GPS-Tracking · Apple Maps · Verpflegung · Ausland</div>
    </div>
    <span class="build-info">April 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> <strong>GPS-Streckenaufzeichnung:</strong> Live-Tracking mit automatischer Kilometerberechnung.</li>
      <li><span class="badge-new">NEU</span> <strong>Apple Maps Integration:</strong> km automatisch aus Routenberechnung übernehmen.</li>
      <li><span class="badge-new">NEU</span> <strong>Verpflegung von Dritten &amp; eigenes Frühstück.</span></li>
      <li><span class="badge-new">NEU</span> <strong>Auslandsregion:</strong> Eigene Pauschalsätze für Auslandsreisen.</li>
    </ul>
  </div>
</details>

<hr>

<details>
  <summary>
    <div class="summary-inner">
      <div class="version-title">Version 1.0 – Erstveröffentlichung</div>
      <div class="preview-text">Fahrten · Erstattung · KFZ-Kosten</div>
    </div>
    <span class="build-info">April 2026</span>
    <span class="chevron">›</span>
  </summary>
  <div class="detail-content">
    <ul>
      <li><span class="badge-new">NEU</span> Fahrten erfassen mit Datum, Start- und Zielort sowie Kilometern.</li>
      <li><span class="badge-new">NEU</span> Automatische Erstattungsberechnung (Kilometer × Pauschale).</li>
      <li><span class="badge-new">NEU</span> KFZ-Kosten nach Kategorien erfassen.</li>
      <li><span class="badge-new">NEU</span> Alle Daten lokal – keine Registrierung erforderlich.</li>
    </ul>
  </div>
</details>

<p class="meta" style="margin-top:24px;">Fahrtkosten · Thomas Wagner · info@wagner-fahrtkosten.de</p>

</body>
</html>
"""#

// MARK: - Bedienungshilfen HTML
private let bedienungshilfenHTML = #"""
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    background: #f5f5f7; color: #1d1d1f; line-height: 1.6; font-size: 16px;
  }
  .container { max-width: 820px; margin: 0 auto; padding: 24px 18px 60px; }
  .intro-card {
    background: linear-gradient(135deg, #4a7fa5 0%, #3d6e8f 100%);
    border-radius: 16px; padding: 22px 24px; margin-bottom: 16px;
    color: white; box-shadow: 0 4px 20px rgba(74,127,165,0.3);
  }
  .intro-card h2 { font-size: 1.1rem; font-weight: 700; margin-bottom: 6px; }
  .intro-card p { color: rgba(255,255,255,0.85); font-size: 0.9rem; margin: 0; }
  .section {
    background: #fff; border-radius: 16px; padding: 22px 18px;
    margin-bottom: 14px; box-shadow: 0 2px 10px rgba(0,0,0,0.07);
  }
  .section-header {
    display: flex; align-items: center; gap: 12px;
    margin-bottom: 16px; padding-bottom: 14px; border-bottom: 1px solid #f0f0f0;
  }
  .section-icon {
    background: #ddeaf4; color: #4a7fa5; width: 34px; height: 34px;
    border-radius: 10px; display: flex; align-items: center;
    justify-content: center; font-size: 1rem; flex-shrink: 0;
  }
  .section-header h2 { font-size: 1.1rem; font-weight: 700; }
  p { margin: 8px 0; color: #3a3a3c; font-size: 0.93rem; }
  p:first-child { margin-top: 0; }
  strong { color: #1d1d1f; }
  a { color: #4a7fa5; text-decoration: none; }
  .tip {
    background: #edf4f9; border-left: 3px solid #4a7fa5;
    border-radius: 0 10px 10px 0; padding: 11px 14px; margin: 12px 0;
    font-size: 0.88rem; color: #1d3557;
  }
  .tip strong { color: #4a7fa5; }
  .note {
    background: #f5f5f7; border-radius: 10px; padding: 12px 14px;
    margin: 12px 0; font-size: 0.88rem; color: #3a3a3c; border: 1px solid #e5e5e7;
  }
  .note-label {
    font-weight: 700; font-size: 0.7rem; letter-spacing: 0.07em;
    text-transform: uppercase; color: #6e6e73; margin-bottom: 4px;
  }
  .subsection { margin-top: 20px; }
  .subsection h3 { font-size: 0.9rem; font-weight: 600; color: #1d1d1f; margin-bottom: 8px; }
  .feature-list { list-style: none; display: flex; flex-direction: column; gap: 9px; margin-top: 8px; }
  .feature-list li { display: flex; align-items: flex-start; gap: 10px; font-size: 0.9rem; color: #3a3a3c; }
  .feature-list li .check { color: #4a7fa5; font-size: 0.95rem; flex-shrink: 0; margin-top: 1px; }
  .steps { display: flex; flex-direction: column; gap: 8px; margin-top: 8px; }
  .step {
    display: flex; align-items: flex-start; gap: 12px;
    background: #f9f9fb; border-radius: 10px; padding: 10px 14px;
  }
  .step-num {
    background: #4a7fa5; color: white; width: 22px; height: 22px; border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    font-size: 0.72rem; font-weight: 700; flex-shrink: 0; margin-top: 1px;
  }
  .step-text { font-size: 0.88rem; color: #3a3a3c; line-height: 1.5; }
  .step-text strong { color: #1d1d1f; }
  .badge-row { display: flex; flex-wrap: wrap; gap: 7px; margin-top: 12px; }
  .badge {
    background: #edf4f9; color: #1d3557; border-radius: 20px;
    padding: 4px 12px; font-size: 0.8rem; font-weight: 500; border: 1px solid #c8dcea;
  }
  .footer-meta {
    text-align: center; color: #6e6e73; font-size: 0.82rem;
    margin-top: 24px; padding-bottom: 16px; line-height: 1.8;
  }
</style>
</head>
<body>
<div class="container">

  <div class="intro-card">
    <h2>Fahrtkosten ist für alle zugänglich</h2>
    <p>Die App unterstützt die Bedienungshilfen von iOS vollständig –
    damit jeder Nutzer die App sicher und bequem verwenden kann,
    unabhängig von körperlichen Einschränkungen oder persönlichen Vorlieben.</p>
  </div>

  <!-- VoiceOver -->
  <div class="section">
    <div class="section-header">
      <div class="section-icon">🔊</div>
      <h2>VoiceOver</h2>
    </div>
    <p>Fahrtkosten unterstützt <strong>VoiceOver</strong> vollständig –
    Apples eingebauten Screenreader für blinde und sehbehinderte Nutzer.</p>
    <ul class="feature-list" style="margin-top:12px;">
      <li><span class="check">✓</span> Alle Schaltflächen und Symbole haben aussagekräftige Beschriftungen</li>
      <li><span class="check">✓</span> Datenkacheln werden vollständig vorgelesen</li>
      <li><span class="check">✓</span> Listeneinträge enthalten Datum, Strecke, Kilometer und Erstattungsbetrag</li>
      <li><span class="check">✓</span> Der aktive Fahrt-Banner nennt Ziel und vergangene Fahrzeit</li>
      <li><span class="check">✓</span> Filter und Tabs zeigen den ausgewählten Zustand an</li>
      <li><span class="check">✓</span> Dekorative Grafiken sind für Screenreader ausgeblendet</li>
    </ul>
    <div class="subsection">
      <h3>VoiceOver aktivieren</h3>
      <div class="steps">
        <div class="step"><div class="step-num">1</div><div class="step-text"><strong>Einstellungen</strong> öffnen</div></div>
        <div class="step"><div class="step-num">2</div><div class="step-text"><strong>Bedienungshilfen</strong> antippen</div></div>
        <div class="step"><div class="step-num">3</div><div class="step-text"><strong>VoiceOver</strong> antippen und einschalten</div></div>
      </div>
    </div>
    <div class="tip" style="margin-top:14px;">
      <strong>Tipp:</strong> VoiceOver lässt sich auch per dreifachem Drücken der Seitentaste
      ein- und ausschalten – sobald es unter <em>Einstellungen → Bedienungshilfen → Kurzbefehl</em>
      eingerichtet wurde.
    </div>
  </div>

  <!-- Reduzierte Bewegung -->
  <div class="section">
    <div class="section-header">
      <div class="section-icon">✋</div>
      <h2>Reduzierte Bewegung</h2>
    </div>
    <p>Alle Animationen der App respektieren die iOS-Einstellung
    <strong>„Bewegung reduzieren"</strong>. Wer auf Bewegungseffekte sensibel reagiert,
    kann sie vollständig deaktivieren.</p>
    <div class="steps" style="margin-top:12px;">
      <div class="step"><div class="step-num">1</div><div class="step-text"><strong>Einstellungen</strong> öffnen</div></div>
      <div class="step"><div class="step-num">2</div><div class="step-text"><strong>Bedienungshilfen → Bewegung</strong> antippen</div></div>
      <div class="step"><div class="step-num">3</div><div class="step-text"><strong>Bewegung reduzieren</strong> einschalten</div></div>
    </div>
  </div>

  <!-- Dynamic Type -->
  <div class="section">
    <div class="section-header">
      <div class="section-icon">🔤</div>
      <h2>Dynamic Type – Schriftgröße</h2>
    </div>
    <p>Fahrtkosten passt sich automatisch der Schriftgröße an,
    die du in den iOS-Einstellungen festgelegt hast – von sehr klein bis extra-groß.</p>
    <div class="steps" style="margin-top:12px;">
      <div class="step"><div class="step-num">1</div><div class="step-text"><strong>Einstellungen</strong> öffnen</div></div>
      <div class="step"><div class="step-num">2</div><div class="step-text"><strong>Bedienungshilfen → Anzeige &amp; Textgröße</strong> antippen</div></div>
      <div class="step"><div class="step-num">3</div><div class="step-text"><strong>Größerer Text</strong> aktivieren und Schieberegler anpassen</div></div>
    </div>
  </div>

  <!-- Weitere Bedienungshilfen -->
  <div class="section">
    <div class="section-header">
      <div class="section-icon">⚙️</div>
      <h2>Weitere unterstützte Bedienungshilfen</h2>
    </div>
    <div class="subsection">
      <h3>Kontrast &amp; Darstellung</h3>
      <ul class="feature-list">
        <li><span class="check">✓</span> <strong>Erhöhter Kontrast:</strong> Die App respektiert die iOS-Einstellung für mehr Kontrast</li>
        <li><span class="check">✓</span> <strong>Dunkler Modus:</strong> Vollständige Unterstützung von Light Mode und Dark Mode</li>
        <li><span class="check">✓</span> <strong>Transparenz reduzieren:</strong> Hintergründe werden bei Bedarf weniger transparent dargestellt</li>
      </ul>
    </div>
    <div class="subsection">
      <h3>Bedienung</h3>
      <ul class="feature-list">
        <li><span class="check">✓</span> <strong>Sprachsteuerung:</strong> Alle Elemente sind korrekt benannt und per Voice Control bedienbar</li>
        <li><span class="check">✓</span> <strong>Wischgesten:</strong> Alle Listeneinträge unterstützen Wischgesten zum Bearbeiten und Löschen</li>
        <li><span class="check">✓</span> <strong>Kontextmenü:</strong> Langes Drücken öffnet ein Kontextmenü mit allen Aktionen</li>
      </ul>
    </div>
    <div class="subsection">
      <h3>Apple Watch</h3>
      <ul class="feature-list">
        <li><span class="check">✓</span> Die Watch-App unterstützt die Schriftgröße aus den Watch-Einstellungen</li>
        <li><span class="check">✓</span> Haptisches Feedback beim Starten und Stoppen einer Fahrt</li>
      </ul>
    </div>
    <div class="badge-row">
      <span class="badge">VoiceOver</span>
      <span class="badge">Dynamic Type</span>
      <span class="badge">Dark Mode</span>
      <span class="badge">Erhöhter Kontrast</span>
      <span class="badge">Reduzierte Bewegung</span>
      <span class="badge">Sprachsteuerung</span>
      <span class="badge">Haptik (Watch)</span>
    </div>
  </div>

  <!-- Feedback -->
  <div class="section">
    <div class="section-header">
      <div class="section-icon">💬</div>
      <h2>Feedback &amp; Verbesserungen</h2>
    </div>
    <p>Wenn eine Funktion mit VoiceOver oder einer anderen Bedienungshilfe
    nicht korrekt funktioniert, freue ich mich über dein Feedback.</p>
    <div class="tip" style="margin-top:12px;">
      <strong>Kontakt:</strong> <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a> –
      Rückmeldungen zu Bedienungshilfen werden bevorzugt bearbeitet.
    </div>
    <div class="note" style="margin-top:8px;">
      <div class="note-label">Feedback direkt in der App</div>
      Unter <strong>Einstellungen → Feedback &amp; Support</strong> kannst du
      ein Protokoll der App-Aktivität mitschicken – das hilft bei der schnellen Fehlersuche.
    </div>
  </div>

  <div class="footer-meta">
    Fahrtkosten App &nbsp;·&nbsp; Version 1.16.11 &nbsp;·&nbsp; Thomas Wagner<br>
    <a href="mailto:info@wagner-fahrtkosten.de">info@wagner-fahrtkosten.de</a>
  </div>

</div>
</body>
</html>
"""#
