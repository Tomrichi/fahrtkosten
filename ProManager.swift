import SwiftUI
import Combine

/// ProManager ohne In-App-Käufe – App ist Einmalkauf im App Store.
/// isPro ist immer true, da alle Features für alle Käufer freigeschaltet sind.
@MainActor
class ProManager: ObservableObject {
    @Published var isPro: Bool = true
    @Published var googleApiKey: String {
        didSet { UserDefaults.standard.set(googleApiKey, forKey: "googleApiKey") }
    }

    init() {
        self.googleApiKey = UserDefaults.standard.string(forKey: "googleApiKey") ?? ""
    }
}
