import SwiftUI
import AppIntents

@main
struct FahrtkostenApp: App {
    private let lm = LocalizationManager.shared
    @StateObject private var proMgr = ProManager()
    @AppStorage("preferredColorScheme") private var colorSchemePref: String = "system"
    @State private var showSplash = true
    @State private var pendingImportFrom: String? = nil
    @State private var pendingImportTo:   String? = nil
    @State private var pendingImportTravelTime: Int = 0
    @State private var pendingImportKm: Double = 0

    private static let appGroup = "group.de.tommwagner.fahrtkosten"

    // Watch Session starten
    private let watchSession = WatchSessionManager.shared

    init() {
        _ = AppLogger.shared

        let device  = UIDevice.current
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        AppLogger.shared.log(
            "iOS \(device.systemVersion) · \(device.model) · App \(version) (\(build))",
            level: .info
        )

        // Siri-Shortcuts bei jedem App-Start registrieren
        FahrtkostenShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !showSplash {
                    ContentView()
                        .environmentObject(lm)
                        .environmentObject(proMgr)
                        .preferredColorScheme(resolvedColorScheme)
                        .transition(.opacity)
                        .onAppear {
                            guard let from = pendingImportFrom,
                                  let to   = pendingImportTo else { return }
                            let tt = pendingImportTravelTime
                            // FahrtenView braucht kurz Zeit zum Subscriben
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                NotificationCenter.default.post(
                                    name: .importFromMaps,
                                    object: nil,
                                    userInfo: ["from": from, "to": to, "travelTime": tt, "km": pendingImportKm]
                                )
                                pendingImportFrom       = nil
                                pendingImportTo         = nil
                                pendingImportTravelTime = 0
                            }
                        }
                }

                if showSplash {
                    SplashScreenView {
                        withOptionalAnimation(.easeInOut(duration: 0.3)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSplash)
            .preferredColorScheme(resolvedColorScheme)
            .onOpenURL { url in
                guard url.scheme == "fahrtkosten",
                      url.host   == "import",
                      let comps   = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let from    = comps.queryItems?.first(where: { $0.name == "from" })?.value,
                      let to      = comps.queryItems?.first(where: { $0.name == "to"   })?.value
                else { return }
                let travelTime = comps.queryItems?.first(where: { $0.name == "travelTime" }).flatMap { Int($0.value ?? "") } ?? 0
                let km         = comps.queryItems?.first(where: { $0.name == "km" }).flatMap { Double($0.value ?? "") } ?? 0
                triggerImport(from: from, to: to, travelTime: travelTime, km: km)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                checkPendingImportFromAppGroup()
            }
        }
    }

    private func checkPendingImportFromAppGroup() {
        guard let ud   = UserDefaults(suiteName: Self.appGroup),
              let from = ud.string(forKey: "pendingImportFrom"),
              let to   = ud.string(forKey: "pendingImportTo"),
              !to.isEmpty
        else { return }
        let travelTime = ud.integer(forKey: "pendingImportTravelTime")
        let km         = ud.double(forKey: "pendingImportKm")
        ud.removeObject(forKey: "pendingImportFrom")
        ud.removeObject(forKey: "pendingImportTo")
        ud.removeObject(forKey: "pendingImportTravelTime")
        ud.removeObject(forKey: "pendingImportKm")
        triggerImport(from: from, to: to, travelTime: travelTime, km: km)
    }

    private func triggerImport(from: String, to: String, travelTime: Int = 0, km: Double = 0) {
        if showSplash {
            pendingImportFrom       = from
            pendingImportTo         = to
            pendingImportTravelTime = travelTime
            pendingImportKm         = km
            withOptionalAnimation(.easeInOut(duration: 0.3)) { showSplash = false }
        } else {
            NotificationCenter.default.post(
                name: .importFromMaps,
                object: nil,
                userInfo: ["from": from, "to": to, "travelTime": travelTime, "km": km]
            )
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemePref {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}
