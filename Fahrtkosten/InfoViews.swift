import SwiftUI
import WebKit

// MARK: - Versionshinweise View
struct VersionHistoryView: View {
    @EnvironmentObject var lm: LocalizationManager

    var body: some View {
        NavigationStack {
            HTMLWebView(html: versionHistoryHTML(for: lm.language))
                .navigationTitle(lm.t("settings.version.history"))
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
