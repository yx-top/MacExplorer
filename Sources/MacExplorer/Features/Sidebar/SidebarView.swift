import SwiftUI
import UniformTypeIdentifiers

private let favoriteDirectoryDragType = UTType(exportedAs: "com.maceexplorer.favorite-directory")

struct SidebarView: View {
    @EnvironmentObject private var browser: BrowserStore
    @EnvironmentObject private var sidebar: SidebarStore
    @State private var draggedFavoriteURL: URL?
    @State private var dropTargetFavoriteURL: URL?
    @State private var isFavoriteImportDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(displayedSections) { section in
                    sidebarSection(section)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var displayedSections: [SidebarSection] {
        var sections = sidebar.sections
        let favoriteItems = browser.favoriteDirectories.map { url in
            SidebarItem(
                title: displayTitle(for: url),
                symbolName: "star.fill",
                url: url,
                role: .favorite
            )
        }
        let recentItems = browser.recentDirectories.filter { !browser.isFavoriteDirectory($0) }.map { url in
            SidebarItem(
                title: displayTitle(for: url),
                symbolName: "clock",
                url: url,
                role: .recent
            )
        }

        var insertedSections: [SidebarSection] = [
            SidebarSection(title: "Favorites", items: favoriteItems)
        ]
        if !recentItems.isEmpty {
            insertedSections.append(SidebarSection(title: "Recent", items: recentItems))
        }

        let insertionIndex = sections.firstIndex { $0.title == "Quick Access" }.map { $0 + 1 } ?? 0
        sections.insert(contentsOf: insertedSections, at: insertionIndex)
        return sections
    }

    private func displayTitle(for url: URL) -> String {
        let title = url.lastPathComponent
        return title.isEmpty ? url.path : title
    }

    @ViewBuilder
    private func sidebarSection(_ section: SidebarSection) -> some View {
        let isFavoritesSection = section.title == "Favorites"

        VStack(alignment: .leading, spacing: 5) {
            SidebarSectionHeader(section: section)

            if isFavoritesSection && section.items.isEmpty {
                FavoriteDropPlaceholder(isTargeted: isFavoriteImportDropTargeted)
            }

            ForEach(section.items) { item in
                SidebarRow(
                    item: item,
                    isSelected: browser.currentURL.standardizedFileURL == item.url.standardizedFileURL,
                    draggedFavoriteURL: $draggedFavoriteURL,
                    dropTargetFavoriteURL: $dropTargetFavoriteURL
                )
            }
        }
        .background(
            isFavoritesSection && isFavoriteImportDropTargeted ? AppTheme.selectedFill : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .onDrop(
            of: isFavoritesSection ? [UTType.fileURL] : [],
            isTargeted: isFavoritesSection ? $isFavoriteImportDropTargeted : .constant(false)
        ) { providers in
            guard isFavoritesSection,
                  providers.contains(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
                return false
            }

            Task {
                let urls = await droppedURLs(from: providers)
                await MainActor.run {
                    browser.addFavoriteDirectories(urls)
                }
            }
            return true
        }
    }

    private func droppedURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }

        return urls
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let nsURL = item as? NSURL {
                    continuation.resume(returning: nsURL as URL)
                } else if let data = item as? Data {
                    continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

private struct FavoriteDropPlaceholder: View {
    let isTargeted: Bool

    var body: some View {
        HStack {
            Image(systemName: isTargeted ? "star.fill" : "star")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.45))
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 28)
        .background(Color.primary.opacity(isTargeted ? 0.07 : 0.035), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isTargeted ? Color.accentColor.opacity(0.35) : AppTheme.subtleLine, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .padding(.horizontal, 8)
    }
}

private struct SidebarSectionHeader: View {
    @EnvironmentObject private var browser: BrowserStore
    let section: SidebarSection

    var body: some View {
        HStack(spacing: 6) {
            Text(L10n.sidebarTitle(section.title, for: browser.language).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if section.title == "Recent" {
                Button {
                    browser.clearRecentDirectories()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(L10n.text(.clearRecent, for: browser.language))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
    }
}

private struct SidebarRow: View {
    @EnvironmentObject private var browser: BrowserStore
    let item: SidebarItem
    let isSelected: Bool
    @Binding var draggedFavoriteURL: URL?
    @Binding var dropTargetFavoriteURL: URL?

    var body: some View {
        Group {
            if item.role == .favorite {
                rowButton
                    .onDrag {
                        draggedFavoriteURL = item.url

                        let provider = NSItemProvider()
                        provider.registerDataRepresentation(
                            forTypeIdentifier: favoriteDirectoryDragType.identifier,
                            visibility: .ownProcess
                        ) { completion in
                            completion(Data(item.url.path.utf8), nil)
                            return nil
                        }
                        return provider
                    }
                    .onDrop(
                        of: [favoriteDirectoryDragType],
                        delegate: FavoriteDirectoryDropDelegate(
                            targetURL: item.url,
                            draggedFavoriteURL: $draggedFavoriteURL,
                            dropTargetFavoriteURL: $dropTargetFavoriteURL,
                            browser: browser
                        )
                    )
            } else {
                rowButton
            }
        }
        .contextMenu {
            if item.role == .favorite {
                Button(L10n.text(.removeFromFavorites, for: browser.language)) {
                    browser.removeFavoriteDirectory(item.url)
                }

                Divider()

                Button(L10n.text(.moveUp, for: browser.language)) {
                    browser.moveFavoriteDirectory(item.url, by: -1)
                }
                .disabled(!browser.canMoveFavoriteDirectory(item.url, by: -1))

                Button(L10n.text(.moveDown, for: browser.language)) {
                    browser.moveFavoriteDirectory(item.url, by: 1)
                }
                .disabled(!browser.canMoveFavoriteDirectory(item.url, by: 1))
            } else {
                if browser.isFavoriteDirectory(item.url) {
                    Button(L10n.text(.removeFromFavorites, for: browser.language)) {
                        browser.removeFavoriteDirectory(item.url)
                    }
                } else {
                    Button(L10n.text(.addToFavorites, for: browser.language)) {
                        browser.addFavoriteDirectory(item.url)
                    }
                }
            }

            if item.role == .recent {
                if !browser.isFavoriteDirectory(item.url) {
                    Divider()
                }
                Button(L10n.text(.removeFromRecent, for: browser.language)) {
                    browser.removeRecentDirectory(item.url)
                }
            }
        }
    }

    private var rowButton: some View {
        Button {
            Task { await browser.navigate(to: item.url) }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 18)

                Text(L10n.sidebarTitle(item.title, for: browser.language))
                    .lineLimit(1)

                Spacer()

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(isSelected ? AppTheme.selectedFill : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                if isFavoriteDropTarget {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.22), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private var isFavoriteDropTarget: Bool {
        item.role == .favorite
            && dropTargetFavoriteURL?.standardizedFileURL == item.url.standardizedFileURL
            && draggedFavoriteURL?.standardizedFileURL != item.url.standardizedFileURL
    }
}

@MainActor
private struct FavoriteDirectoryDropDelegate: DropDelegate {
    let targetURL: URL
    @Binding var draggedFavoriteURL: URL?
    @Binding var dropTargetFavoriteURL: URL?
    let browser: BrowserStore

    func validateDrop(info: DropInfo) -> Bool {
        draggedFavoriteURL != nil
    }

    func dropEntered(info: DropInfo) {
        dropTargetFavoriteURL = targetURL

        guard let sourceURL = draggedFavoriteURL,
              sourceURL.standardizedFileURL != targetURL.standardizedFileURL else { return }

        withAnimation(.easeInOut(duration: 0.12)) {
            browser.moveFavoriteDirectory(sourceURL, to: targetURL)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetFavoriteURL?.standardizedFileURL == targetURL.standardizedFileURL {
            dropTargetFavoriteURL = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedFavoriteURL = nil
        dropTargetFavoriteURL = nil
        return true
    }
}
