# Fahrtkosten – Hilfe & Bedienungsanleitung
Version 1.14.5 · Mai 2026

---

## Inhaltsverzeichnis

1. [Erste Schritte](#1-erste-schritte)
2. [Fahrten erfassen](#2-fahrten-erfassen)
3. [Arbeitszeit & Spesen](#3-arbeitszeit--spesen)
4. [Google Maps Import](#4-google-maps-import)
5. [Apple Watch](#5-apple-watch)
6. [GPS-Aufzeichnung](#6-gps-aufzeichnung)
7. [Export & Backup](#7-export--backup)
8. [Einstellungen](#8-einstellungen)
9. [Häufige Fragen](#9-häufige-fragen)

---

## 1. Erste Schritte

### App einrichten

Beim ersten Start führt die App dich durch die wichtigsten Einstellungen:

- **Kilometerpauschale** – Der gesetzliche Standardwert beträgt 0,30 € / km. Du kannst diesen Wert in den Einstellungen anpassen.
- **Fahrzeugtyp** – Wähle zwischen Benzin/Diesel, Elektro und Hybrid.
- **Sprache** – Die App ist in Deutsch, Englisch, Polnisch und Tschechisch verfügbar. Die Sprache kann jederzeit unabhängig von der iPhone-Systemsprache gewechselt werden.

### Erste Fahrt erfassen

1. Tippe auf den Tab **Fahrten**.
2. Tippe auf das **+**-Symbol oben rechts.
3. Fülle mindestens **Datum**, **Startort** und **Zielort** aus.
4. Gib die **Kilometer** ein oder lass sie via Apple Maps automatisch berechnen.
5. Tippe auf **Speichern**.

Die berechnete Erstattung erscheint sofort in der Fahrtenliste.

---

## 2. Fahrten erfassen

### Manuelle Eingabe

Tippe auf **+** im Fahrten-Tab. Folgende Felder stehen zur Verfügung:

| Feld | Beschreibung |
|------|--------------|
| Datum | Datum der Fahrt |
| Startort | Abfahrtsadresse oder Ortsname |
| Zielort | Zieladresse oder Ortsname |
| Kilometer | Strecke in km (kann automatisch berechnet werden) |
| Abfahrtszeit | Uhrzeit der Abfahrt (für Abwesenheitszeitberechnung) |
| Ankunftszeit | Uhrzeit der Ankunft (für Abwesenheitszeitberechnung) |
| Fahrzeug | Fahrzeugtyp und Kraftstoff |
| Notiz | Freitext, z. B. Kundennummer oder Projektnummer |

**Tipp:** Gibst du Start- und Zieladresse vollständig ein, kannst du die Kilometer automatisch via Apple Maps berechnen lassen – tippe dazu auf das Karten-Symbol neben dem Kilometer-Feld.

### Via GPS aufzeichnen

Siehe Abschnitt [6. GPS-Aufzeichnung](#6-gps-aufzeichnung).

### Via Apple Watch

Siehe Abschnitt [5. Apple Watch](#5-apple-watch).

### Via Google Maps / Apple Maps teilen

Siehe Abschnitt [4. Google Maps Import](#4-google-maps-import).

### Einträge bearbeiten und duplizieren

- **Bearbeiten:** Tippe auf einen Eintrag in der Liste, um ihn zu öffnen und zu bearbeiten.
- **Duplizieren:** Wische den Eintrag nach rechts und tippe auf **Duplizieren**. Nützlich bei wiederkehrenden Fahrten zur gleichen Strecke.
- **Löschen:** Wische den Eintrag nach links und tippe auf **Löschen**.

Die Wischgesten-Aktionen und deren Farben können in den Einstellungen unter **Wischgesten** frei konfiguriert werden.

---

## 3. Arbeitszeit & Spesen

### Wie die Abwesenheitszeitberechnung funktioniert

Die App berechnet die tägliche Gesamtabwesenheitszeit aus zwei Quellen:

1. **Fahrzeiten** der an diesem Tag erfassten Fahrten (nur manuell eingetragene Fahrzeiten, keine automatischen Schätzungen)
2. **Manuell erfasste Arbeitszeit** im Tab Arbeitszeit

Die Summe ergibt die Gesamtabwesenheitszeit, die für die Verpflegungspauschale maßgeblich ist.

### Verpflegungspauschalen (§ 9 Abs. 4a EStG)

| Region | Unter 3 Std. | 3 bis 6 Std. | Ab 6 Std. |
|--------|-------------|-------------|-----------|
| Inland | 0,00 € | 14,00 € | 28,00 € |
| Schweiz / Ausland | 0,00 € | 20,00 € | 35,00 € |

Die Pauschale wird automatisch angesetzt, sobald die Gesamtabwesenheitszeit den jeweiligen Schwellenwert überschreitet.

### Arbeitszeit erfassen

1. Tippe auf den Tab **Arbeitszeit**.
2. Tippe auf **+** und wähle das Datum aus.
3. Trage **Beginn** und **Ende** der Arbeitszeit ein.
4. Optional: Region wählen (Inland / Schweiz / Ausland).

Die App kombiniert die eingetragene Arbeitszeit automatisch mit den Fahrzeiten des gleichen Tages und zeigt die errechnete Verpflegungspauschale an.

### Wichtiger Hinweis (ab Version 1.14.5)

Bei mehreren Fahrten am gleichen Tag fließen **nur manuell eingetragene Fahrzeiten** (Abfahrts- und Ankunftszeit) in die Berechnung ein. Fahrten ohne eingetragene Uhrzeiten oder Fahrten, bei denen die Fahrzeit nur aus Kilometern oder der Maps-API geschätzt wurde, werden nicht automatisch hinzugerechnet. Dies verhindert eine Überschätzung der Abwesenheitszeit.

---

## 4. Google Maps Import

### Route aus Google Maps in Fahrtkosten importieren

Du kannst eine bereits gerechnete Route aus Google Maps direkt als Fahrt importieren:

1. Öffne **Google Maps** auf deinem iPhone.
2. Berechne deine Route (Startpunkt und Ziel eingeben).
3. Tippe auf das **Teilen**-Symbol (Pfeil nach oben).
4. Wähle **Fahrtkosten** aus der Liste der Apps.
5. Die App öffnet sich und erstellt automatisch eine neue Fahrt mit den Routendaten.
6. Überprüfe die vorausgefüllten Felder und tippe auf **Speichern**.

### Apple Maps Import

Derselbe Vorgang funktioniert auch mit Apple Maps:

1. Route in Apple Maps berechnen.
2. Auf **Teilen** tippen.
3. **Fahrtkosten** auswählen.

### Hinweis zu Version 1.14.5

In früheren Versionen konnte es vorkommen, dass die Route beim Importieren aus Google Maps verloren ging, wenn die App noch nicht geöffnet war (die URL wurde während des Startbildschirms verworfen). Dieser Fehler wurde in Version 1.14.5 behoben. Aktualisiere die App, falls du dieses Problem erlebt hast.

---

## 5. Apple Watch

### Voraussetzungen

- Apple Watch mit watchOS 10 oder neuer
- iPhone mit Fahrtkosten in Version 1.14.4 oder neuer
- Die Fahrtkosten Watch App muss auf der Apple Watch installiert sein (erfolgt automatisch über den App Store, sofern „Automatisch installieren" in der Watch-App aktiviert ist)

### Fahrt von der Apple Watch starten

1. Öffne die **Fahrtkosten App** auf der Apple Watch.
2. Tippe auf **Fahrt starten**.
3. Die Uhr zeigt Startzeit und laufende Fahrzeit an.

### Fahrt beenden und importieren

1. Tippe auf **Fahrt beenden**.
2. Die App fragt optional nach Startort und Zielort (oder du trägst diese später auf dem iPhone nach).
3. Der Eintrag wird automatisch via WatchConnectivity an die iPhone-App übertragen.
4. Auf dem iPhone erscheint die Fahrt in der Fahrtenliste – bereit zur finalen Bearbeitung.

### Einschränkungen der Watch App

- GPS-Streckenaufzeichnung ist nicht verfügbar (nur Start/Stopp mit Zeit)
- Kilometerangaben müssen auf dem iPhone ergänzt werden
- Synchronisierung erfordert, dass sich iPhone und Apple Watch in Reichweite befinden

---

## 6. GPS-Aufzeichnung

### Live-Tracking starten

1. Tippe auf den Tab **GPS** im Hauptmenü.
2. Tippe auf **Aufzeichnung starten**.
3. Bestätige den Zugriff auf den Standort (Berechtigung „Immer erlauben" empfohlen für zuverlässige Hintergrundaufzeichnung).

Die Aufzeichnung läuft im Hintergrund weiter, auch wenn das Display gesperrt oder eine andere App geöffnet ist. Ein Banner oben in der App zeigt die aktive Aufzeichnung an.

### Automatischer Stopp

Die App erkennt automatisch längere Standzeiten:

- **Pause:** Nach 5 Minuten Stillstand wird die Aufzeichnung vorübergehend pausiert.
- **Auto-Stop:** Nach 30 Minuten Stillstand wird die Aufzeichnung automatisch beendet und die Fahrt gespeichert.

### Fahrt manuell beenden

Tippe auf den **roten Banner** am oberen Bildschirmrand oder öffne den GPS-Tab und tippe auf **Aufzeichnung beenden**.

### CarPlay

Fahrtkosten zeigt den Status der aktiven GPS-Aufzeichnung direkt im CarPlay-Display. Du kannst die Aufzeichnung über CarPlay starten und beenden, ohne das iPhone anfassen zu müssen.

### GPS-Stadtname statt vollständiger Adresse

Seit Version 1.14.4 wird bei GPS-Fahrten automatisch nur der Ortsname (z. B. „München") statt der vollständigen Straßenadresse gespeichert. Das ergibt übersichtlichere Einträge in der Fahrtenliste.

---

## 7. Export & Backup

### PDF-Export

1. Tippe auf den Tab **Übersicht**.
2. Tippe auf das **Teilen**-Symbol oder das **Export**-Symbol in der Toolbar.
3. Wähle **PDF-Export**.
4. In der Vorschau siehst du das fertige Dokument. Tippe auf **Teilen** um es weiterzuleiten (E-Mail, AirDrop, Dateien-App, etc.).

Das PDF enthält alle erfassten Kategorien (Fahrten, Arbeitszeit, Übernachtungen, KFZ-Kosten, Spesen) mit Summen und ist für die Einreichung bei der Buchhaltung oder dem Finanzamt geeignet.

### CSV-Export

1. Wie beim PDF-Export, wähle stattdessen **CSV-Export**.
2. Die CSV-Datei ist mit Semikolon getrennt und direkt in Excel oder Numbers importierbar.

CSV-Spalten: `Datum;Kategorie;Von;Nach;Kilometer;Spritpreis €/L;Verbrauch L/100km;Verbrauchte Liter;Erstattung €;Notiz`

### Zeitraum filtern

Über die Chip-Filter in der Übersicht kannst du den Export auf bestimmte Kategorien oder Zeiträume einschränken, bevor du exportierst.

### Backup erstellen

1. Gehe zu **Einstellungen** > **Backup & Wiederherstellen**.
2. Tippe auf **Backup erstellen & speichern**.
3. Wähle im Share Sheet ein Ziel (iCloud Drive, Google Drive, AirDrop, Dateien-App).

Die Backup-Datei ist eine JSON-Datei im Format `Fahrtkosten_Backup_YYYY-MM-DD_HH-mm.json` und enthält alle Daten und Einstellungen.

### Backup wiederherstellen

1. Gehe zu **Einstellungen** > **Backup & Wiederherstellen**.
2. Tippe auf **Backup wiederherstellen**.
3. Wähle die Backup-Datei aus der Dateien-App oder iCloud Drive.
4. Bestätige die Wiederherstellung.

**Achtung:** Die Wiederherstellung überschreibt alle aktuellen Daten. Erstelle vorher ein neues Backup, wenn du aktuelle Einträge sichern möchtest.

---

## 8. Einstellungen

### Kilometerpauschale

Unter **Einstellungen** > **Fahrten** kannst du den Erstattungssatz pro Kilometer anpassen. Der gesetzliche Standardwert (Stand 2026) beträgt 0,30 € / km.

### Fahrzeug & Kraftstoff

- **Fahrzeugtyp:** Benzin/Diesel, Elektro oder Hybrid
- **Verbrauch:** Liter / 100 km (Benzin/Diesel) oder kWh / 100 km (Elektro/Hybrid)
- **Kraftstoffpreis / kWh-Preis:** Manuell hinterlegen oder via Tankerkönig API automatisch abrufen

### Verpflegungspauschalen

Unter **Einstellungen** > **Verpflegung** können die Pauschalen für Inland, Schweiz und Ausland individuell angepasst werden (z. B. für abweichende Firmenregelungen).

### Übernachtungspauschale

Standard: 75,00 € (gesetzliche Pauschale). Kann auf den tatsächlichen Hotelbetrag geändert werden.

### Wischgesten

Unter **Einstellungen** > **Wischgesten** kannst du für jede Liste separat festlegen:
- Welche Aktion beim Wischen nach links / rechts ausgeführt wird
- Welche Farbe die Wischgeste erhält

### Sprache

Unter **Einstellungen** > **Sprache** kannst du zwischen Deutsch, Englisch, Polnisch und Tschechisch wählen – unabhängig von der iPhone-Systemsprache.

### Diagnoseprotokoll

Unter **Einstellungen** > **Info & Datenschutz** > **Diagnoseprotokoll** kannst du das lokale Protokoll aller App-Aktionen einsehen und exportieren. Nützlich zur Fehleranalyse.

### Alle Einträge löschen

Unter **Einstellungen** > **Daten verwalten** > **Alle Einträge löschen** kannst du alle erfassten Einträge unwiderruflich löschen. Einstellungen bleiben erhalten. Erstelle vorher ein Backup.

---

## 9. Häufige Fragen

### Die Fahrt aus Google Maps wurde nicht gespeichert

**Frage:** Ich habe eine Route in Google Maps geteilt und Fahrtkosten ausgewählt, aber die Fahrt erscheint nicht in der Liste.

**Antwort:** Dieser Fehler trat in Versionen vor 1.14.5 auf. Die URL mit den Routendaten ging verloren, wenn die App neu gestartet wurde und der Startbildschirm angezeigt wurde. **Aktualisiere die App auf Version 1.14.5**, um dieses Problem zu beheben. Seit 1.14.5 wird der Startbildschirm übersprungen, wenn eine Route geteilt wird, und die Fahrt wird zuverlässig gespeichert.

---

### Die Abwesenheitszeit wird falsch berechnet

**Frage:** Bei mehreren Fahrten am gleichen Tag stimmt die berechnete Abwesenheitszeit nicht.

**Antwort:** Ab Version 1.14.5 werden nur Fahrten mit **manuell eingetragenen Fahrzeiten** (Abfahrts- und Ankunftszeit) in die Berechnung einbezogen. Fahrten ohne Uhrzeiten oder Fahrten, bei denen die Dauer nur aus Kilometern geschätzt wurde, werden nicht automatisch berücksichtigt. Trage Abfahrts- und Ankunftszeiten in jede Fahrt ein, damit die Berechnung korrekt ist.

---

### Die GPS-Aufzeichnung stoppt unerwartet

**Frage:** Die GPS-Aufzeichnung hört auf, obwohl ich noch unterwegs bin.

**Antwort:** Prüfe folgende Punkte:
- Standortberechtigung: Unter **Einstellungen** > **Datenschutz** > **Ortungsdienste** > **Fahrtkosten** muss **„Immer"** ausgewählt sein (nicht nur „Bei Verwendung der App").
- Energiesparmodus: Im iPhone-Energiesparmodus kann die Hintergrundlokalisierung eingeschränkt sein.
- Auto-Stop: Nach 30 Minuten Stillstand beendet die App die Aufzeichnung automatisch.

---

### Apple Watch zeigt keine Verbindung zur App

**Frage:** Die Apple Watch App kann keine Daten mit dem iPhone synchronisieren.

**Antwort:**
- Stelle sicher, dass iPhone und Apple Watch sich in Bluetooth-Reichweite befinden.
- Öffne die **Watch App** auf dem iPhone und prüfe, ob Fahrtkosten unter „Meine Watch" aufgeführt ist.
- Starte beide Geräte neu, falls die Verbindung nicht hergestellt werden kann.

---

### Tankerkönig-Preise werden nicht geladen

**Frage:** Die aktuellen Kraftstoffpreise können nicht abgerufen werden.

**Antwort:** Der Dienst benötigt eine aktive Internetverbindung und aktivierten Standortzugriff. Prüfe:
- Internetverbindung (WLAN oder Mobilfunk)
- Standortberechtigung (mindestens „Bei Verwendung der App")
- Tankerkönig-API ist ein Drittanbieterdienst – gelegentliche Ausfälle sind möglich

---

### Wie exportiere ich Daten für die Steuererklärung?

Nutze den PDF-Export aus der Übersicht. Das Dokument enthält alle notwendigen Angaben (Datum, Start/Ziel, Kilometer, Erstattungsbetrag) und ist für die Einreichung beim Finanzamt oder der Buchhaltung geeignet. Alternativ steht ein CSV-Export für die Weiterverarbeitung in Excel oder einer Buchhaltungssoftware zur Verfügung.

---

### Wo werden meine Daten gespeichert?

Alle Daten werden **ausschließlich lokal auf deinem iPhone** gespeichert. Es gibt keine Cloud-Synchronisierung, keine Registrierung und keine Übertragung von Daten an Dritte. Belegscan und PDF-Import laufen vollständig offline via Apple Vision Framework.

---

### Kontakt & Support

Bei weiteren Fragen oder Feedback wende dich an:

**E-Mail:** info@wagner-fahrtkosten.de

Bitte gib bei Supportanfragen die App-Version (unter Einstellungen > Info einsehbar) sowie eine kurze Beschreibung des Problems an. Das integrierte Diagnoseprotokoll (Einstellungen > Info & Datenschutz > Diagnoseprotokoll) kann bei der Fehleranalyse helfen – exportiere und füge es ggf. deiner Anfrage bei.
