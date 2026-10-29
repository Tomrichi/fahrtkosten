import SwiftUI

// MARK: - LogViewerSheet
struct LogViewerSheet: View {
    @EnvironmentObject var lm: LocalizationManager
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
                        lm.t("misc.no.entries"),
                        systemImage: "doc.text",
                        description: Text(lm.t("settings.log.empty.desc"))
                    )
                }
            }
            .navigationTitle(lm.t("settings.log.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(lm.t("action.close")) { dismiss() }
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
        .alert(lm.t("settings.log.delete.title"), isPresented: $clearConfirm) {
            Button(lm.t("settings.swipe.delete"), role: .destructive) { logger.clearLog() }
            Button(lm.t("action.cancel"), role: .cancel) {}
        } message: {
            Text(lm.t("settings.log.delete.msg"))
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
    @EnvironmentObject var lm: LocalizationManager
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
                    ProgressView(lm.t("settings.backup.loading"))
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if backupMgr.savedBackups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(lm.t("settings.backup.empty.title"))
                        .font(.headline)
                    Text(lm.t("settings.backup.empty.hint"))
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
                                Label(lm.t("settings.swipe.delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                showRestoreConfirm = info
                            } label: {
                                Label(lm.t("settings.backup.restore.btn"), systemImage: "arrow.counterclockwise")
                            }
                            .tint(.blue)
                        }
                        .onTapGesture { showRestoreConfirm = info }
                }
            }
        }
        .navigationTitle(lm.t("settings.backup.saved.title"))
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
            lm.t("settings.restore.title"),
            isPresented: Binding(get: { showRestoreConfirm != nil }, set: { if !$0 { showRestoreConfirm = nil } }),
            titleVisibility: .visible
        ) {
            if let info = showRestoreConfirm {
                Button(lm.t("settings.backup.restore.btn"), role: .destructive) {
                    Task {
                        let ok = backupMgr.restore(from: info.url, into: store)
                        let msg: String
                        if ok {
                            msg = backupMgr.lastSuccess ?? lm.t("settings.backup.restore.btn")
                        } else {
                            msg = backupMgr.lastError ?? "Fehler"
                        }
                        bannerMessage = msg
                        bannerIsError = !ok
                        showBanner = true
                        showRestoreConfirm = nil
                    }
                }
                Button(lm.t("action.cancel"), role: .cancel) { showRestoreConfirm = nil }
            }
        } message: {
            if let info = showRestoreConfirm {
                Text(String(format: lm.t("settings.backup.restore.msg"), info.date.formatted(date: .abbreviated, time: .shortened)))
            }
        }
        // Löschen
        .confirmationDialog(
            lm.t("settings.backup.delete.title"),
            isPresented: Binding(get: { showDeleteConfirm != nil }, set: { if !$0 { showDeleteConfirm = nil } }),
            titleVisibility: .visible
        ) {
            if let info = showDeleteConfirm {
                Button(lm.t("settings.swipe.delete"), role: .destructive) {
                    Task {
                        backupMgr.deleteBackup(info)
                        showDeleteConfirm = nil
                    }
                }
                Button(lm.t("action.cancel"), role: .cancel) { showDeleteConfirm = nil }
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
