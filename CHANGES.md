# Fahrtkosten – Änderungsprotokoll

---

## Version 1.15.1 (22. Mai 2026)

- **Neu: Watch – Durchschnittsgeschwindigkeit** – Die Watch zeigt während der GPS-Aufzeichnung jetzt zusätzlich zur aktuellen Geschwindigkeit auch die Durchschnittsgeschwindigkeit (⌀ km/h) in Echtzeit an.
- **Neu: Wiederkehrende Fahrten – Hauptmenü-Shortcut** – Wiederkehrende Fahrten sind jetzt direkt über das Menü (⋯) in der Fahrtenliste erreichbar — ohne eine neue Fahrt anlegen zu müssen.
- **Neu: iCloud-Sync für wiederkehrende Fahrten & Favoriten** – Beide Datentypen werden jetzt automatisch via iCloud zwischen Geräten synchronisiert und sicher gemergt.
- **Neu: Live Activity / Dynamic Island** – Die GPS-Aufzeichnung erscheint jetzt als Live Activity im Dynamic Island und auf dem Sperrbildschirm. Angezeigt werden: gefahrene Kilometer, vergangene Zeit und aktuelle Geschwindigkeit – in Echtzeit aktualisiert.
- **Neu: Wiederkehrende Fahrten** – Häufige Routen (Von/Nach/km) mit Wochentagen hinterlegen. Passende Routen erscheinen beim Anlegen einer neuen Fahrt automatisch als Vorschlag zum direkten Eintippen.
- **Neu: Watch – Hintergrund-GPS** – Die Apple Watch App zeichnet GPS-Strecken jetzt auch bei gesperrtem Display auf (WKExtendedRuntimeSession). Ein iPhone in der Nähe ist nicht mehr notwendig.
- **Neu: Watch – Live-Geschwindigkeit** – Die Watch zeigt während der GPS-Aufzeichnung die aktuelle Geschwindigkeit in km/h an.
- **Neu: Watch – Haptisches Feedback** – Start, Stopp und Fehler werden mit den nativen Watch-Vibrationen quittiert.
- **Neu: Watch – Heimatadresse als Schnellziel** – Die in den Einstellungen hinterlegte Heimatadresse erscheint als erstes Schnellziel auf der Watch.
- **Neu: Watch – Dynamische Favoriten** – Gespeicherte Favoriten aus der iPhone-App sind jetzt direkt als Schnellziele auf der Watch auswählbar.
- **Neu: Verpflegung Bilanz in Reisespesen** – Die Kategorie Verpflegung zeigt jetzt Ausgaben (rot) vs. Verpflegungspauschale (grün) und den Nettosaldo auf einen Blick.
- **Fehlerbehebung: Verpflegungsberechnung** – Die Vorschau der Verpflegungspauschale und der angezeigte Betrag basieren jetzt einheitlich auf den gleichen Zeiten (Abfahrtszeit der frühesten Fahrt des Tages).

---

## Version 1.14.5 (19. Mai 2026)

- **Fehlerbehebung: Google Maps Import** – Fahrten, die über das Teilen-Symbol in Google Maps importiert werden, werden jetzt korrekt gespeichert. Bisher ging die Route während des Startbildschirms verloren.
- **Verbesserung: Abwesenheitszeitberechnung** – Bei mehreren Fahrten am gleichen Tag wird die Gesamtabwesenheitszeit jetzt präziser ermittelt. Nur manuell eingetragene Fahrzeiten fließen in die Berechnung ein – keine automatischen Schätzungen mehr.
- **Kompatibilität: iOS 26** – Vollständige Unterstützung von iOS 26 (neue MapKit-API für GPS-Ortsbestimmung).
- **Intern** – Versionsnummern der App-Erweiterungen (Widget, Share Extension) korrigiert.

---

## Version 1.14.4

- **Neu: Apple Watch App** – Fahrten direkt vom Handgelenk starten und beenden, automatischer Import in die iPhone-App.
- **Neu: Home Screen Widget** – aktive Fahrt auf dem Home Screen im Blick.
- **Neu: CarPlay-Integration** – Fahrt-Status direkt im Fahrzeugdisplay.
- **Neu: GPS Stadt-Erkennung** – Ortsnamen statt vollständiger Adressen bei GPS-Fahrten.
- **Verbesserung** – Tankerkönig API-Anbindung aktualisiert und stabilisiert.
- **Verbesserung** – Backup- und Exportfunktion überarbeitet.

---

## Version 1.13.1

- **Neu: Integriertes Diagnoseprotokoll** – alle Nutzeraktionen werden lokal aufgezeichnet für einfachere Fehleranalyse.
- **Neu: Mehrsprachige Oberfläche** – App vollständig in DE/EN/PL/CZ verfügbar; Sprache unabhängig von der iPhone-Systemsprache wählbar.
- Fehlerbehebungen und Stabilitätsverbesserungen.

---

## Version 1.13.0

- **Neu: Elektro & Hybrid** – Neue Fahrzeugtypen mit kWh-basierter Verbrauchserfassung.
- **Neu: Collapsible Cards & Chip-Filter** – Übersicht mit aufklappbaren Karten und schnellen Kategorie-Filtern.
- **Neu: Wischgesten** – Frei konfigurierbar; Farbe und Aktion individuell wählbar.
- **Neu: Duplizieren** – Einträge per Wischen duplizieren für wiederkehrende Fahrten.
- **Neu: Lokales Backup** – Daten via Share Sheet exportieren und wiederherstellen, ohne Cloud.
- **Neu: Beleg-Import als PDF** – Zusätzlich zu Kamera und Fotobibliothek.
