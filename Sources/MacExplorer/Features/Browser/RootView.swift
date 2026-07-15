import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var browser: BrowserStore
    @StateObject private var sidebarStore = SidebarStore()
    @State private var sidebarWidth: CGFloat

    init() {
        let preferences = PreferencesStore()
        _sidebarWidth = State(
            initialValue: preferences.loadSidebarWidth(
                defaultValue: AppTheme.sidebarWidth,
                minValue: AppTheme.sidebarMinimumWidth,
                maxValue: AppTheme.sidebarMaximumWidth
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()
            ExplorerToolbar()
            AddressBarView()
            if browser.isSearchFilterBarVisible {
                SearchFilterBarView()
            }

            HStack(spacing: 0) {
                SidebarView()
                    .environmentObject(sidebarStore)
                    .frame(width: sidebarWidth)

                SidebarResizeHandle(width: $sidebarWidth) { width in
                    PreferencesStore().save(sidebarWidth: width)
                }

                BrowserContentView()
                    .frame(minWidth: AppTheme.minimumFileAreaWidth)

                if browser.isShowingDetailsPanel {
                    Divider()
                    DetailsPanelView()
                        .frame(minWidth: AppTheme.detailsPanelWidth, idealWidth: AppTheme.detailsPanelWidth, maxWidth: AppTheme.detailsPanelWidth)
                }
            }

            Divider()
            StatusBarView()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            WindowStateRestorer(autosaveName: "MacExplorer.BrowserWindow")
                .frame(width: 0, height: 0)
        }
        .task {
            await browser.reload()
            browser.requestFocus(.fileArea)
        }
    }
}

private struct SidebarResizeHandle: View {
    @Binding var width: CGFloat
    let onCommit: (CGFloat) -> Void
    @State private var dragStartWidth: CGFloat?
    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.subtleLine)
                .frame(width: 1)

            Rectangle()
                .fill((isHovering || isDragging) ? Color.accentColor.opacity(0.25) : Color.clear)
                .frame(width: 5)
        }
        .frame(width: 7)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = width
                        isDragging = true
                    }

                    let proposedWidth = (dragStartWidth ?? width) + value.translation.width
                    width = clamped(proposedWidth)
                }
                .onEnded { _ in
                    width = clamped(width)
                    onCommit(width)
                    dragStartWidth = nil
                    isDragging = false
                }
        )
    }

    private func clamped(_ proposedWidth: CGFloat) -> CGFloat {
        min(max(proposedWidth, AppTheme.sidebarMinimumWidth), AppTheme.sidebarMaximumWidth)
    }
}

private struct BrowserContentView: View {
    @EnvironmentObject private var browser: BrowserStore
    @State private var isDropTargeted = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if browser.viewMode == .details {
                    FileListView()
                } else {
                    FileGridView()
                }
            }

            if browser.isLoading || (browser.isSearching && browser.displayedItems.isEmpty) {
                ProgressView()
                    .controlSize(.large)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if let errorMessage = browser.errorMessage {
                ContentUnavailableView(
                    L10n.text(.cannotOpenFolder, for: browser.language),
                    systemImage: "lock.trianglebadge.exclamationmark",
                    description: Text(errorMessage)
                )
                .padding(40)
            } else if browser.displayedItems.isEmpty && !browser.isLoading && !browser.isSearching {
                ContentUnavailableView(
                    browser.isSearchActive ? L10n.text(.noResults, for: browser.language) : L10n.text(.emptyFolder, for: browser.language),
                    systemImage: browser.isSearchActive ? "magnifyingglass" : "folder",
                    description: Text(browser.isSearchActive ? L10n.text(.tryDifferentSearch, for: browser.language) : L10n.text(.noVisibleItems, for: browser.language))
                )
                .padding(40)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.delete) {
            guard browser.hasSelection, browser.canStartFileOperation else { return .ignored }
            Task { await browser.deleteSelectedToTrash() }
            return .handled
        }
        .onChange(of: browser.focusRequest) { _, request in
            guard let request else { return }
            switch request.target {
            case .fileArea:
                isFocused = true
            case .addressBar, .searchField:
                isFocused = false
            }
        }
        .onDrop(of: [macExplorerDraggedFileURLsType, UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            guard browser.canStartFileOperation else { return false }
            let shouldCopy = NSEvent.modifierFlags.contains(.option)
            Task {
                let urls = browser.resolveDroppedFileURLs(await loadDroppedFileURLs(from: providers))
                await browser.dropItems(urls, copy: shouldCopy)
            }
            return true
        }
        .contextMenu {
            Button(L10n.text(.newFolder, for: browser.language)) {
                Task { await browser.createFolderFromPrompt() }
            }
            .disabled(!browser.canStartFileOperation)
            Button(L10n.text(.newEmptyFile, for: browser.language)) {
                Task { await browser.createFileFromPrompt() }
            }
            .disabled(!browser.canStartFileOperation)
            Button(L10n.text(.paste, for: browser.language)) {
                Task { await browser.pasteItems() }
            }
            .disabled(!browser.canPaste)
            Divider()
            Button(L10n.text(.openInTerminal, for: browser.language)) {
                browser.openCurrentDirectoryInTerminal()
            }
            Button(L10n.text(.refresh, for: browser.language)) {
                Task { await browser.reload() }
            }
        }
    }
}
