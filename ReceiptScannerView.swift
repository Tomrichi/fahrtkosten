import SwiftUI
import UIKit
import PDFKit
import UniformTypeIdentifiers

// MARK: - Kamera-Picker
struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ p: CameraPickerView) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.onDismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onDismiss() }
    }
}

// MARK: - Fotobibliothek-Picker
struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryPickerView
        init(_ p: PhotoLibraryPickerView) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.onDismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onDismiss() }
    }
}

// MARK: - PDF Document Picker
struct PDFPickerView: UIViewControllerRepresentable {
    var onPicked: (URL) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: PDFPickerView
        init(_ p: PDFPickerView) { parent = p }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { parent.onDismiss(); return }
            parent.onPicked(url)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onDismiss()
        }
    }
}

// MARK: - PDF → UIImage Renderer
struct PDFRenderer {
    /// Rendert alle Seiten eines PDFs als UIImages (72 dpi → für OCR ausreichend)
    static func renderPages(from url: URL, scale: CGFloat = 2.0) -> [UIImage] {
        guard let pdf = PDFDocument(url: url) else { return [] }
        var images: [UIImage] = []
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            let img = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.translateBy(x: 0, y: size.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(img)
        }
        return images
    }

    /// Kombiniert alle Seiten zu einem einzigen langen Bild für die Vorschau
    static func combinedPreview(from images: [UIImage], maxWidth: CGFloat = 600) -> UIImage? {
        guard !images.isEmpty else { return nil }
        let scaledImages = images.map { img -> UIImage in
            let scale = maxWidth / img.size.width
            let newSize = CGSize(width: maxWidth, height: img.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
        }
        let totalHeight = scaledImages.reduce(0) { $0 + $1.size.height }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: maxWidth, height: totalHeight))
        return renderer.image { _ in
            var y: CGFloat = 0
            for img in scaledImages {
                img.draw(at: CGPoint(x: 0, y: y))
                y += img.size.height
            }
        }
    }
}

// MARK: - Receipt Scanner View
struct ReceiptScannerView: View {

    enum ScanTarget {
        case hotel
        case reiseSpese
        case vehicleCost
    }

    let target: ScanTarget
    var onResult: (ReceiptScanResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var pdfPages: [UIImage] = []
    @State private var showCamera        = false
    @State private var showPhotoLibrary  = false
    @State private var showPDFPicker     = false
    @State private var isProcessing      = false
    @State private var showError         = false
    @State private var errorMessage      = "Der Beleg konnte nicht ausgelesen werden."

    private var hasInput: Bool { capturedImage != nil || !pdfPages.isEmpty }
    private var previewImage: UIImage? {
        if let img = capturedImage { return img }
        return PDFRenderer.combinedPreview(from: pdfPages)
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasInput, let preview = previewImage {
                    previewContent(preview)
                } else {
                    promptContent
                }
            }
            .navigationTitle("Beleg importieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        AppLogger.shared.logTap("Beleg: Abbrechen")
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView(image: $capturedImage, onDismiss: { showCamera = false })
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryPickerView(image: $capturedImage, onDismiss: { showPhotoLibrary = false })
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPDFPicker) {
            PDFPickerView(
                onPicked: { url in
                    showPDFPicker = false
                    processPDF(url: url)
                },
                onDismiss: { showPDFPicker = false }
            )
        }
        .alert("Beleg nicht lesbar", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Vorschau
    @ViewBuilder
    private func previewContent(_ img: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // PDF-Badge wenn PDF-Import
                if !pdfPages.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.red)
                            .font(.caption.bold())
                        Text("PDF · \(pdfPages.count) Seite\(pdfPages.count == 1 ? "" : "n")")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                }

                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)

                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.2)
                        Text("Beleg wird ausgelesen …")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                } else {
                    VStack(spacing: 12) {
                        Button {
                            AppLogger.shared.logTap("Beleg: OCR starten")
                            processInput()
                        } label: {
                            Label("Daten automatisch übernehmen", systemImage: "text.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        Button {
                            capturedImage = nil
                            pdfPages = []
                        } label: {
                            Label("Anderen Beleg wählen", systemImage: "arrow.counterclockwise")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Auswahl-Buttons
    private var promptContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 88, height: 88)
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 38, weight: .light))
                        .foregroundColor(.blue)
                }
                VStack(spacing: 8) {
                    Text("Beleg importieren")
                        .font(.title2.bold())
                    Text(target == .hotel
                         ? "Hotelrechnung scannen oder als PDF importieren – Datum, Name, Betrag und Nächte werden automatisch erkannt."
                         : target == .vehicleCost
                         ? "Werkstattrechnung scannen – Einzelpositionen, Kategorien und Beträge werden automatisch erkannt."
                         : "Beleg fotografieren oder als PDF importieren – Datum, Name und Betrag werden automatisch erkannt.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }

            Spacer()

            VStack(spacing: 10) {
                // Kamera
                Button {
                    AppLogger.shared.logTap("Beleg: Kamera öffnen")
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCamera = true
                    } else {
                        showPhotoLibrary = true
                    }
                } label: {
                    Label("Kamera öffnen", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // Fotobibliothek
                Button {
                    AppLogger.shared.logTap("Beleg: Aus Fotos wählen")
                    showPhotoLibrary = true
                } label: {
                    Label("Aus Fotos wählen", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(.secondarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // PDF-Import (NEU)
                Button {
                    AppLogger.shared.logTap("Beleg: PDF importieren")
                    showPDFPicker = true
                } label: {
                    Label("PDF importieren", systemImage: "doc.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.red.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - PDF verarbeiten
    private func processPDF(url: URL) {
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let pages = PDFRenderer.renderPages(from: url, scale: 2.5)
            DispatchQueue.main.async {
                if pages.isEmpty {
                    isProcessing = false
                    errorMessage = "Das PDF konnte nicht geöffnet werden. Bitte prüfe, ob die Datei beschädigt oder passwortgeschützt ist."
                    showError = true
                } else {
                    pdfPages = pages
                    isProcessing = false
                }
            }
        }
    }

    // MARK: - OCR starten (Foto oder PDF)
    private func processInput() {
        isProcessing = true

        if let img = capturedImage {
            // Foto-Pfad: direkt OCR
            ReceiptParser.parse(image: img) { result in
                DispatchQueue.main.async {
                    isProcessing = false
                    handleResult(result)
                }
            }
        } else if !pdfPages.isEmpty {
            // PDF-Pfad: alle Seiten OCR, Ergebnisse zusammenführen
            ReceiptParser.parseMultiPage(images: pdfPages) { result in
                DispatchQueue.main.async {
                    isProcessing = false
                    handleResult(result)
                }
            }
        }
    }

    private func handleResult(_ result: ReceiptScanResult?) {
        if let r = result {
            AppLogger.shared.logScan("Beleg erfolgreich gescannt: Betrag=\(r.suggestedAmount.map { String(format: "%.2f€", $0) } ?? "?"), Datum=\(r.suggestedDate.map { "\($0)" } ?? "?")")
            onResult(r)
            dismiss()
        } else {
            AppLogger.shared.logScan("Beleg-Scan fehlgeschlagen")
            errorMessage = "Der Beleg konnte nicht ausgelesen werden. Bitte versuche ein klareres Foto oder eine bessere PDF-Qualität."
            showError = true
        }
    }
}
