import SwiftUI
import WebKit

// MARK: - Einstellungen
struct EinstellungenView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var lm: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var kmRateStr          = ""
    @State private var inlandMeal1to3Str  = ""
    @State private var inlandMeal3to6Str  = ""
    @State private var inlandMeal6plusStr = ""
    @State private var swissMeal1to3Str   = ""
    @State private var swissMeal3to6Str   = ""
    @State private var swissMeal6plusStr  = ""
    @State private var chfRateStr         = ""
    @State private var abroadMeal1to3Str  = ""
    @State private var abroadMeal3to6Str  = ""
    @State private var abroadMeal6plusStr = ""
    @State private var hotelFlatStr       = ""
    @State private var breakfastFlatStr   = ""
    @State private var monteurszulageInlandStr  = ""
    @State private var monteurszulageSchweizStr = ""
    @State private var monteurszulageAuslandStr = ""
    @State private var werkOrtStr = ""

    @State private var showResetAlert       = false
    @State private var showDeleteAllAlert   = false
    @State private var showRestoreAlert     = false
    @State private var showDatenschutz          = false
    @State private var showAppInfo              = false
    @State private var showImpressum            = false
    @State private var showVersionHistory       = false
    @State private var showBedienungshilfen     = false
    @State private var showBackupPicker     = false
    @State private var showBackupShareSheet = false
    @State private var showFeedback         = false
    @State private var showLogViewer        = false
    @State private var logClearConfirm      = false

    @State private var backupFileURL: URL?
    @State private var bannerMessage: String?
    @State private var bannerIsError = false

    @StateObject private var backupMgr = BackupManager()

    @AppStorage("preferredColorScheme") private var colorSchemePref: String = "system"
    @AppStorage("swipeLeading1")       private var swipeLeading1:  String = "delete"
    @AppStorage("swipeTrailing1")      private var swipeTrailing1: String = "edit"
    @AppStorage("swipeTrailing2")      private var swipeTrailing2: String = "duplicate"
    @AppStorage("swipeLeading1Color")  private var swipeLeading1Color:  String = "red"
    @AppStorage("swipeTrailing1Color") private var swipeTrailing1Color: String = "orange"
    @AppStorage("swipeTrailing2Color") private var swipeTrailing2Color: String = "blue"
    @AppStorage("homeAddress")             private var homeAddress: String = ""
    @AppStorage("defaultFuelType")         private var defaultFuelType: String = "e10"
    // Preis pro Kraftstoffart
    @AppStorage("defaultFuelPrice.e5")     private var priceE5: String = ""
    @AppStorage("defaultFuelPrice.e10")    private var priceE10: String = ""
    @AppStorage("defaultFuelPrice.diesel") private var priceDiesel: String = ""
    @AppStorage("defaultFuelPrice.elektro")private var priceElektro: String = ""
    @AppStorage("defaultFuelPrice.hybrid") private var priceHybrid: String = ""
    // Verbrauch pro Kraftstoffart
    @AppStorage("defaultConsumption.e5")     private var consumptionE5: String = ""
    @AppStorage("defaultConsumption.e10")    private var consumptionE10: String = ""
    @AppStorage("defaultConsumption.diesel") private var consumptionDiesel: String = ""
    @AppStorage("defaultConsumption.elektro")private var consumptionElektro: String = ""
    @AppStorage("defaultConsumption.hybrid") private var consumptionHybrid: String = ""

    // Computed helpers für aktuell gewählte Kraftstoffart
    private var currentPriceBinding: Binding<String> {
        switch defaultFuelType {
        case "e5":      return $priceE5
        case "diesel":  return $priceDiesel
        case "elektro": return $priceElektro
        case "hybrid":  return $priceHybrid
        default:        return $priceE10
        }
    }
    private var currentConsumptionBinding: Binding<String> {
        switch defaultFuelType {
        case "e5":      return $consumptionE5
        case "diesel":  return $consumptionDiesel
        case "elektro": return $consumptionElektro
        case "hybrid":  return $consumptionHybrid
        default:        return $consumptionE10
        }
    }

    // Aufklappbare Sections
    @State private var expandRates   = false
    @State private var expandMeals   = false
    @State private var expandMonteurszulage = false
    @State private var expandHotel   = false
    @State private var expandFuel    = false
    @State private var expandLang    = false
    @State private var expandSwipe   = false
    @State private var expandBackup  = false
    @State private var expandInfo    = false
    @State private var expandProto   = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            Form {
                collapsibleRates
                homeAddressSection
                collapsibleFuel
                collapsibleMeals
                collapsibleMonteurszulage
                collapsibleHotel
                resetSection
                backupSection
                deleteSection
                languageSection
                appearanceSection
                swipeSection
                infoSection
                protokollSection
                platformSection
            }
            .safeAreaInset(edge: .top) { bannerView }
            .animation(.spring(response: 0.3), value: bannerMessage)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(resolvedColorScheme)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { saveAndDismiss() }
                        .fontWeight(.regular)
                }
            }
            .onAppear { loadValues() }
            .alert("Standardwerte wiederherstellen?", isPresented: $showResetAlert) {
                Button("Zurücksetzen", role: .destructive) { resetToDefaults() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Alle Pauschalsätze werden auf die gesetzlichen Standardwerte zurückgesetzt.")
            }
            .alert("Alle Einträge löschen?", isPresented: $showDeleteAllAlert) {
                Button("Alles löschen", role: .destructive) {
                    AppLogger.shared.logTap("Einstellungen: Alle Einträge gelöscht")
                    backupMgr.deleteAllEntries(in: store)
                    bannerMessage = "Alle Einträge wurden gelöscht."
                    bannerIsError = false
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden. Erstelle vorher ein Backup.")
            }
            .alert("Backup wiederherstellen?", isPresented: $showRestoreAlert) {
                Button("Backup laden", role: .destructive) { showBackupPicker = true }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Alle aktuellen Daten werden durch die Backup-Daten ersetzt.")
            }
            .sheet(isPresented: $showBackupShareSheet) {
                if let url = backupFileURL { ShareSheet(items: [url]) }
            }
            .sheet(isPresented: $showBackupPicker) {
                BackupImportPicker { url in
                    let success = backupMgr.restore(from: url, into: store)
                    if success {
                        loadValues()
                        bannerMessage = backupMgr.lastSuccess ?? "Backup wiederhergestellt"
                        bannerIsError = false
                    } else {
                        bannerMessage = backupMgr.lastError ?? "Fehler beim Wiederherstellen"
                        bannerIsError = true
                    }
                }
            }
        }
    }

    // MARK: - Sub-Views (aufgeteilt wegen Swift Type-Checker-Limit)

    @ViewBuilder private var bannerView: some View {
        if let msg = bannerMessage {
            HStack(spacing: 10) {
                Image(systemName: bannerIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(bannerIsError ? Color.red : Color.iosGreen)
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Button { bannerMessage = nil } label: {
                    Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Aufklappbare Sections

    @ViewBuilder private var homeAddressSection: some View {
        Section {
            HStack {
                Label("Heimatadresse", systemImage: "house.fill")
                    .foregroundStyle(.orange)
                Spacer()
                TextField("z.B. München", text: $homeAddress)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Wird im Fahrtenformular als Schnellzugriff-Button (🏠) angezeigt und in der Fahrtenliste markiert.")
        }
    }

    @ViewBuilder private var collapsibleRates: some View {
        Section {
            DisclosureGroup(isExpanded: $expandRates) {
                HStack {
                    Label("Kilometerpauschale", systemImage: "car.fill")
                    Spacer()
                    TextField("0,30", text: $kmRateStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("€ / km").foregroundStyle(.secondary).font(.subheadline)
                }
            } label: {
                Label("Kilometerpauschale", systemImage: "car.fill")
                    .foregroundStyle(.primary)
                    .fontWeight(.regular)
            }
        } footer: { Text("Gesetzlicher Standardwert: 0,30 € / km (§ 9 Abs. 1 Nr. 4a EStG)") }
    }

    @ViewBuilder private var collapsibleMeals: some View {
        Section {
            DisclosureGroup(isExpanded: $expandMeals) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Inland").font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 8).padding(.bottom, 4)
                    mealRow(label: "< 3 Stunden",   icon: "1.circle.fill", color: .gray,   binding: $inlandMeal1to3Str)
                    mealRow(label: "3 - 6 Stunden", icon: "2.circle.fill", color: .orange, binding: $inlandMeal3to6Str)
                    mealRow(label: "ab 6 Stunden",  icon: "3.circle.fill", color: .green,  binding: $inlandMeal6plusStr)
                    Divider().padding(.vertical, 6)
                    Text("Schweiz (in CHF)").font(.caption).foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                    mealRow(label: "< 3 Stunden",   icon: "1.circle.fill", color: .gray,   binding: $swissMeal1to3Str,  currency: "CHF")
                    mealRow(label: "3 - 6 Stunden", icon: "2.circle.fill", color: .orange, binding: $swissMeal3to6Str,  currency: "CHF")
                    mealRow(label: "ab 6 Stunden",  icon: "3.circle.fill", color: .green,  binding: $swissMeal6plusStr, currency: "CHF")
                    HStack {
                        Label("CHF-Kurs (1 CHF = … €)", systemImage: "arrow.left.arrow.right")
                        Spacer()
                        TextField("1,08", text: $chfRateStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("€").foregroundStyle(.secondary).font(.subheadline)
                    }
                    Divider().padding(.vertical, 6)
                    Text("Ausland").font(.caption).foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                    mealRow(label: "< 3 Stunden",   icon: "1.circle.fill", color: .gray,   binding: $abroadMeal1to3Str)
                    mealRow(label: "3 - 6 Stunden", icon: "2.circle.fill", color: .orange, binding: $abroadMeal3to6Str)
                    mealRow(label: "ab 6 Stunden",  icon: "3.circle.fill", color: .green,  binding: $abroadMeal6plusStr)
                }
            } label: {
                Label("Verpflegungspauschalen", systemImage: "fork.knife")
                    .foregroundStyle(.primary)
                    .fontWeight(.regular)
            }
        } footer: { Text("Inland: 0 € · 14 € · 28 €  |  Schweiz: 0 · 65 · 65 CHF (wird mit obigem Kurs in € umgerechnet)  |  Ausland: 0 € · 10 € · 35 €") }
    }

    @ViewBuilder private var collapsibleMonteurszulage: some View {
        Section {
            DisclosureGroup(isExpanded: $expandMonteurszulage) {
                HStack {
                    Label("Werk-Standort", systemImage: "building.2.fill")
                    Spacer()
                    TextField("z.B. Steffisburg", text: $werkOrtStr)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("Zulage Inland / Deutschland", systemImage: "flag.fill")
                    Spacer()
                    TextField("12,00", text: $monteurszulageInlandStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("€").foregroundStyle(.secondary).font(.subheadline)
                }
                HStack {
                    Label("Zulage Schweiz / Außerhalb des Werks", systemImage: "flag.checkered")
                    Spacer()
                    TextField("18,00", text: $monteurszulageSchweizStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("CHF").foregroundStyle(.secondary).font(.subheadline)
                }
                HStack {
                    Label("CHF-Kurs (1 CHF = … €)", systemImage: "arrow.left.arrow.right")
                    Spacer()
                    TextField("1,08", text: $chfRateStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("€").foregroundStyle(.secondary).font(.subheadline)
                }
                HStack {
                    Spacer()
                    Text("≈ \((parseCurrency(monteurszulageSchweizStr) * parseCurrency(chfRateStr)).euroFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("Zulage Ausland / Außerhalb des Werks und Deutschlands", systemImage: "globe.europe.africa.fill")
                    Spacer()
                    TextField("50,00", text: $monteurszulageAuslandStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("€").foregroundStyle(.secondary).font(.subheadline)
                }
            } label: {
                Label("Monteurszulage", systemImage: "wrench.and.screwdriver.fill")
                    .foregroundStyle(.primary)
                    .fontWeight(.regular)
            }
        } footer: {
            Text("Pauschale Zulage: 12 € bei Region Inland oder bei Arbeit am Werk (\(werkOrtStr.isEmpty ? "Steffisburg" : werkOrtStr)), 18 CHF außerhalb des Werks bei Region Schweiz (wird mit dem CHF-Kurs oben in € umgerechnet – derselbe Kurs wie bei Verpflegungspauschalen), 50 € außerhalb des Werks bei Region Ausland. Wird über den Lohn ausbezahlt und ist daher NICHT Teil der Verpflegungspauschale/Erstattung – wird separat ausgewiesen. Beim Erfassen eines Verpflegungseintrags mit Region Schweiz oder Ausland kann „Am Werk gearbeitet\" angehakt werden, um die Inlands-Zulage anzuwenden.")
        }
    }

    @ViewBuilder private var collapsibleHotel: some View {
        Section {
            DisclosureGroup(isExpanded: $expandHotel) {
                HStack {
                    Label("Übernachtungspauschale", systemImage: "bed.double.fill")
                    Spacer()
                    TextField("0,00", text: $hotelFlatStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("€").foregroundStyle(.secondary).font(.subheadline)
                }
                HStack {
                    Label("Frühstückspauschale", systemImage: "cup.and.saucer.fill")
                    Spacer()
                    TextField("0,00", text: $breakfastFlatStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("€").foregroundStyle(.secondary).font(.subheadline)
                }
            } label: {
                Label("Übernachtung/Frühstück", systemImage: "bed.double.fill")
                    .foregroundStyle(.primary)
                    .fontWeight(.regular)
            }
        } footer: { Text("Standard Deutschland: 20,00 € / Nacht (§ 9 Abs. 1 Nr. 5a EStG). Grenzgänger mit Schweizer Arbeitgeber und Tätigkeit in Deutschland: bitte individuell prüfen.") }
    }

    @ViewBuilder private var collapsibleFuel: some View {
        Section {
            DisclosureGroup(isExpanded: $expandFuel) {
                // Kraftstoffart
                VStack(alignment: .leading, spacing: 6) {
                    Text("Antrieb / Kraftstoffart")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    // Zeile 1: Benzin-Typen
                    HStack(spacing: 8) {
                        ForEach([("Super E5", "e5"), ("Super E10", "e10"), ("Diesel", "diesel")], id: \.1) { name, key in
                            Button {
                                defaultFuelType = key
                            } label: {
                                Text(name)
                                    .font(.caption)
                                    .foregroundColor(defaultFuelType == key ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(defaultFuelType == key ? Color(red: 1.0, green: 0.584, blue: 0.0) : Color(.systemFill))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    // Zeile 2: Elektro / Hybrid
                    HStack(spacing: 8) {
                        ForEach([("⚡ Elektro", "elektro"), ("⚡ Hybrid", "hybrid")], id: \.1) { name, key in
                            Button {
                                defaultFuelType = key
                            } label: {
                                Text(name)
                                    .font(.caption)
                                    .foregroundColor(defaultFuelType == key ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(defaultFuelType == key ? Color.iosGreen : Color(.systemFill))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)

                // Durchschnittsverbrauch
                HStack {
                    Label(defaultFuelType == "elektro" ? "Verbrauch (kWh/100 km)" : "Durchschnittsverbrauch",
                          systemImage: "gauge.with.dots.needle.33percent")
                    Spacer()
                    TextField(defaultFuelType == "elektro" ? "z.B. 18,0" : "z.B. 7,5",
                              text: currentConsumptionBinding)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text(defaultFuelType == "elektro" ? "kWh/100 km" : "L/100 km")
                        .foregroundStyle(.secondary).font(.subheadline)
                }

                // Standard-Preis
                HStack {
                    Label(defaultFuelType == "elektro" ? "Standard-Strompreis" : "Standard-Spritpreis",
                          systemImage: "eurosign.circle")
                    Spacer()
                    TextField(defaultFuelType == "elektro" ? "z.B. 0,30" : "z.B. 1,75",
                              text: currentPriceBinding)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text(defaultFuelType == "elektro" ? "€/kWh" : "€/L")
                        .foregroundStyle(.secondary).font(.subheadline)
                }
            } label: {
                HStack {
                    Label("Antrieb / Kraftstoff",
                          systemImage: defaultFuelType == "elektro" ? "bolt.fill" : defaultFuelType == "hybrid" ? "bolt.car.fill" : "fuelpump.fill")
                        .foregroundStyle(.primary)
                        .fontWeight(.regular)
                    Spacer()
                    Text(fuelDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: { Text("Antriebsart, Preis und Verbrauch werden beim Anlegen neuer Fahrten automatisch vorausgefüllt. Leer = manuelle Eingabe pro Fahrt.") }
    }

    private var fuelDisplayName: String {
        switch defaultFuelType {
        case "e5":      return "Super E5"
        case "diesel":  return "Diesel"
        case "elektro": return "⚡ Elektro"
        case "hybrid":  return "⚡ Hybrid"
        default:        return "Super E10"
        }
    }

    @ViewBuilder private var ratesSection: some View { collapsibleRates }
    @ViewBuilder private var verpflegungSection: some View { collapsibleMeals }
    @ViewBuilder private var hotelSection: some View { collapsibleHotel }

    @ViewBuilder private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label("Auf Standardwerte zurücksetzen", systemImage: "arrow.counterclockwise")
            }
        } footer: {
            Text("Stellt alle gesetzlichen Standardwerte gemäß § 9 Abs. 4a EStG wieder her.")
        }
    }

    @ViewBuilder private var backupSection: some View {
        Section {
            // ── Aufklapp-Header ──
            Button {
                withOptionalAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandBackup.toggle()
                }
            } label: {
                HStack {
                    Label("Backup & Wiederherstellen", systemImage: "externaldrive.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: expandBackup ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expandBackup {
                // Lokal speichern
                Button {
                    saveAndApply()
                    AppLogger.shared.logTap("Backup: Lokal speichern")
                    backupMgr.saveLocally(from: store)
                    if let msg = backupMgr.lastSuccess {
                        bannerMessage = msg; bannerIsError = false
                    } else if let err = backupMgr.lastError {
                        bannerMessage = err; bannerIsError = true
                    }
                } label: {
                    Label("Backup lokal speichern", systemImage: "internaldrive")
                }

                // Teilen / Cloud
                Button {
                    saveAndApply()
                    AppLogger.shared.logTap("Backup: Teilen / Cloud-Export")
                    if let url = backupMgr.backupFileURL(from: store) {
                        backupFileURL = url
                        showBackupShareSheet = true
                    } else {
                        bannerMessage = backupMgr.lastError ?? "Backup fehlgeschlagen"
                        bannerIsError = true
                    }
                } label: {
                    Label("Backup teilen / in Cloud exportieren", systemImage: "square.and.arrow.up")
                }

                // Wiederherstellen
                Button {
                    showRestoreAlert = true
                } label: {
                    Label("Backup wiederherstellen", systemImage: "arrow.down.doc.fill")
                }

                // Gespeicherte Backups
                NavigationLink {
                    SavedBackupListView(backupMgr: backupMgr)
                        .environmentObject(store)
                } label: {
                    HStack {
                        Label("Gespeicherte Backups", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        if backupMgr.isLoadingBackups {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("\(backupMgr.savedBackups.count)")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
                .task { backupMgr.loadSavedBackups() }

                Text("'Lokal speichern' legt das Backup in der Dateien-App ab. 'Teilen' ermöglicht Export in iCloud Drive, Google Drive oder per AirDrop. Max. 10 Backups werden aufbewahrt.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAllAlert = true
            } label: {
                Label("Alle Einträge löschen", systemImage: "trash.fill")
            }
        } header: {
            Label("Daten verwalten", systemImage: "folder.fill")
        } footer: {
            Text("Löscht unwiderruflich alle Einträge. Einstellungen bleiben erhalten.")
        }
    }

    @ViewBuilder private var languageSection: some View {
        Section {
            DisclosureGroup(isExpanded: $expandLang) {
                ForEach(AppLanguage.allCases.filter { ["de","en","pl","cs"].contains($0.rawValue) }) { lang in
                    Button {
                        withOptionalAnimation(.easeInOut(duration: 0.2)) {
                            lm.language = lang
                            expandLang = false
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Text(lang.flag)
                                .font(.system(size: 22))
                            Text(lang.displayName)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)
                            Spacer()
                            if lm.language == lang {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            } label: {
                HStack(spacing: 12) {
                    Label("Sprache / Language", systemImage: "globe")
                        .foregroundStyle(.primary)
                        .fontWeight(.regular)
                    Spacer()
                    HStack(spacing: 6) {
                        Text(lm.language.flag)
                        Text(lm.language.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

        @ViewBuilder private var infoSection: some View {
        Section {
            Button {
                withOptionalAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandInfo.toggle()
                }
            } label: {
                HStack {
                    Label("App Info und Datenschutz", systemImage: "info.circle.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: expandInfo ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expandInfo {
                Button {
                    showVersionHistory = true
                } label: {
                    HStack {
                        Label("App Version", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                .foregroundStyle(.primary)
                .sheet(isPresented: $showVersionHistory) { VersionHistoryView() }

                Button {
                    showDatenschutz = true
                } label: {
                    Label("Datenschutzerklärung", systemImage: "lock.shield.fill")
                }
                .foregroundStyle(.primary)
                .sheet(isPresented: $showDatenschutz) { DatenschutzView() }

                Button {
                    showAppInfo = true
                } label: {
                    Label("App-Funktionen & Anleitung", systemImage: "questionmark.circle.fill")
                }
                .foregroundStyle(.primary)
                .sheet(isPresented: $showAppInfo) { HilfeView() }

                Button {
                    showBedienungshilfen = true
                } label: {
                    Label("Bedienungshilfen", systemImage: "accessibility.fill")
                }
                .foregroundStyle(.primary)
                .sheet(isPresented: $showBedienungshilfen) { BedienungshilfenView() }

                Button {
                    showImpressum = true
                } label: {
                    Label("Impressum", systemImage: "doc.text.fill")
                }
                .foregroundStyle(.primary)
                .sheet(isPresented: $showImpressum) { ImpressumView() }

                HStack {
                    Label("Entwickler", systemImage: "person.fill")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Thomas Wagner")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                Button {
                    if let url = URL(string: "mailto:info@wagner-fahrtkosten.de") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Kontakt", systemImage: "envelope.fill")
                }
                .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder private var protokollSection: some View {
        Section {
            Button {
                withOptionalAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandProto.toggle()
                }
            } label: {
                HStack {
                    Label("Protokoll & Feedback", systemImage: "list.bullet.clipboard")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: expandProto ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expandProto {
                Button {
                    showLogViewer = true
                } label: {
                    HStack {
                        Label("Protokoll anzeigen", systemImage: "doc.text.magnifyingglass")
                        Spacer()
                        Text(AppLogger.shared.sizeText)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                .foregroundStyle(.primary)
                .sheet(isPresented: $showLogViewer) { LogViewerSheet() }

                Button {
                    showFeedback = true
                } label: {
                    Label("Feedback & Support", systemImage: "paperplane.fill")
                }
                .foregroundStyle(.primary)
                .sheet(isPresented: $showFeedback) { FeedbackView() }

                if AppLogger.shared.hasEntries {
                    Button(role: .destructive) {
                        logClearConfirm = true
                    } label: {
                        Label("Protokoll löschen", systemImage: "trash")
                    }
                    .alert("Protokoll löschen?", isPresented: $logClearConfirm) {
                        Button("Löschen", role: .destructive) {
                            AppLogger.shared.clearLog()
                            bannerMessage = "Protokoll gelöscht."
                            bannerIsError = false
                        }
                        Button("Abbrechen", role: .cancel) {}
                    } message: {
                        Text("Das Protokoll wird geleert. Es wird beim nächsten App-Start automatisch neu angelegt.")
                    }
                }

                Text("Das Protokoll wird nur im Arbeitsspeicher geführt und beim nächsten App-Start automatisch geleert. Es enthält keine personenbezogenen Daten.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder private var platformSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "devices.fill")
                    .foregroundStyle(.secondary)
                Text("Optimiert für iPhone, iPad & Mac")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("© 2026 Thomas Wagner")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
    }

    // MARK: - Erscheinungsbild
    @ViewBuilder private var appearanceSection: some View {
        Section {
            HStack(spacing: 0) {
                ForEach([("System", "circle.lefthalf.filled", "system"),
                         ("Hell",   "sun.max.fill",           "light"),
                         ("Dunkel", "moon.fill",              "dark")],
                        id: \.2) { label, icon, key in
                    Button {
                        withOptionalAnimation(.easeInOut(duration: 0.2)) { colorSchemePref = key }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(colorSchemePref == key ? .white : .secondary)
                            Text(label)
                                .font(.system(size: 11))
                                .foregroundColor(colorSchemePref == key ? .white : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(colorSchemePref == key ? Color.blue : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        } header: {
            Label("Erscheinungsbild", systemImage: "paintbrush.fill")
        }
    }

    @ViewBuilder private var swipeSection: some View {
        Section {
            // ── Aufklapp-Header ──
            Button {
                withOptionalAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandSwipe.toggle()
                }
            } label: {
                HStack {
                    Label("Wischgesten", systemImage: "hand.draw.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: expandSwipe ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expandSwipe {
                swipeRow(direction: "links",    iconColor: swipeColorValue(swipeLeading1Color),
                         action: $swipeLeading1, color: $swipeLeading1Color,
                         defaultAction: "delete", defaultColor: "red")
                swipeRow(direction: "rechts 1", iconColor: swipeColorValue(swipeTrailing1Color),
                         action: $swipeTrailing1, color: $swipeTrailing1Color,
                         defaultAction: "edit", defaultColor: "orange")
                swipeRow(direction: "rechts 2", iconColor: swipeColorValue(swipeTrailing2Color),
                         action: $swipeTrailing2, color: $swipeTrailing2Color,
                         defaultAction: "duplicate", defaultColor: "blue")

                Text("Legt fest welche Aktion und Farbe beim Wischen nach links oder rechts erscheint.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func swipeRow(direction: String, iconColor: Color,
                          action: Binding<String>, color: Binding<String>,
                          defaultAction: String, defaultColor: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: direction == "links" ? "arrow.left" : "arrow.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(iconColor)
                }
                Text("Swipe \(direction)").font(.system(size: 15))
                Spacer()
                Picker("", selection: action) {
                    Text("Löschen").tag("delete")
                    Text("Bearbeiten").tag("edit")
                    Text("Kopieren").tag("duplicate")
                    Text("-").tag("none")
                }.pickerStyle(.menu)
            }
            // Farbauswahl
            HStack(spacing: 8) {
                Text("Farbe:").font(.caption).foregroundColor(.secondary)
                ForEach([("red","Rot"),("orange","Orange"),("blue","Blau"),("green","Grün"),("purple","Lila")], id: \.0) { key, _ in
                    Button { color.wrappedValue = key } label: {
                        Circle()
                            .fill(swipeColorValue(key))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(Color.primary, lineWidth: color.wrappedValue == key ? 2.5 : 0)
                                    .padding(2)
                            )
                    }.buttonStyle(.plain)
                }
            }
            .padding(.leading, 42)
        }
        .padding(.vertical, 4)
    }

    private func swipeColorValue(_ key: String) -> Color {
        switch key {
        case "red":    return .red
        case "orange": return .orange
        case "blue":   return .blue
        case "green":  return .green
        case "purple": return .purple
        default:       return .red
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemePref {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    // MARK: - Helper Row
    @ViewBuilder
    private func mealRow(label: String, icon: String, color: Color, binding: Binding<String>, currency: String = "€") -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(color)
            Spacer()
            TextField("0,00", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(currency)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    // MARK: - Load / Save / Reset
    private func loadValues() {
        func fmt(_ v: Double) -> String {
            String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
        }
        kmRateStr          = fmt(store.kmRate)
        inlandMeal1to3Str  = fmt(store.inlandMeal1to3)
        inlandMeal3to6Str  = fmt(store.inlandMeal3to6)
        inlandMeal6plusStr = fmt(store.inlandMeal6plus)
        swissMeal1to3Str   = fmt(store.swissMeal1to3)
        swissMeal3to6Str   = fmt(store.swissMeal3to6)
        swissMeal6plusStr  = fmt(store.swissMeal6plus)
        chfRateStr         = fmt(store.chfRate)
        abroadMeal1to3Str  = fmt(store.abroadMeal1to3)
        abroadMeal3to6Str  = fmt(store.abroadMeal3to6)
        abroadMeal6plusStr = fmt(store.abroadMeal6plus)
        hotelFlatStr       = fmt(store.hotelFlat)
        breakfastFlatStr   = fmt(store.breakfastFlat)
        monteurszulageInlandStr  = fmt(store.monteurszulageInland)
        monteurszulageSchweizStr = fmt(store.monteurszulageSchweiz)
        monteurszulageAuslandStr = fmt(store.monteurszulageAusland)
        werkOrtStr = store.werkOrt
    }

    private func saveAndApply() {
        store.kmRate          = parseCurrency(kmRateStr)
        store.inlandMeal1to3  = parseCurrency(inlandMeal1to3Str)
        store.inlandMeal3to6  = parseCurrency(inlandMeal3to6Str)
        store.inlandMeal6plus = parseCurrency(inlandMeal6plusStr)
        store.swissMeal1to3   = parseCurrency(swissMeal1to3Str)
        store.swissMeal3to6   = parseCurrency(swissMeal3to6Str)
        store.swissMeal6plus  = parseCurrency(swissMeal6plusStr)
        store.chfRate         = parseCurrency(chfRateStr)
        store.abroadMeal1to3  = parseCurrency(abroadMeal1to3Str)
        store.abroadMeal3to6  = parseCurrency(abroadMeal3to6Str)
        store.abroadMeal6plus = parseCurrency(abroadMeal6plusStr)
        store.hotelFlat       = parseCurrency(hotelFlatStr)
        store.breakfastFlat   = parseCurrency(breakfastFlatStr)
        store.monteurszulageInland  = parseCurrency(monteurszulageInlandStr)
        store.monteurszulageSchweiz = parseCurrency(monteurszulageSchweizStr)
        store.monteurszulageAusland = parseCurrency(monteurszulageAuslandStr)
        store.werkOrt = werkOrtStr.trimmingCharacters(in: .whitespaces).isEmpty ? Constants.werkOrt : werkOrtStr
    }

    private func saveAndDismiss() {
        saveAndApply()
        AppLogger.shared.log("Einstellungen gespeichert: kmRate=\(String(format: "%.2f", store.kmRate))€/km, Antrieb=\(defaultFuelType)", level: .store)
        dismiss()
    }

    private func resetToDefaults() {
        store.kmRate          = Constants.kmRate
        store.inlandMeal1to3  = Constants.inlandMeal1to3
        store.inlandMeal3to6  = Constants.inlandMeal3to6
        store.inlandMeal6plus = Constants.inlandMeal6plus
        store.swissMeal1to3   = Constants.swissMeal1to3
        store.swissMeal3to6   = Constants.swissMeal3to6
        store.swissMeal6plus  = Constants.swissMeal6plus
        store.chfRate         = Constants.chfRate
        store.abroadMeal1to3  = Constants.abroadMeal1to3
        store.abroadMeal3to6  = Constants.abroadMeal3to6
        store.abroadMeal6plus = Constants.abroadMeal6plus
        store.hotelFlat       = Constants.hotelFlat
        store.breakfastFlat   = Constants.breakfastFlat
        store.monteurszulageInland  = Constants.monteurszulageInland
        store.monteurszulageSchweiz = Constants.monteurszulageSchweiz
        store.monteurszulageAusland = Constants.monteurszulageAusland
        store.werkOrt = Constants.werkOrt
        AppLogger.shared.logTap("Einstellungen: Auf Standardwerte zurückgesetzt")
        loadValues()
    }

    private func parseCurrency(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}

// MARK: - LogViewerSheet
struct LogViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var logger = AppLogger.shared
    @State private var showShareSheet = false
    @State private var clearConfirm   = false

    var body: some View {
        NavigationStack {
            Group {
                if logger.hasEntries {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(logger.logContents)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .id("bottom")
                        }
                        .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                } else {
                    ContentUnavailableView(
                        "Keine Einträge",
                        systemImage: "doc.text",
                        description: Text("Das Protokoll ist leer.")
                    )
                }
            }
            .navigationTitle("App-Protokoll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Teilen
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(!logger.hasEntries)
                    // Löschen
                    Button(role: .destructive) {
                        clearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(!logger.hasEntries)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Statuszeile unten
                HStack {
                    Image(systemName: "memorychip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("In-Memory · \(logger.entryCount) Einträge · \(logger.sizeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = logger.logData {
                ShareSheet(items: [data as Any])
            }
        }
        .alert("Protokoll löschen?", isPresented: $clearConfirm) {
            Button("Löschen", role: .destructive) { logger.clearLog() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Protokoll wird geleert. Es wird beim nächsten App-Start automatisch neu angelegt.")
        }
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct SavedBackupListView: View {
    @ObservedObject var backupMgr: BackupManager
    @EnvironmentObject var store: DataStore
    @State private var showRestoreConfirm: SavedBackupInfo? = nil
    @State private var showDeleteConfirm:  SavedBackupInfo? = nil
    @State private var bannerMessage = ""
    @State private var bannerIsError = false
    @State private var showBanner = false

    var body: some View {
        List {
            if backupMgr.isLoadingBackups {
                HStack {
                    Spacer()
                    ProgressView("Lade Backups…")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if backupMgr.savedBackups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Noch keine iCloud Backups")
                        .font(.headline)
                    Text("Erstelle ein Backup über Einstellungen → iCloud Backup")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(backupMgr.savedBackups) { info in
                    SavedBackupRow(info: info)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                showDeleteConfirm = info
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                showRestoreConfirm = info
                            } label: {
                                Label("Wiederherstellen", systemImage: "arrow.counterclockwise")
                            }
                            .tint(.blue)
                        }
                        .onTapGesture { showRestoreConfirm = info }
                }
            }
        }
        .navigationTitle("Gespeicherte Backups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { backupMgr.loadSavedBackups() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { backupMgr.loadSavedBackups() }
        // Wiederherstellen
        .confirmationDialog(
            "Backup wiederherstellen?",
            isPresented: Binding(get: { showRestoreConfirm != nil }, set: { if !$0 { showRestoreConfirm = nil } }),
            titleVisibility: .visible
        ) {
            if let info = showRestoreConfirm {
                Button("Wiederherstellen", role: .destructive) {
                    Task {
                        let ok = backupMgr.restore(from: info.url, into: store)
                        let msg: String
                        if ok {
                            msg = backupMgr.lastSuccess ?? "Wiederhergestellt"
                        } else {
                            msg = backupMgr.lastError ?? "Fehler"
                        }
                        bannerMessage = msg
                        bannerIsError = !ok
                        showBanner = true
                        showRestoreConfirm = nil
                    }
                }
                Button("Abbrechen", role: .cancel) { showRestoreConfirm = nil }
            }
        } message: {
            if let info = showRestoreConfirm {
                Text("Alle aktuellen Daten werden durch das Backup vom \(info.date.formatted(date: .abbreviated, time: .shortened)) ersetzt.")
            }
        }
        // Löschen
        .confirmationDialog(
            "Backup löschen?",
            isPresented: Binding(get: { showDeleteConfirm != nil }, set: { if !$0 { showDeleteConfirm = nil } }),
            titleVisibility: .visible
        ) {
            if let info = showDeleteConfirm {
                Button("Löschen", role: .destructive) {
                    Task {
                        backupMgr.deleteBackup(info)
                        showDeleteConfirm = nil
                    }
                }
                Button("Abbrechen", role: .cancel) { showDeleteConfirm = nil }
            }
        }
        .overlay(alignment: .top) {
            if showBanner {
                HStack(spacing: 10) {
                    Image(systemName: bannerIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(bannerIsError ? Color.red : Color.iosGreen)
                    Text(bannerMessage)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withOptionalAnimation { showBanner = false }
                        }
                    }
            }
        }
    }
}

// MARK: - Backup Zeile
struct SavedBackupRow: View {
    let info: SavedBackupInfo

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "icloud.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(info.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 15, weight: .medium))
                Text(info.filename)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(info.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.vertical, 4)
    }
}
