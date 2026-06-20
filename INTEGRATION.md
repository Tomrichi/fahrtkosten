# Fahrtkosten – Update-Anleitung

## Neue & geänderte Dateien

### NEU – einfach in Xcode hinzufügen (Drag & Drop):
- `ReceiptParser.swift` – OCR-Logik (Vision Framework)
- `ReceiptScannerView.swift` – Kamera/Foto-Scanner UI
- `ReisespesenView.swift` – Neuer Tab: Maut, Vignette, Parkgebühr …

### ERSETZEN – bestehende Dateien überschreiben:
- `Models.swift` – ReiseSpese-Modell ergänzt
- `DataStore.swift` – reiseSpesen-Array + CRUD ergänzt
- `ContentView.swift` – Neuer "Spesen"-Tab
- `UebernachtungView.swift` – Scan-Button im Formular + frischeres Design
- `FahrzeugkostenView.swift` – Leasing-Bug behoben + kleinere Icons
- `SharedComponents.swift` – kompaktere Icons, frischeres Layout

---

## 1. Vision Framework einbinden

In Xcode → Target → „Frameworks, Libraries, and Embedded Content":

- `Vision.framework` hinzufügen (falls noch nicht vorhanden)

---

## 2. Info.plist – Kamera-Berechtigung

Füge folgende Einträge in `Info.plist` ein (falls noch nicht vorhanden):

```xml
<key>NSCameraUsageDescription</key>
<string>Die Kamera wird benötigt, um Rechnungen und Belege zu scannen und die Daten automatisch zu importieren.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Der Zugriff auf die Fotos wird benötigt, um gespeicherte Belege einzulesen.</string>
```

---

## 3. Was ist neu?

### Belege scannen (OCR)
- **Hotelrechnungen**: Im UebernachtungView-Formular gibt es einen „Rechnung scannen"-Button.
  → Datum, Hotelname, Stadt und Betrag werden automatisch erkannt und vorausgefüllt.
- **Reisespesen-Belege**: Im neuen Reisespesen-Tab oder direkt im Formular.
  → Datum und Betrag werden erkannt; Kategorie (Maut, Vignette …) kann angepasst werden.

### Neuer Tab „Spesen"
Kategorien: Maut / Toll · Vignette · Parkgebühr · Fähre · ÖPNV · Taxi · Sonstiges

Die Reisespesen fließen jetzt auch in den Gesamtbetrag (grandTotal) ein.

### Design-Verbesserungen
- Zeilenicons: 44 × 44 pt → 36 × 36 pt
- EmptyState-Icons: 72 × 72 pt → 64 × 64 pt
- StatTiles und Karten kompakter
- HeroCard mit Pill-Chips statt Label-Reihe
- Wiederverwendbare `ScanButtonRow`-Komponente

### Bug-Fix
- `FahrzeugkostenView.swift`: `.leasing` → `.sonstiges` in der Farbauswahl korrigiert

---

## 4. UebersichtView anpassen (optional)

Falls du in `UebersichtView` die neuen Reisespesen auch anzeigen möchtest,
ergänze einen Eintrag analog zu Hotel/Verpflegung:

```swift
StatTile(
    icon: "creditcard.fill",
    color: .iosIndigo,
    label: "Reisespesen",
    amount: store.totalReiseSpesen,
    detail: "\(store.reiseSpesen.count) Belege"
)
```

Und in der `HeroTotalCard`:
```swift
HeroTotalCard(
    total: store.grandTotal,
    tripCount: store.trips.count,
    mealCount: store.meals.count,
    hotelCount: store.hotels.count,
    spesenCount: store.reiseSpesen.count   // NEU
)
```
