import SwiftUI

struct DetailsPanelView: View {
    @EnvironmentObject private var browser: BrowserStore
    @State private var mode: InspectorMode = .details

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker(L10n.text(.inspectorMode, for: browser.language), selection: $mode) {
                    ForEach(InspectorMode.allCases) { mode in
                        Text(mode.title(for: browser.language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 176)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 42)

            Divider()

            if mode == .details {
                if let item = browser.selectedItems.first {
                    SelectedItemDetails(item: item, displayName: browser.displayName(for: item), language: browser.language)
                } else {
                    FolderDetails()
                }
            } else {
                PreviewContentView(
                    item: browser.selectedItems.first,
                    displayName: browser.selectedItems.first.map { browser.displayName(for: $0) },
                    language: browser.language
                )
            }

            Spacer()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private enum InspectorMode: String, CaseIterable, Identifiable {
    case details
    case preview

    var id: String { rawValue }

    var title: String {
        title(for: .english)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .details: L10n.text(.details, for: language)
        case .preview: L10n.text(.preview, for: language)
        }
    }
}

private struct PreviewContentView: View {
    let item: FileItem?
    let displayName: String?
    let language: AppLanguage

    var body: some View {
        Group {
            if let item {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        FileIconView(url: item.url, size: 18)
                        Text(displayName ?? item.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 36)

                    Divider()

                    QuickLookPreviewView(url: item.url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .textBackgroundColor))
                }
            } else {
                ContentUnavailableView(
                    L10n.text(.noSelection, for: language),
                    systemImage: "doc.viewfinder",
                    description: Text(L10n.text(.selectItemToPreview, for: language))
                )
                .padding(22)
            }
        }
    }
}

private struct SelectedItemDetails: View {
    let item: FileItem
    let displayName: String
    let language: AppLanguage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 10) {
                    FileIconView(url: item.url, size: 72)
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

                DetailGroup(title: L10n.text(.general, for: language)) {
                    DetailRow(label: L10n.text(.type, for: language), value: item.typeDescription)
                    DetailRow(label: L10n.text(.size, for: language), value: item.isDirectory ? "--" : ExplorerFormatters.fileSize(item.fileSize))
                    DetailRow(label: L10n.text(.modified, for: language), value: ExplorerFormatters.date(item.modificationDate))
                    DetailRow(label: L10n.text(.created, for: language), value: ExplorerFormatters.date(item.creationDate))
                }

                if item.isDirectory {
                    FolderStatisticsSection(url: item.url, language: language)
                }

                DetailGroup(title: L10n.text(.location, for: language)) {
                    DetailRow(label: L10n.text(.path, for: language), value: item.url.deletingLastPathComponent().path)
                    DetailRow(label: L10n.text(.hidden, for: language), value: item.isHidden ? L10n.text(.yes, for: language) : L10n.text(.no, for: language))
                    DetailRow(
                        label: L10n.text(.permissions, for: language),
                        value: L10n.permissions(
                            readable: item.isReadable,
                            writable: item.isWritable,
                            executable: item.isExecutable,
                            for: language
                        )
                    )
                }
            }
            .padding(16)
        }
    }
}

private struct FolderDetails: View {
    @EnvironmentObject private var browser: BrowserStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 10) {
                    FileIconView(url: browser.currentURL, size: 72)
                    Text(
                        browser.currentURL.lastPathComponent.isEmpty
                            ? browser.currentURL.path
                            : browser.currentURL.lastPathComponent
                    )
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

                DetailGroup(title: L10n.text(.currentFolder, for: browser.language)) {
                    DetailRow(label: L10n.text(.items, for: browser.language), value: "\(browser.displayedItems.count)")
                    DetailRow(label: L10n.text(.path, for: browser.language), value: browser.currentURL.path)
                }
            }
            .padding(16)
        }
    }
}

private struct FolderStatisticsSection: View {
    let url: URL
    let language: AppLanguage

    @State private var statistics: FolderStatistics?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = FolderStatisticsService()

    var body: some View {
        DetailGroup(title: L10n.text(.contents, for: language)) {
            if let statistics {
                DetailRow(label: L10n.text(.files, for: language), value: "\(statistics.fileCount)")
                DetailRow(label: L10n.text(.folders, for: language), value: "\(statistics.folderCount)")
                DetailRow(label: L10n.text(.size, for: language), value: ExplorerFormatters.fileSize(statistics.totalSize))

                if statistics.skippedDirectoryCount > 0 {
                    DetailRow(label: L10n.text(.skipped, for: language), value: "\(statistics.skippedDirectoryCount)")
                }
            } else if let errorMessage {
                DetailRow(label: L10n.text(.failed, for: language), value: errorMessage)
            } else {
                DetailRow(
                    label: L10n.text(.size, for: language),
                    value: isLoading ? L10n.text(.calculating, for: language) : "--"
                )
            }
        }
        .task(id: url.standardizedFileURL) {
            await loadStatistics()
        }
    }

    private func loadStatistics() async {
        statistics = nil
        errorMessage = nil
        isLoading = true

        do {
            let loadedStatistics = try await service.statistics(for: url)
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            statistics = loadedStatistics
            isLoading = false
        } catch is CancellationError {
            isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

private struct DetailGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 7) {
                content
            }
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12))
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
