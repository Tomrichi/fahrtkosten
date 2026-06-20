import UIKit
import UniformTypeIdentifiers
import MapKit
import CoreLocation

class ShareViewController: UIViewController {

    // MARK: - UI
    private let containerView  = UIView()
    private let handleBar      = UIView()
    private let titleLabel     = UILabel()
    private let fromIcon       = UILabel()
    private let fromLabel      = UILabel()
    private let toIcon         = UILabel()
    private let toLabel        = UILabel()
    private let noteLabel      = UILabel()
    private let importButton   = UIButton(type: .system)
    private let cancelButton   = UIButton(type: .system)
    private let spinner        = UIActivityIndicatorView(style: .medium)

    private var parsedFrom = ""
    private var parsedTo   = ""
    private var parsedTravelTime: Int = 0
    private var parsedKm: Double = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractURL()
    }

    // MARK: - URL extrahieren

    private func extractURL() {
        guard let item        = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments, !attachments.isEmpty else {
            showError("Keine URL gefunden."); return
        }

        let urlType  = UTType.url.identifier
        let textType = UTType.plainText.identifier

        // Alle Attachments prüfen: erst URL-Typ suchen, dann Text-Typ
        var urlProvider:  NSItemProvider? = nil
        var textProvider: NSItemProvider? = nil
        for provider in attachments {
            if urlProvider  == nil && provider.hasItemConformingToTypeIdentifier(urlType)  { urlProvider  = provider }
            if textProvider == nil && provider.hasItemConformingToTypeIdentifier(textType) { textProvider = provider }
        }

        if let provider = urlProvider {
            provider.loadItem(forTypeIdentifier: urlType) { [weak self] obj, _ in
                guard let url = obj as? URL else { self?.showError("URL nicht lesbar."); return }
                self?.handleURL(url)
            }
        } else if let provider = textProvider {
            provider.loadItem(forTypeIdentifier: textType) { [weak self] obj, _ in
                guard let text = obj as? String else { self?.showError("Text nicht lesbar."); return }
                // URL aus dem Text extrahieren (Google Maps teilt oft "Name\nhttps://...")
                if let url = self?.extractURLFromText(text) {
                    self?.handleURL(url)
                } else {
                    self?.showError("Keine erkannte URL im geteilten Text.")
                }
            }
        } else {
            showError("Nicht unterstütztes Format.")
        }
    }

    // Adresse bereinigen: + → Leerzeichen, Percent-Encoding auflösen
    private func cleanAddress(_ raw: String) -> String {
        let s = raw.removingPercentEncoding ?? raw
        return s.replacingOccurrences(of: "+", with: " ").trimmingCharacters(in: .whitespaces)
    }

    // Stadt und Straße aus einer Adresse extrahieren (DE 5-stellig, AT/CH 4-stellig)
    // z.B. "Nebelhornstraße 12A, 86420 Diedorf, Deutschland" → "Diedorf, Nebelhornstraße 12A"
    // z.B. "Steirische Straße 5, 8605 Kapfenberg, Österreich" → "Kapfenberg, Steirische Straße 5"
    private func extractCity(_ address: String) -> String {
        let components = address.components(separatedBy: ", ")
        var cityName: String?
        var plzIndex: Int?

        for (i, component) in components.enumerated() {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.components(separatedBy: " ")
            if parts.count >= 2,
               let first = parts.first,
               (first.count == 4 || first.count == 5),
               first.allSatisfy({ $0.isNumber }) {
                cityName = parts.dropFirst().joined(separator: " ")
                plzIndex = i
                break
            }
        }

        guard let city = cityName, let idx = plzIndex else {
            // Kein PLZ-Muster: erstes Element ist meist Stadt oder Straße, letztes oft Land
            return components.first?.trimmingCharacters(in: .whitespaces) ?? address
        }

        // Straße ist der Teil vor der PLZ-Komponente (Index idx-1)
        if idx > 0 {
            let street = components[idx - 1].trimmingCharacters(in: .whitespaces)
            return "\(city), \(street)"
        }
        return city
    }

    // Prüft ob String GPS-Koordinaten sind, gibt CLLocation zurück
    private func parseCoordinates(_ s: String) -> CLLocation? {
        let parts = s.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              abs(lat) <= 90, abs(lon) <= 180 else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    // Reverse Geocoding: Koordinaten → "Stadt, Straße HausNr", dann calculateAndShow aufrufen
    private func reverseGeocodeAndShow(location: CLLocation, to: String) {
        Task { [weak self] in
            guard let self else { return }
            guard let req = MKReverseGeocodingRequest(location: location) else { return }
            let items = (try? await req.mapItems) ?? []
            let item = items.first
            let fromLabel: String
            if let full = item?.address?.fullAddress, !full.isEmpty {
                fromLabel = extractCity(full)
            } else if let short = item?.address?.shortAddress, !short.isEmpty {
                fromLabel = short
            } else {
                fromLabel = "Aktueller Standort"
            }
            await MainActor.run { self.calculateAndShow(from: fromLabel, to: to) }
        }
    }

    // Zeige Ergebnis sofort, berechne Reisezeit asynchron
    private func calculateAndShow(from: String, to: String) {
        // UI sofort zeigen
        showResult(from: from, to: to)

        // Reisezeit via MKDirections berechnen
        Task { [weak self] in
            guard let self else { return }
            guard let fromReq = MKGeocodingRequest(addressString: from),
                  let toReq   = MKGeocodingRequest(addressString: to) else { return }
            async let fromItemsFuture = (try? fromReq.mapItems) ?? []
            async let toItemsFuture   = (try? toReq.mapItems)   ?? []
            guard let fromItem = await fromItemsFuture.first,
                  let toItem   = await toItemsFuture.first else { return }

            let request = MKDirections.Request()
            request.source      = fromItem
            request.destination = toItem
            request.transportType = .automobile

            guard let route = try? await MKDirections(request: request).calculate().routes.first else { return }
            let seconds = Int(route.expectedTravelTime)
            let km      = route.distance / 1000.0
            await MainActor.run {
                self.parsedTravelTime = seconds
                self.parsedKm = km
                self.showTravelTime(seconds)
                if let ud = UserDefaults(suiteName: "group.de.tommwagner.fahrtkosten") {
                    ud.set(seconds, forKey: "pendingImportTravelTime")
                    ud.set(km,      forKey: "pendingImportKm")
                    ud.synchronize()
                }
            }
        }
    }

    private func extractURLFromText(_ text: String) -> URL? {
        // Direkt als URL parsen
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true { return url }
        // URL aus mehrzeiligem Text extrahieren
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches  = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        return matches.compactMap { $0.url }.first { $0.scheme?.hasPrefix("http") == true }
    }

    private func handleURL(_ url: URL) {
        let host = url.host ?? ""

        // Google Consent-Seite: eigentliche URL im "continue"-Parameter
        if host.contains("consent.google.com") {
            if let comps   = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let contStr = comps.queryItems?.first(where: { $0.name == "continue" })?.value,
               let contURL = URL(string: contStr) {
                handleURL(contURL)
            } else {
                // Redirect folgen wenn continue-Parameter fehlt
                resolveShortURL(url) { [weak self] resolved in
                    if let r = resolved { self?.parseGoogleMapsURL(r) }
                    else { self?.showError("Consent-Seite konnte nicht aufgelöst werden.") }
                }
            }
            return
        }

        if host.contains("maps.apple.com") {
            parseAppleMapsURL(url)
        } else if host.contains("google.com") || host.contains("maps.google.com") {
            parseGoogleMapsURL(url)
        } else if host.contains("goo.gl") {
            resolveShortURL(url) { [weak self] resolved in
                if let r = resolved { self?.handleURL(r) }
                else { self?.showError("Kurzlink konnte nicht aufgelöst werden.") }
            }
        } else {
            showError("Keine unterstützte Maps-URL.\n(Apple Maps oder Google Maps)")
        }
    }

    // MARK: - Apple Maps Parser
    // Beispiel: https://maps.apple.com/?saddr=München&daddr=Berlin&dirflg=d

    private func parseAppleMapsURL(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            showError("Apple Maps URL nicht lesbar."); return
        }
        let params = Dictionary(uniqueKeysWithValues:
            (comps.queryItems ?? []).compactMap { item -> (String, String)? in
                guard let v = item.value else { return nil }
                return (item.name, v)
            }
        )
        let from = cleanAddress(params["saddr"] ?? "")
        let to   = cleanAddress(params["daddr"] ?? "")
        guard !to.isEmpty else { showError("Kein Zielort in der Apple Maps URL."); return }
        let toCity = extractCity(to)
        DispatchQueue.main.async {
            self.calculateAndShow(from: from.isEmpty ? "Aktueller Standort" : from, to: toCity)
        }
    }

    // MARK: - Google Maps Parser
    // Beispiel: https://www.google.com/maps/dir/München,+Deutschland/Berlin,+Deutschland/

    private func parseGoogleMapsURL(_ url: URL) {
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let params = Dictionary(
                (comps.queryItems ?? []).compactMap { item -> (String, String)? in
                    guard let v = item.value, !v.isEmpty else { return nil }
                    return (item.name, v)
                },
                uniquingKeysWith: { first, _ in first }
            )

            // Format 1: ?origin=...&destination=... (aktuelles Google Maps)
            if let to = params["destination"], !to.isEmpty {
                let from    = cleanAddress(params["origin"] ?? "")
                let toClean = extractCity(cleanAddress(to))
                if let loc = parseCoordinates(from) {
                    reverseGeocodeAndShow(location: loc, to: toClean)
                } else {
                    DispatchQueue.main.async {
                        self.calculateAndShow(from: from.isEmpty ? "Aktueller Standort" : from, to: toClean)
                    }
                }
                return
            }

            // Format 2: ?saddr=...&daddr=... (älteres Google Maps)
            if let to = params["daddr"], !to.isEmpty {
                let from    = cleanAddress(params["saddr"] ?? "")
                let toClean = extractCity(cleanAddress(to))
                if let loc = parseCoordinates(from) {
                    reverseGeocodeAndShow(location: loc, to: toClean)
                } else {
                    DispatchQueue.main.async {
                        self.calculateAndShow(from: from.isEmpty ? "Aktueller Standort" : from, to: toClean)
                    }
                }
                return
            }

            // Format 3: ?q=... (einzelner Ort – als Ziel verwenden)
            if let q = params["q"], !q.isEmpty {
                let toClean = extractCity(self.cleanAddress(q))
                DispatchQueue.main.async { self.calculateAndShow(from: "Aktueller Standort", to: toClean) }
                return
            }
        }

        // Format 4: /maps/dir/ORIGIN/DESTINATION/ (Pfad-Format)
        let parts = url.pathComponents
        if let dirIdx = parts.firstIndex(of: "dir"), parts.count > dirIdx + 2 {
            let from   = cleanAddress(parts[dirIdx + 1])
            let toRaw  = cleanAddress(parts[dirIdx + 2])
            let toCity = extractCity(toRaw)
            guard !toCity.isEmpty && toCity != "/" else { showError("Zielort nicht erkannt."); return }
            if let loc = parseCoordinates(from) {
                reverseGeocodeAndShow(location: loc, to: toCity)
            } else {
                DispatchQueue.main.async {
                    self.calculateAndShow(from: from.isEmpty ? "Aktueller Standort" : from, to: toCity)
                }
            }
            return
        }

        // geocode-Parameter: Place-ID → Redirect folgen um lesbare Adresse zu bekommen
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           comps.queryItems?.contains(where: { $0.name == "geocode" }) == true {
            resolveShortURL(url) { [weak self] resolved in
                if let r = resolved, r != url {
                    self?.parseGoogleMapsURL(r)
                } else {
                    self?.showError("Route nicht erkannt.\nURL: \(url.absoluteString.prefix(100))")
                }
            }
            return
        }

        // Nichts erkannt → URL zur Diagnose anzeigen
        let hint = url.absoluteString.prefix(120)
        showError("Route nicht erkannt.\nURL: \(hint)")
    }

    // MARK: - Short URL auflösen

    private func resolveShortURL(_ url: URL, completion: @escaping (URL?) -> Void) {
        DispatchQueue.main.async { self.spinner.startAnimating() }
        // GET statt HEAD: folgt Redirects zuverlässig
        let config  = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        session.dataTask(with: url) { _, response, _ in
            DispatchQueue.main.async { self.spinner.stopAnimating() }
            completion((response as? HTTPURLResponse)?.url ?? url)
        }.resume()
    }

    // MARK: - Ergebnis anzeigen

    private func showResult(from: String, to: String) {
        parsedFrom = from
        parsedTo   = to
        fromLabel.text = from
        toLabel.text   = to
        spinner.stopAnimating()
        fromIcon.isHidden    = false
        fromLabel.isHidden   = false
        toIcon.isHidden      = false
        toLabel.isHidden     = false
        // Import erst freischalten wenn Reisezeit berechnet
        importButton.isEnabled = false
        importButton.alpha     = 0.4
        noteLabel.text      = "Reisezeit wird berechnet…"
        noteLabel.textColor = .secondaryLabel
        noteLabel.isHidden  = false
    }

    private func showTravelTime(_ seconds: Int) {
        DispatchQueue.main.async {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            self.noteLabel.text = h > 0
                ? String(format: "Reisezeit: %dh %02dmin", h, m)
                : String(format: "Reisezeit: %dmin", m)
            self.importButton.isEnabled = true
            self.importButton.alpha     = 1
        }
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async {
            self.spinner.stopAnimating()
            self.noteLabel.text      = message
            self.noteLabel.isHidden  = false
            self.noteLabel.textColor = .systemRed
            self.importButton.isEnabled = false
            self.importButton.alpha     = 0.4
        }
    }

    // MARK: - Aktionen

    @objc private func importTapped() {
        guard !parsedTo.isEmpty else { return }

        let travelTime = parsedTravelTime
        let km         = parsedKm

        // Daten in App Group UserDefaults schreiben
        if let ud = UserDefaults(suiteName: "group.de.tommwagner.fahrtkosten") {
            ud.set(parsedFrom, forKey: "pendingImportFrom")
            ud.set(parsedTo,   forKey: "pendingImportTo")
            ud.set(travelTime, forKey: "pendingImportTravelTime")
            ud.set(km,         forKey: "pendingImportKm")
            ud.synchronize()
        }

        // App über URL-Scheme öffnen (Host-App leitet weiter), dann Extension schließen
        var comps        = URLComponents()
        comps.scheme     = "fahrtkosten"
        comps.host       = "import"
        comps.queryItems = [
            URLQueryItem(name: "from",       value: parsedFrom),
            URLQueryItem(name: "to",         value: parsedTo),
            URLQueryItem(name: "travelTime", value: "\(travelTime)"),
            URLQueryItem(name: "km",         value: String(format: "%.1f", km))
        ]
        if let url = comps.url {
            extensionContext?.open(url) { [weak self] _ in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        } else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }


    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        // Container (Bottom Sheet)
        containerView.backgroundColor    = UIColor.systemBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Handle
        handleBar.backgroundColor            = UIColor.systemGray4
        handleBar.layer.cornerRadius          = 2.5
        handleBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(handleBar)

        // Titel
        titleLabel.text          = "Fahrt importieren"
        titleLabel.font          = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Spinner
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        containerView.addSubview(spinner)

        // From-Icon
        fromIcon.text      = "🟢"
        fromIcon.font      = .systemFont(ofSize: 14)
        fromIcon.isHidden  = true
        fromIcon.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(fromIcon)

        // From-Label
        fromLabel.font          = .systemFont(ofSize: 15, weight: .medium)
        fromLabel.textColor     = .label
        fromLabel.numberOfLines = 2
        fromLabel.isHidden      = true
        fromLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(fromLabel)

        // To-Icon
        toIcon.text      = "🔴"
        toIcon.font      = .systemFont(ofSize: 14)
        toIcon.isHidden  = true
        toIcon.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(toIcon)

        // To-Label
        toLabel.font          = .systemFont(ofSize: 15, weight: .medium)
        toLabel.textColor     = .label
        toLabel.numberOfLines = 2
        toLabel.isHidden      = true
        toLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(toLabel)

        // Note-Label (Fehler / Hinweis)
        noteLabel.text          = "Route wird gelesen…"
        noteLabel.font          = .systemFont(ofSize: 14)
        noteLabel.textColor     = .secondaryLabel
        noteLabel.textAlignment = .center
        noteLabel.numberOfLines = 3
        noteLabel.isHidden      = false
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(noteLabel)

        // Import-Button
        importButton.setTitle("In Fahrtkosten importieren", for: .normal)
        importButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        importButton.backgroundColor  = .systemBlue
        importButton.setTitleColor(.white, for: .normal)
        importButton.layer.cornerRadius = 14
        importButton.isEnabled          = false
        importButton.alpha              = 0.4
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        importButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(importButton)

        // Abbrechen-Button
        cancelButton.setTitle("Abbrechen", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15)
        cancelButton.setTitleColor(.secondaryLabel, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelButton)

        let p: CGFloat = 20
        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            handleBar.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 36),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: p),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -p),

            spinner.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            spinner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            noteLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            noteLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: p),
            noteLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -p),

            fromIcon.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            fromIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: p),
            fromIcon.widthAnchor.constraint(equalToConstant: 24),

            fromLabel.topAnchor.constraint(equalTo: fromIcon.topAnchor),
            fromLabel.leadingAnchor.constraint(equalTo: fromIcon.trailingAnchor, constant: 8),
            fromLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -p),

            toIcon.topAnchor.constraint(equalTo: fromLabel.bottomAnchor, constant: 12),
            toIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: p),
            toIcon.widthAnchor.constraint(equalToConstant: 24),

            toLabel.topAnchor.constraint(equalTo: toIcon.topAnchor),
            toLabel.leadingAnchor.constraint(equalTo: toIcon.trailingAnchor, constant: 8),
            toLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -p),

            importButton.topAnchor.constraint(equalTo: toLabel.bottomAnchor, constant: 24),
            importButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: p),
            importButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -p),
            importButton.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.topAnchor.constraint(equalTo: importButton.bottomAnchor, constant: 10),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }
}
