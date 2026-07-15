import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileGridView: View {
    @EnvironmentObject private var browser: BrowserStore
    @State private var itemFrames: [FileItem.ID: CGRect] = [:]
    @State private var selectionDrag: FileSelectionDragState?
    @State private var ignoresSelectionDrag = false

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 132), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(browser.displayedItems) { item in
                    FileGridCell(item: item, isSelected: browser.selectedItemIDs.contains(item.id))
                }
            }
            .padding(16)
        }
        .coordinateSpace(name: fileSelectionCoordinateSpaceName)
        .onPreferenceChange(FileItemFramePreferenceKey.self) { frames in
            itemFrames = frames
        }
        .overlay {
            if let selectionDrag, selectionDrag.isSelectingRange {
                FileSelectionMarquee(rect: selectionDrag.selectionRect)
            }
        }
        .simultaneousGesture(fileSelectionGesture)
    }

    private var fileSelectionGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(fileSelectionCoordinateSpaceName))
            .onChanged { value in
                if selectionDrag == nil && !ignoresSelectionDrag {
                    if itemFrames.values.contains(where: { $0.contains(value.startLocation) }) {
                        ignoresSelectionDrag = true
                        return
                    }

                    browser.requestFocus(.fileArea)
                    selectionDrag = FileSelectionDragState(startLocation: value.startLocation, location: value.location)
                }

                guard var drag = selectionDrag else { return }
                drag.location = value.location
                selectionDrag = drag

                if drag.isSelectingRange {
                    browser.selectItems(withIDs: itemIDs(in: drag.selectionRect))
                }
            }
            .onEnded { value in
                defer {
                    selectionDrag = nil
                    ignoresSelectionDrag = false
                }

                guard var drag = selectionDrag else { return }
                drag.location = value.location

                if drag.isSelectingRange {
                    browser.selectItems(withIDs: itemIDs(in: drag.selectionRect))
                } else {
                    browser.clearSelectedItems()
                }
            }
    }

    private func itemIDs(in rect: CGRect) -> Set<FileItem.ID> {
        Set(itemFrames.compactMap { id, frame in
            frame.intersects(rect) ? id : nil
        })
    }
}

private struct FileGridCell: View {
    @EnvironmentObject private var browser: BrowserStore
    let item: FileItem
    let isSelected: Bool
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            FileIconView(url: item.url, size: 44)

            VStack(spacing: 3) {
                Text(browser.displayName(for: item))
                    .font(.system(size: 12))
                    .lineLimit(browser.isRecursiveSearchActive ? 1 : 2)
                    .multilineTextAlignment(.center)
                    .frame(height: browser.isRecursiveSearchActive ? 18 : 34, alignment: .top)

                if browser.isRecursiveSearchActive {
                    Label(browser.searchLocationDescription(for: item), systemImage: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .labelStyle(.titleAndIcon)
                        .frame(height: 15)
                        .help(browser.fullLocationPath(for: item))
                }
            }
        }
        .padding(8)
        .frame(width: 112, height: browser.isRecursiveSearchActive ? 122 : 104)
        .background(isSelected ? AppTheme.selectedFill : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if isDropTargeted && item.isDirectory {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }
        }
        .reportsFileItemFrame(id: item.id)
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
        let flags = InputEventTracker.selectionModifierFlags
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
            let urls = browser.resolveDroppedFileURLs(await loadDroppedFileURLs(from: providers))
            await browser.dropItems(urls, to: item.url, copy: shouldCopy)
        }
        return true
    }
}
