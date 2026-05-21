import SwiftUI

struct CloudBackupListView: View {
    @ObservedObject var backupMgr: BackupManager
    @EnvironmentObject var store: DataStore
    @State private var showRestoreConfirm: CloudBackupInfo? = nil
    @State private var showDeleteConfirm:  CloudBackupInfo? = nil
    @State private var bannerMessage = ""
    @State private var bannerIsError = false
    @State private var showBanner = false

    var body: some View {
        List {
            if backupMgr.isLoadingCloudBackups {
                HStack {
                    Spacer()
                    ProgressView("Lade Backups…")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if backupMgr.cloudBackups.isEmpty {
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
                ForEach(backupMgr.cloudBackups) { info in
                    CloudBackupRow(info: info)
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
        .navigationTitle("iCloud Backups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await backupMgr.loadCloudBackups() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await backupMgr.loadCloudBackups() }
        // Wiederherstellen
        .confirmationDialog(
            "Backup wiederherstellen?",
            isPresented: Binding(get: { showRestoreConfirm != nil }, set: { if !$0 { showRestoreConfirm = nil } }),
            titleVisibility: .visible
        ) {
            if let info = showRestoreConfirm {
                Button("Wiederherstellen", role: .destructive) {
                    Task {
                        let ok = await backupMgr.restoreFromiCloud(info, into: store)
                        bannerMessage = ok
                            ? (backupMgr.lastSuccess ?? "Wiederhergestellt")
                            : (backupMgr.lastError ?? "Fehler")
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
                        await backupMgr.deleteCloudBackup(info)
                        showDeleteConfirm = nil
                    }
                }
                Button("Abbrechen", role: .cancel) { showDeleteConfirm = nil }
            }
        }
        .overlay(alignment: .top) {
            if showBanner {
                BannerView(message: bannerMessage, isError: bannerIsError)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { showBanner = false }
                        }
                    }
            }
        }
    }
}

// MARK: - Backup Zeile
struct CloudBackupRow: View {
    let info: CloudBackupInfo

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
