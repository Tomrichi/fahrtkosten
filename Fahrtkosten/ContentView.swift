import SwiftUI
import Combine

// MARK: - Settings Environment Key
class SettingsController: ObservableObject {
    @Published var showSettings = false
}

// MARK: - Tab Definition

private enum AppTab: Int, CaseIterable {
    case fahrten, arbeitszeit, uebernachtung, kfzKosten, uebersicht, statistik, suche

    var label: String {
        switch self {
        case .fahrten:       return "Fahrzeit"
        case .arbeitszeit:   return "Arbeitszeit"
        case .uebernachtung: return "Übernacht."
        case .kfzKosten:     return "KFZ"
        case .uebersicht:    return "Übersicht"
        case .statistik:     return "Statistik"
        case .suche:         return "Suche"
        }
    }

    var icon: String {
        switch self {
        case .fahrten:       return "car.fill"
        case .arbeitszeit:   return "clock.fill"
        case .uebernachtung: return "bed.double.fill"
        case .kfzKosten:     return "wrench.and.screwdriver.fill"
        case .uebersicht:    return "list.bullet.rectangle.portrait.fill"
        case .statistik:     return "chart.bar.fill"
        case .suche:         return "magnifyingglass"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var store              = DataStore()
    @StateObject private var settingsController = SettingsController()
    @EnvironmentObject var lm: LocalizationManager

    @State private var selectedTab: AppTab = .fahrten

    var body: some View {
        VStack(spacing: 0) {
            // Active tab content
            ZStack {
                FahrtenView()
                    .environmentObject(store)
                    .environmentObject(settingsController)
                    .environmentObject(lm)
                    .opacity(selectedTab == .fahrten ? 1 : 0)
                    .allowsHitTesting(selectedTab == .fahrten)

                ArbeitszeitView()
                    .environmentObject(store)
                    .environmentObject(settingsController)
                    .environmentObject(lm)
                    .opacity(selectedTab == .arbeitszeit ? 1 : 0)
                    .allowsHitTesting(selectedTab == .arbeitszeit)

                UebernachtungView()
                    .environmentObject(store)
                    .environmentObject(settingsController)
                    .environmentObject(lm)
                    .opacity(selectedTab == .uebernachtung ? 1 : 0)
                    .allowsHitTesting(selectedTab == .uebernachtung)

                KFZKostenView()
                    .environmentObject(store)
                    .environmentObject(settingsController)
                    .environmentObject(lm)
                    .opacity(selectedTab == .kfzKosten ? 1 : 0)
                    .allowsHitTesting(selectedTab == .kfzKosten)

                UebersichtView()
                    .environmentObject(store)
                    .environmentObject(settingsController)
                    .environmentObject(lm)
                    .opacity(selectedTab == .uebersicht ? 1 : 0)
                    .allowsHitTesting(selectedTab == .uebersicht)

                SearchView()
                    .environmentObject(store)
                    .environmentObject(settingsController)
                    .environmentObject(lm)
                    .opacity(selectedTab == .suche ? 1 : 0)
                    .allowsHitTesting(selectedTab == .suche)

                StatistikView()
                    .environmentObject(store)
                    .opacity(selectedTab == .statistik ? 1 : 0)
                    .allowsHitTesting(selectedTab == .statistik)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .tint(.blue)
        .onReceive(NotificationCenter.default.publisher(for: .watchDidSaveTrip)) { _ in
            store.reloadFromWatch()
            WatchSessionManager.shared.sendContextToWatch()
        }
        .sheet(isPresented: $settingsController.showSettings) {
            EinstellungenView()
                .environmentObject(store)
                .environmentObject(lm)
        }
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    TabBarButton(tab: tab, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, safeAreaBottom + 2)
            .background(.bar)
        }
    }
}

private struct TabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)
                Text(tab.label)
                    .font(.system(size: 9, weight: .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(isSelected ? .blue : Color(.label).opacity(0.5))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
