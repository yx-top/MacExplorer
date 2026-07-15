import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileListView: View {
    @EnvironmentObject private var browser: BrowserStore

    var body: some View {
        VStack(spacing: 0) {
            FileListHeader()
            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(browser.displayedItems) { item in
                        FileListRow(item: item, isSelected: browser.selectedItemIDs.contains(item.id))
                    }
                }
            }
        }
    }
}

private struct FileListHeader: View {
    @EnvironmentObject private var browser: BrowserStore

    var body: some View {
        HStack(spacing: 12) {
            HeaderButton(field: .name)
                .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
            HeaderButton(field: .type)
                .frame(width: 150, alignment: .leading)
            HeaderButton(field: .size)
                .frame(width: 90, alignment: .trailing)
            HeaderButton(field: .modified)
                .frame(width: 168, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(height: 31)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private struct HeaderButton: View {
        @EnvironmentObject private var browser: BrowserStore
        let field: FileSortField

        var body: some View {
            Button {
                browser.toggleSort(field)
            } label: {
                HStack(spacing: 5) {
                    Text(field.title(for: browser.language))
                        .font(.system(size: 12, weight: .semibold))
                    if browser.sort.field == field {
                        Image(systemName: browser.sort.direction == .ascending ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FileListRow: View {
    @EnvironmentObject private var browser: BrowserStore
    let item: FileItem
    let isSelected: Bool
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                FileIconView(url: item.url, size: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(browser.displayName(for: item))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if browser.isRecursiveSearchActive {
                        Label(browser.searchLocationDescription(for: item), systemImage: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .labelStyle(.titleAndIcon)
                            .help(browser.fullLocationPath(for: item))
                    }
                }
            }
            .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)

            Text(item.typeDescription)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(item.isDirectory ? "--" : ExplorerFormatters.fileSize(item.fileSize))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)

            Text(ExplorerFormatters.date(item.modificationDate))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: 168, alignment: .leading)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: browser.isRecursiveSearchActive ? 44 : AppTheme.listRowHeight)
        .background(isSelected ? AppTheme.selectedStrongFill : Color.clear)
        .overlay {
            if isDropTargeted && item.isDirectory {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
        }
        .contentShape(Rectangle())
        .gesture(itemActivationGesture)
        .onDrag {
            makeDragItemProvider()
        }
        .onDrop(of: [macExplorerDraggedFileURLsType, UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .contextMenu {
            Button(L10n.text(.open, for: browser.language)) {
                browser.select(item)
                Task { await browser.open(item) }
            }
            Button(L10n.text(.openWith, for: browser.language)) {
                browser.select(item)
                Task { await browser.openSelectedWithApplicationFromPrompt() }
            }
            Button(L10n.text(.quickLook, for: browser.language)) {
                browser.select(item)
                browser.previewSelectedItems()
            }
            Divider()
            Button(L10n.text(.copy, for: browser.language)) {
                browser.select(item)
                browser.copySelectedItems()
            }
            Button(L10n.text(.cut, for: browser.language)) {
                browser.select(item)
                browser.cutSelectedItems()
            }
            Button(L10n.text(.rename, for: browser.language)) {
                browser.select(item)
                Task { await browser.renameSelectedFromPrompt() }
            }
            .disabled(!browser.canStartFileOperation)
            Button(L10n.text(.moveToTrash, for: browser.language)) {
                browser.select(item)
                Task { await browser.deleteSelectedToTrash() }
            }
            .disabled(!browser.canStartFileOperation)
            Button(L10n.text(.deletePermanently, for: browser.language)) {
                browser.select(item)
                Task { await browser.deleteSelectedPermanently() }
            }
            .disabled(!browser.canStartFileOperation)
            Divider()
            Button(L10n.text(.revealInFinder, for: browser.language)) {
                browser.select(item)
                browser.revealSelectedInFinder()
            }
            Button(L10n.text(.openCurrentFolderInTerminal, for: browser.language)) {
                browser.openCurrentDirectoryInTerminal()
            }
            Divider()
            Button(L10n.text(.copyPath, for: browser.language)) {
                browser.select(item)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
    }

    private var itemActivationGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first:
                    browser.requestFocus(.fileArea)
                    browser.select(item)
                    Task { await browser.open(item) }
                case .second:
                    selectWithCurrentModifiers()
                }
            }
    }

    private func selectWithCurrentModifiers() {
        let flags = NSEvent.modifierFlags
        browser.requestFocus(.fileArea)
        browser.select(
            item,
            extending: flags.contains(.shift),
            toggling: flags.contains(.command)
        )
    }

    private func makeDragItemProvider() -> NSItemProvider {
        let urls = browser.prepareDragSelection(for: item)
        return makeFileDragItemProvider(for: urls, fallbackURL: item.url)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard item.isDirectory,
              browser.canStartFileOperation,
              providers.contains(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        let shouldCopy = NSEvent.modifierFlags.contains(.option)
        Task {
            let urls = await loadDroppedFileURLs(from: providers)
            await browser.dropItems(urls, to: item.url, copy: shouldCopy)
        }
        return true
    }
}
