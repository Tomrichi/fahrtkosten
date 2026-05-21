# Fahrtkosten App

**Digitaler Reisekostenassistent für iPhone, Apple Watch und iPad**

[![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B-blue?logo=apple)](https://apps.apple.com)
[![watchOS](https://img.shields.io/badge/watchOS-10%2B-blue?logo=apple)](https://apps.apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![Version](https://img.shields.io/badge/Version-1.15.0-green)](CHANGES.md)
[![License](https://img.shields.io/badge/License-Proprietary-lightgrey)](LICENSE)

---

## Über die App

Fahrtkosten entstand aus dem eigenen Alltag als Außendienstmitarbeiter – früher Excel-Tabellen, heute alles direkt am iPhone. Die App erfasst alle erstattungsfähigen Kosten einer Dienstreise an einem Ort und exportiert sie steuerkonform als PDF oder CSV.

🌐 **[wagner-fahrtkosten.de](https://wagner-fahrtkosten.de)**

---

## Features

### 🚗 Fahrten & Kilometerpauschale
- Manuelle Eingabe mit Start, Ziel, Datum, Kilometeranzahl und Fahrzeiten
- Kilometer automatisch via Apple Maps berechnen
- Import direkt aus **Google Maps** oder **Apple Maps** (Teilen-Funktion)
- Erstattungsberechnung nach § 9 EStG (0,30 €/km, anpassbar)

### 🔁 Wiederkehrende Fahrten *(neu in 1.15.0)*
- Häufige Routen mit Wochentagen hinterlegen
- Passende Routen erscheinen beim Anlegen einer neuen Fahrt automatisch als Vorschlag

### 🔴 Live Activity & Dynamic Island *(neu in 1.15.0)*
- GPS-Aufzeichnung live im Dynamic Island und auf dem Sperrbildschirm
- Gefahrene Kilometer, vergangene Zeit und aktuelle Geschwindigkeit in Echtzeit

### 📍 GPS-Streckenaufzeichnung
- Live-Tracking im Hintergrund – auch bei gesperrtem Display
- Intelligente Pausenerkennung (5 Min Stillstand → Pause, 30 Min → Auto-Stop)
- Haptisches Feedback und Live-Anzeige

### ⌚ Apple Watch App
- Fahrten starten und beenden direkt vom Handgelenk
- **Hintergrund-GPS** ohne iPhone in der Nähe (`WKExtendedRuntimeSession`)
- Live-Geschwindigkeit, haptisches Feedback
- Heimatadresse und App-Favoriten als Schnellziele auf der Watch

### 🚙 CarPlay
- Aufzeichnungsstatus direkt im Fahrzeugdisplay
- Monatsübersicht und aktuelle Erstattung

### 🏠 Home Screen Widget
- Aktiver Fahrt-Status auf dem Home Screen via WidgetKit

### ⏱ Arbeitszeit & Verpflegungspauschale
- Automatische Kombination von Fahrzeiten + manueller Arbeitszeit
- Verpflegungspauschalen nach § 9 Abs. 4a EStG (Inland / Schweiz / Ausland)
- Bilanzansicht: Ausgaben vs. Pauschale (rot/grün) mit Nettosaldo

### 📷 Belegscan (OCR)
- Texterkennung vollständig lokal via **Apple Vision Framework**
- Unterstützt Kamera, Fotobibliothek und PDF-Import
- Betrag, Datum und Name werden automatisch erkannt

### ⛽ Aktuelle Kraftstoffpreise
- Live-Abfrage via **Tankerkönig API** (auf Nutzeraktion, nie automatisch)

### 📤 Export
- **PDF-Export** – steuerkonform, geeignet für Finanzamt und Buchhaltung
- **CSV-Export** – semikolon-getrennt, direkt in Excel/Numbers importierbar
- **Lokales Backup/Restore** – JSON über iOS Share Sheet, keine Cloud erforderlich

### 🌍 Mehrsprachig
Deutsch 🇩🇪 · Englisch 🇬🇧 · Polnisch 🇵🇱 · Tschechisch 🇨🇿

### 🔒 Datenschutz
- Alle Daten ausschließlich lokal auf dem iPhone
- Keine Registrierung, kein Konto, kein Tracking, keine Werbung
- OCR und Belegscan vollständig offline

---

## Technischer Stack

| Bereich | Technologie |
|---|---|
| UI | SwiftUI |
| Persistenz | UserDefaults + JSON (lokal) |
| Karten & Geocoding | MapKit, MKReverseGeocodingRequest |
| GPS | CoreLocation, WKExtendedRuntimeSession |
| Live Activity | ActivityKit |
| Watch | WatchKit, WatchConnectivity |
| Widget | WidgetKit |
| CarPlay | CarPlay Framework |
| OCR | Apple Vision Framework |
| Spritpreise | Tankerkönig REST API |
| Sprache | Swift 5.9 / iOS 16+ |

---

## Projektstruktur

```
Fahrtkosten/
├── FahrtenView.swift          # Fahrten-Tab
├── RecurringTripView.swift    # Wiederkehrende Fahrten
├── VerpflegungView.swift      # Verpflegungspauschale
├── ArbeitszeitView.swift      # Arbeitszeit & Spesen
├── ReisespesenView.swift      # Reisespesen-Übersicht
├── FahrzeugkostenView.swift   # KFZ-Kosten
├── LocationTracker.swift      # GPS + Live Activity
├── Models.swift               # Datenmodelle
├── DataStore.swift            # Datenpersistenz
├── ExportServices.swift       # PDF/CSV Export
├── BackupManager.swift        # Backup & Restore
│
├── FahrtkostenWatch Watch App/
│   ├── WatchTripView.swift
│   ├── WatchViewModel.swift
│   └── WatchLocationTracker.swift
│
├── FahrtkostenWidget/
│   ├── FahrtkostenWidget.swift
│   └── FahrtkostenWidgetLiveActivity.swift
│
├── FahrtkostenShareExtension/ # Google/Apple Maps Import
│
└── html-seiten/               # Website-Quellen
    ├── homepage_neu.html
    ├── beschreibung_neu.html
    ├── changelog_neu.html
    └── datenschutz_neu.html
```

---

## Versionshistorie

Vollständiges Protokoll: **[CHANGES.md](CHANGES.md)**

| Version | Highlights |
|---|---|
| **1.15.0** *(Mai 2026)* | Live Activity & Dynamic Island · Wiederkehrende Fahrten · Watch-GPS ohne iPhone · Haptisches Feedback · Verpflegung-Bilanz |
| **1.14.5** *(Mai 2026)* | Google Maps Import-Fix · präzisere Abwesenheitszeitberechnung · iOS 26 Kompatibilität |
| **1.14.4** *(Mai 2026)* | Apple Watch App · Home Screen Widget · CarPlay-Integration · GPS Stadterkennung |
| **1.14.3** *(Mai 2026)* | iCloud-Synchronisation · Siri Shortcuts · Statistiken & Auswertungen |
| **1.14.2** *(Mai 2026)* | Spritpreisabfrage verbessert · PDF-Vorschau Fix |
| **1.14.1** *(Mai 2026)* | Globale Suche · eigene Tab-Leiste |
| **1.13.3** *(Mai 2026)* | Zeitfilter KFZ-Kosten · Splash Screen überarbeitet |
| **1.13.2** *(Mai 2026)* | Zeitfilter · Einstellungen kompakter · KFZ-Kosten Verbesserungen |
| **1.13.1** *(April 2026)* | Diagnoseprotokoll · mehrsprachige Oberfläche (DE/EN/PL/CZ) |
| **1.13.0** *(April 2026)* | Elektro & Hybrid · Collapsible Cards · Wischgesten · lokales Backup |
| **1.12.25** *(April 2026)* | Elektrofahrzeug & Hybrid · Strompreis · Einmalkauf |
| **1.12.24** *(April 2026)* | Fahrzeit & Arbeitszeit kombiniert · Live-Spritpreise · Belegscan OCR |
| **1.12.23** *(April 2026)* | Belegscan · KFZ-Kosten Tab · CarPlay · Übernachtungs-Datumsbereich |
| **1.10 – 1.11** *(April 2026)* | GPS-Streckenaufzeichnung · Apple Maps Integration · Auslandsregion |
| **1.0** *(April 2026)* | Erstveröffentlichung – Fahrten, Erstattung, KFZ-Kosten |

---

## Kontakt

**Thomas Wagner**
📧 [info@wagner-fahrtkosten.de](mailto:info@wagner-fahrtkosten.de)
🌐 [wagner-fahrtkosten.de](https://wagner-fahrtkosten.de)

---

*Alle Rechte vorbehalten · © 2026 Thomas Wagner*
