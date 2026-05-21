import SwiftUI
import MessageUI

// MARK: - Mail Composer (UIKit-Bridge für MFMailComposeViewController)

struct MailComposerView: UIViewControllerRepresentable {
    var recipients:       [String]
    var subject:          String
    var body:             String
    var attachmentData:   Data?
    var attachmentMime:   String?
    var attachmentName:   String?
    var onFinish:         (MFMailComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        if let data = attachmentData, let mime = attachmentMime, let name = attachmentName {
            vc.addAttachmentData(data, mimeType: mime, fileName: name)
        }
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void
        init(onFinish: @escaping (MFMailComposeResult) -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true)
            onFinish(result)
        }
    }
}

// MARK: - Feedback & Support View

struct FeedbackView: View {

    enum MailMode { case feedback, withLog, support }

    @State private var feedbackText   = ""
    @State private var mailMode: MailMode = .feedback
    @State private var showMail       = false
    @State private var showNoMail     = false
    @State private var showLogSection = false
    @State private var logRefresh     = UUID()   // erzwingt Aktualisierung des Logs
    @Environment(\.dismiss) private var dismiss

    private let supportEmail = "info@wagner-fahrtkosten.de"

    // MARK: Hilfseigenschaften

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    private var deviceInfo: String {
        "iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.model) · App \(appVersion)"
    }

    private var mailSubject: String {
        switch mailMode {
        case .feedback: return "Fahrtkosten App – Feedback"
        case .withLog:  return "Fahrtkosten App – Feedback mit Protokoll"
        case .support:  return "Fahrtkosten App – Support-Anfrage"
        }
    }

    private var mailBody: String {
        let text = feedbackText.isEmpty ? "(kein Text eingegeben)" : feedbackText
        switch mailMode {
        case .feedback:
            return text
        case .withLog:
            return "\(text)\n\n---\nGeräteinformation:\n\(deviceInfo)"
        case .support:
            return "Support-Anfrage\n\nGeräteinformation:\n\(deviceInfo)\n\n---\nZusatzinformationen:\n\(text)"
        }
    }

    private var mailAttachment: (data: Data, mime: String, name: String)? {
        guard mailMode != .feedback else { return nil }
        let content = AppLogger.shared.logFileContents
        guard let data = content.data(using: .utf8) else { return nil }
        return (data, "text/plain", "fahrtkosten_log.txt")
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Form {

                // ── Hinweistext ──────────────────────────────────────────
                Section {
                    Text("""
Ihr Feedback können Sie im folgenden Dialog mit einer Protokolldatei über Ihre E-Mail-Adresse an Thomas Wagner senden. \
Diese Daten werden streng vertraulich behandelt und nicht an Dritte weitergegeben.
""")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                }

                // ── Freitextfeld ─────────────────────────────────────────
                Section(header: Text("Ihr Feedback / Ihre Anfrage")) {
                    ZStack(alignment: .topLeading) {
                        if feedbackText.isEmpty {
                            Text("Beschreiben Sie hier Ihr Anliegen, Fehler oder Verbesserungsvorschläge …")
                                .foregroundColor(Color(uiColor: .placeholderText))
                                .padding(.top, 8)
                                .padding(.horizontal, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $feedbackText)
                            .frame(minHeight: 130)
                    }
                }

                // ── Senden-Buttons ───────────────────────────────────────
                Section(header: Text("Senden")) {
                    Button {
                        mailMode = .feedback
                        openMail()
                    } label: {
                        Label("Feedback senden", systemImage: "paperplane.fill")
                    }

                    Button {
                        mailMode = .withLog
                        openMail()
                    } label: {
                        Label("Feedback + Protokoll senden", systemImage: "doc.badge.ellipsis")
                    }

                    Button {
                        mailMode = .support
                        openMail()
                    } label: {
                        Label("Support-Daten senden", systemImage: "wrench.and.screwdriver.fill")
                    }
                }

                // ── Protokoll-Viewer ─────────────────────────────────────
                Section {
                    Button {
                        withAnimation { showLogSection.toggle() }
                    } label: {
                        HStack {
                            Label("Protokoll anzeigen", systemImage: "doc.text.magnifyingglass")
                                .foregroundColor(.primary)
                            Spacer()
                            if AppLogger.shared.logFileExists {
                                Text(AppLogger.shared.logFileSizeText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: showLogSection ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if showLogSection {
                        let logContent = AppLogger.shared.logFileContents
                        if logContent.isEmpty {
                            Text("Keine Protokolleinträge vorhanden.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ScrollView(.vertical) {
                                Text(logContent)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(6)
                            }
                            .frame(maxHeight: 280)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(8)
                        }

                        if AppLogger.shared.logFileExists {
                            Button(role: .destructive) {
                                AppLogger.shared.clearLog()
                                logRefresh = UUID()
                            } label: {
                                Label("Protokoll löschen", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Protokoll")
                }
            }
            .navigationTitle("Feedback & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            // Mail-Sheet
            .sheet(isPresented: $showMail) {
                let att = mailAttachment
                MailComposerView(
                    recipients:     [supportEmail],
                    subject:        mailSubject,
                    body:           mailBody,
                    attachmentData: att?.data,
                    attachmentMime: att?.mime,
                    attachmentName: att?.name
                ) { _ in showMail = false }
            }
            // Kein E-Mail-Client konfiguriert
            .alert("E-Mail nicht verfügbar", isPresented: $showNoMail) {
                Button("OK") {}
            } message: {
                Text("Auf diesem iPhone ist keine E-Mail-App konfiguriert. Bitte richte die Mail-App ein und versuche es erneut.")
            }
        }
    }

    // MARK: Hilfsmethoden

    private func openMail() {
        if MFMailComposeViewController.canSendMail() {
            showMail = true
        } else {
            showNoMail = true
        }
    }
}
