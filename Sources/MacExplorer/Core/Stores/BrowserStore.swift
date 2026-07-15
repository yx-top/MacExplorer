import AppKit
import Combine
import Foundation

@MainActor
final class BrowserStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab]
    @Published var selectedTabID: BrowserTab.ID
    @Published private(set) var items: [FileItem] = []
    @Published private(set) var searchResults: [FileItem] = []
    @Published private(set) var scannedSearchItemCount = 0
    @Published private(set) var skippedSearchDirectoryCount = 0
    @Published private(set) var isSearchResultLimited = false
    @Published var selectedItemIDs: Set<FileItem.ID> = []
    @Published var viewMode: ExplorerViewMode = .details {
        didSet {
            guard !isApplyingDirectoryPreferences else { return }
            preferences.save(viewMode: viewMode)
            preferences.save(viewMode: viewMode, for: currentURL)
        }
    }
    @Published var sort = FileSort() {
        didSet {
            guard !isApplyingDirectoryPreferences else { return }
            preferences.save(sort: sort)
            preferences.save(sort: sort, for: currentURL)
        }
    }
    @Published var showHiddenFiles = false {
        didSet {
            preferences.save(showHiddenFiles: showHiddenFiles)
            Task { await reload() }
        }
    }
    @Published var showFileExtensions = true {
        didSet { preferences.save(showFileExtensions: showFileExtensions) }
    }
    @Published private(set) var searchQuery = ""
    @Published var searchFilters = SearchFilters() {
        didSet {
            guard oldValue != searchFilters else { return }
            clearSelection()
            scheduleSearchIfNeeded()
        }
    }
    @Published var searchScope: SearchScope = .currentFolder {
        didSet {
            guard oldValue != searchScope else { return }
            preferences.save(searchScope: searchScope)
            clearSelection()
            scheduleSearchIfNeeded()
        }
    }
    @Published var language: AppLanguage = .chinese {
        didSet {
            guard oldValue != language else { return }
            preferences.save(language: language)
            Task { await refreshAfterLanguageChange() }
        }
    }
    @Published var isShowingSearchFilters = false
    @Published var isShowingDetailsPanel = true {
        didSet { preferences.save(detailsPanelVisible: isShowingDetailsPanel) }
    }
    @Published private(set) var isLoading = false
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var operationMessage: String?
    @Published private(set) var activeOperation: FileOperationTask?
    @Published private(set) var operationHistory: [FileOperationTask] = []
    @Published private(set) var focusRequest: BrowserFocusRequest?
    @Published private(set) var recentDirectories: [URL] = []
    @Published private(set) var favoriteDirectories: [URL] = []

    private let fileSystem: FileSystemService
    private let searchService: SearchService
    private let fileOperations = FileOperationService()
    private let quickLookService = QuickLookService()
    private let directoryMonitor = DirectoryMonitor()
    private let preferences = PreferencesStore()
    private var fileClipboard: FileClipboard?
    private var loadRequestID = UUID()
    private var searchTask: Task<Void, Never>?
    private var searchRequestID = UUID()
    private var monitorReloadTask: Task<Void, Never>?
    private var activeTransferTask: Task<[URL], Error>?
    private var lastSelectedItemID: FileItem.ID?
    private var isApplyingDirectoryPreferences = false
    private let recentDirectoryLimit = 5
    private let favoriteDirectoryLimit = 30

    init(fileSystem: FileSystemService = FileSystemService(), searchService: SearchService = SearchService()) {
        self.fileSystem = fileSystem
        self.searchService = searchService
        self.viewMode = preferences.loadViewMode()
        self.sort = preferences.loadSort()
        self.showHiddenFiles = preferences.loadShowHiddenFiles()
        self.showFileExtensions = preferences.loadShowFileExtensions()
        self.searchScope = preferences.loadSearchScope()
        self.language = preferences.loadLanguage()
        self.isShowingDetailsPanel = preferences.loadDetailsPanelVisibility()
        self.recentDirectories = preferences.loadRecentDirectories()
        self.favoriteDirectories = preferences.loadFavoriteDirectories()

        let restoredURLs = preferences.loadTabs()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let restoredTabs = restoredURLs.isEmpty
            ? [BrowserTab(currentURL: home)]
            : restoredURLs.map { BrowserTab(currentURL: $0) }
        self.tabs = restoredTabs

        if let selectedPath = preferences.loadSelectedTabPath(),
           let selectedTab = restoredTabs.first(where: { $0.currentURL.path == selectedPath }) {
            self.selectedTabID = selectedTab.id
        } else {
            self.selectedTabID = restoredTabs[0].id
        }
    }

    var currentURL: URL {
        selectedTab?.currentURL ?? FileManager.default.homeDirectoryForCurrentUser
    }

    var displayedItems: [FileItem] {
        if isRecursiveSearchActive {
            return searchResults
        }

        return items.filter {
            matchesSearchText($0) && searchFilters.matches($0)
        }
    }

    var selectedItems: [FileItem] {
        displayedItems.filter { selectedItemIDs.contains($0.id) }
    }

    var canGoBack: Bool {
        !(selectedTab?.backStack.isEmpty ?? true)
    }

    var canGoForward: Bool {
        !(selectedTab?.forwardStack.isEmpty ?? true)
    }

    var hasSelection: Bool {
        !selectedItemIDs.isEmpty
    }

    var hasDisplayedItems: Bool {
        !displayedItems.isEmpty
    }

    var canPaste: Bool {
        canStartFileOperation && (fileClipboard?.urls.isEmpty == false || !pasteboardURLs().isEmpty)
    }

    var canCloseSelectedTab: Bool {
        canCloseTab(selectedTabID)
    }

    var canStartFileOperation: Bool {
        activeTransferTask == nil && activeOperation?.state != .running
    }

    var canCancelActiveOperation: Bool {
        activeTransferTask != nil
            && activeOperation?.state == .running
            && activeOperation?.kind.supportsCancellation == true
    }

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedTabID }
    }

    var isRecursiveSearchActive: Bool {
        searchScope == .recursive && isSearchActive
    }

    var isSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || searchFilters.isActive
    }

    var isSearchFilterBarVisible: Bool {
        isShowingSearchFilters || searchFilters.isActive
    }

    var searchResultLimit: Int {
        SearchService.defaultResultLimit
    }

    var isCurrentDirectoryFavorite: Bool {
        isFavoriteDirectory(currentURL)
    }

    func createTab(url: URL? = nil) {
        let tabURL = url ?? currentURL
        let tab = BrowserTab(currentURL: tabURL)
        tabs.append(tab)
        selectedTabID = tab.id
        persistTabs()
        Task { await load(url: tabURL, tabID: tab.id, updatingHistory: false) }
    }

    func duplicateSelectedTab() {
        duplicateTab(selectedTabID)
    }

    func duplicateTab(_ id: BrowserTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let source = tabs[index]
        let duplicate = BrowserTab(
            currentURL: source.currentURL,
            backStack: source.backStack,
            forwardStack: source.forwardStack
        )
        tabs.insert(duplicate, at: index + 1)
        selectedTabID = duplicate.id
        persistTabs()
        Task { await load(url: duplicate.currentURL, tabID: duplicate.id, updatingHistory: false) }
    }

    func closeSelectedTab() {
        closeTab(selectedTabID)
    }

    func closeTab(_ id: BrowserTab.ID) {
        guard canCloseTab(id),
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let shouldReload = selectedTabID == id
        tabs.remove(at: index)
        if shouldReload {
            clearSearchForLocationChange()
            selectedTabID = tabs[min(index, tabs.count - 1)].id
        }
        persistTabs()
        if shouldReload {
            let tabID = selectedTabID
            let url = currentURL
            Task { await load(url: url, tabID: tabID, updatingHistory: false) }
        }
    }

    func closeOtherTabs(keeping id: BrowserTab.ID) {
        guard tabs.count > 1,
              let keptTab = tabs.first(where: { $0.id == id }) else { return }

        let shouldReload = selectedTabID != id
        tabs = [keptTab]
        if shouldReload {
            clearSearchForLocationChange()
        }
        selectedTabID = id
        persistTabs()
        if shouldReload {
            Task { await load(url: keptTab.currentURL, tabID: id, updatingHistory: false) }
        }
    }

    func closeTabsToRight(of id: BrowserTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }),
              index < tabs.count - 1 else { return }

        let keptTabs = Array(tabs.prefix(index + 1))
        let shouldReload = !keptTabs.contains { $0.id == selectedTabID }
        tabs = keptTabs
        if shouldReload {
            clearSearchForLocationChange()
            selectedTabID = id
        }
        persistTabs()
        if shouldReload {
            let tabID = selectedTabID
            let url = currentURL
            Task { await load(url: url, tabID: tabID, updatingHistory: false) }
        }
    }

    func canCloseTab(_ id: BrowserTab.ID) -> Bool {
        tabs.count > 1 && tabs.contains { $0.id == id }
    }

    func canCloseOtherTabs(keeping id: BrowserTab.ID) -> Bool {
        tabs.count > 1 && tabs.contains { $0.id == id }
    }

    func canCloseTabsToRight(of id: BrowserTab.ID) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        return index < tabs.count - 1
    }

    func selectTab(_ id: BrowserTab.ID) {
        guard selectedTabID != id,
              let tab = tabs.first(where: { $0.id == id }) else { return }
        clearSearchForLocationChange()
        selectedTabID = id
        persistTabs()
        Task { await load(url: tab.currentURL, tabID: id, updatingHistory: false) }
    }

    func moveTab(_ sourceID: BrowserTab.ID, to targetID: BrowserTab.ID) {
        guard sourceID != targetID,
              let sourceIndex = tabs.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = tabs.firstIndex(where: { $0.id == targetID }) else { return }

        let tab = tabs.remove(at: sourceIndex)
        tabs.insert(tab, at: targetIndex)
        persistTabs()
    }

    func reload() async {
        await load(url: currentURL, tabID: selectedTabID, updatingHistory: false)
    }

    func navigate(to url: URL) async {
        if url.standardizedFileURL != currentURL.standardizedFileURL {
            clearSearchForLocationChange()
        }
        await load(url: url, tabID: selectedTabID, updatingHistory: true)
    }

    func open(_ item: FileItem) async {
        if item.isDirectory {
            await navigate(to: item.url)
        } else {
            fileOperations.open(item.url)
        }
    }

    func goBack() async {
        guard let index = selectedTabIndex, let previous = tabs[index].backStack.popLast() else { return }
        let tabID = tabs[index].id
        clearSearchForLocationChange()
        tabs[index].forwardStack.append(tabs[index].currentURL)
        tabs[index].currentURL = previous
        await load(url: previous, tabID: tabID, updatingHistory: false)
    }

    func goForward() async {
        guard let index = selectedTabIndex, let next = tabs[index].forwardStack.popLast() else { return }
        let tabID = tabs[index].id
        clearSearchForLocationChange()
        tabs[index].backStack.append(tabs[index].currentURL)
        tabs[index].currentURL = next
        await load(url: next, tabID: tabID, updatingHistory: false)
    }

    func goUp() async {
        let parent = currentURL.deletingLastPathComponent()
        guard parent.path != currentURL.path else { return }
        await navigate(to: parent)
    }

    func toggleSort(_ field: FileSortField) {
        if sort.field == field {
            sort.direction.toggle()
        } else {
            sort.field = field
            sort.direction = .ascending
        }

        refreshAfterSortChange()
    }

    func updateSortField(_ field: FileSortField) {
        guard sort.field != field else { return }
        sort.field = field
        sort.direction = .ascending
        refreshAfterSortChange()
    }

    func updateSortDirection(_ direction: SortDirection) {
        guard sort.direction != direction else { return }
        sort.direction = direction
        refreshAfterSortChange()
    }

    func updateFoldersFirst(_ foldersFirst: Bool) {
        guard sort.foldersFirst != foldersFirst else { return }
        sort.foldersFirst = foldersFirst
        refreshAfterSortChange()
    }

    private func refreshAfterSortChange() {
        if isRecursiveSearchActive {
            scheduleSearchIfNeeded()
        } else {
            Task { await reload() }
        }
    }

    func select(_ item: FileItem) {
        selectedItemIDs = [item.id]
        lastSelectedItemID = item.id
    }

    func select(_ item: FileItem, extending: Bool, toggling: Bool) {
        if extending, let lastSelectedItemID,
           let lastIndex = displayedItems.firstIndex(where: { $0.id == lastSelectedItemID }),
           let currentIndex = displayedItems.firstIndex(where: { $0.id == item.id }) {
            let bounds = min(lastIndex, currentIndex)...max(lastIndex, currentIndex)
            selectedItemIDs = Set(displayedItems[bounds].map(\.id))
            return
        }

        if toggling {
            if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
            } else {
                selectedItemIDs.insert(item.id)
            }
            lastSelectedItemID = item.id
            return
        }

        select(item)
    }

    func selectAll() {
        selectedItemIDs = Set(displayedItems.map(\.id))
        lastSelectedItemID = displayedItems.last?.id
    }

    func moveSelection(by offset: Int, extending: Bool = false) {
        guard !displayedItems.isEmpty else { return }

        let currentIndex = selectionAnchorIndex ?? (offset >= 0 ? -1 : displayedItems.count)
        let nextIndex = min(max(currentIndex + offset, 0), displayedItems.count - 1)
        let nextItem = displayedItems[nextIndex]

        if extending,
           let anchor = lastSelectedItemID,
           let anchorIndex = displayedItems.firstIndex(where: { $0.id == anchor }) {
            let bounds = min(anchorIndex, nextIndex)...max(anchorIndex, nextIndex)
            selectedItemIDs = Set(displayedItems[bounds].map(\.id))
        } else {
            select(nextItem)
        }
    }

    func openSelectedItems() async {
        guard selectedItems.count == 1, let item = selectedItems.first else { return }
        await open(item)
    }

    func openSelectedWithApplicationFromPrompt() async {
        guard selectedItems.count == 1,
              let item = selectedItems.first,
              let applicationURL = UserPromptService.chooseApplication(language: language) else { return }

        do {
            try await fileOperations.open(item.url, withApplicationAt: applicationURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearOperationHistory() {
        operationHistory.removeAll()
    }

    func clearRecentDirectories() {
        recentDirectories.removeAll()
        preferences.save(recentDirectories: recentDirectories)
    }

    func removeRecentDirectory(_ url: URL) {
        recentDirectories.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        preferences.save(recentDirectories: recentDirectories)
    }

    func toggleCurrentDirectoryFavorite() {
        if isCurrentDirectoryFavorite {
            removeFavoriteDirectory(currentURL)
        } else {
            addFavoriteDirectory(currentURL)
        }
    }

    func addFavoriteDirectory(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        favoriteDirectories.removeAll { $0.standardizedFileURL == standardizedURL }
        favoriteDirectories.insert(standardizedURL, at: 0)

        if favoriteDirectories.count > favoriteDirectoryLimit {
            favoriteDirectories.removeLast(favoriteDirectories.count - favoriteDirectoryLimit)
        }

        preferences.save(favoriteDirectories: favoriteDirectories)
        operationMessage = L10n.addedToFavorites(displayName(for: standardizedURL), for: language)
    }

    func addFavoriteDirectories(_ urls: [URL]) {
        var seenPaths: Set<String> = []
        let directories = urls.compactMap { url -> URL? in
            let standardizedURL = url.standardizedFileURL
            guard Self.isExistingDirectory(standardizedURL),
                  seenPaths.insert(standardizedURL.path).inserted else {
                return nil
            }
            return standardizedURL
        }

        guard !directories.isEmpty else { return }

        for url in directories.reversed() {
            addFavoriteDirectory(url)
        }
    }

    func removeFavoriteDirectory(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        favoriteDirectories.removeAll { $0.standardizedFileURL == standardizedURL }
        preferences.save(favoriteDirectories: favoriteDirectories)
        operationMessage = L10n.removedFromFavorites(displayName(for: standardizedURL), for: language)
    }

    func moveFavoriteDirectory(_ sourceURL: URL, to targetURL: URL) {
        let source = sourceURL.standardizedFileURL
        let target = targetURL.standardizedFileURL
        guard source != target,
              let sourceIndex = favoriteDirectories.firstIndex(where: { $0.standardizedFileURL == source }),
              let targetIndex = favoriteDirectories.firstIndex(where: { $0.standardizedFileURL == target }) else { return }

        let favorite = favoriteDirectories.remove(at: sourceIndex)
        favoriteDirectories.insert(favorite, at: targetIndex)
        preferences.save(favoriteDirectories: favoriteDirectories)
    }

    func moveFavoriteDirectory(_ url: URL, by offset: Int) {
        let standardizedURL = url.standardizedFileURL
        guard let sourceIndex = favoriteDirectories.firstIndex(where: { $0.standardizedFileURL == standardizedURL }) else { return }

        let targetIndex = sourceIndex + offset
        guard favoriteDirectories.indices.contains(targetIndex) else { return }

        let favorite = favoriteDirectories.remove(at: sourceIndex)
        favoriteDirectories.insert(favorite, at: targetIndex)
        preferences.save(favoriteDirectories: favoriteDirectories)
    }

    func canMoveFavoriteDirectory(_ url: URL, by offset: Int) -> Bool {
        let standardizedURL = url.standardizedFileURL
        guard let sourceIndex = favoriteDirectories.firstIndex(where: { $0.standardizedFileURL == standardizedURL }) else {
            return false
        }

        return favoriteDirectories.indices.contains(sourceIndex + offset)
    }

    func isFavoriteDirectory(_ url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        return favoriteDirectories.contains { $0.standardizedFileURL == standardizedURL }
    }

    func displayName(for item: FileItem) -> String {
        item.displayName(showFileExtensions: showFileExtensions)
    }

    func searchLocationDescription(for item: FileItem) -> String {
        let parentURL = item.url.deletingLastPathComponent().standardizedFileURL
        let rootURL = currentURL.standardizedFileURL

        if parentURL.path == rootURL.path {
            return L10n.text(.currentFolder, for: language)
        }

        let rootPrefix = rootURL.path == "/" ? "/" : rootURL.path + "/"
        if parentURL.path.hasPrefix(rootPrefix) {
            let relativePath = String(parentURL.path.dropFirst(rootPrefix.count))
            if !relativePath.isEmpty {
                return relativePath
            }
        }

        return (parentURL.path as NSString).abbreviatingWithTildeInPath
    }

    func fullLocationPath(for item: FileItem) -> String {
        let parentPath = item.url.deletingLastPathComponent().path
        return (parentPath as NSString).abbreviatingWithTildeInPath
    }

    func clearCompletedOperations() {
        operationHistory.removeAll { $0.state.isTerminal }
    }

    func cancelActiveOperation() {
        guard canCancelActiveOperation else { return }
        activeTransferTask?.cancel()
        markActiveOperationCanceled()
    }

    func revealSelectedInFinder() {
        guard let item = selectedItems.first else { return }
        fileOperations.revealInFinder(item.url)
    }

    func openCurrentDirectoryInTerminal() {
        fileOperations.openInTerminal(currentURL)
    }

    func previewSelectedItems() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        quickLookService.show(urls: urls)
    }

    func updateSearchQuery(_ query: String) {
        guard searchQuery != query else { return }
        searchQuery = query
        clearSelection()
        scheduleSearchIfNeeded()
    }

    func cancelSearch() {
        cancelSearchTask(clearResults: true)
        searchQuery = ""
        if searchFilters != SearchFilters() {
            searchFilters = SearchFilters()
        }
        clearSelection()
    }

    func resetSearchFilters() {
        if searchFilters != SearchFilters() {
            searchFilters = SearchFilters()
        }
    }

    func requestFocus(_ target: BrowserFocusTarget) {
        focusRequest = BrowserFocusRequest(target: target)
    }

    func createFolderFromPrompt() async {
        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        let location = currentURL.lastPathComponent.isEmpty ? currentURL.path : currentURL.lastPathComponent
        guard let name = UserPromptService.requestString(
            title: L10n.text(.newFolder, for: language),
            message: L10n.createFolderMessage(in: location, for: language),
            placeholder: L10n.text(.folderName, for: language),
            initialValue: L10n.text(.newFolder, for: language),
            confirmButton: L10n.text(.create, for: language),
            cancelButton: L10n.text(.cancel, for: language)
        ) else { return }

        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        do {
            startOperation(kind: .create, totalItems: 1, currentItemName: name)
            let folder = try fileOperations.createFolder(named: name, in: currentURL)
            finishOperation(message: L10n.created(folder.lastPathComponent, for: language))
            await reload()
            selectedItemIDs = [folder]
        } catch {
            failOperation(error)
        }
    }

    func createFileFromPrompt() async {
        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        let location = currentURL.lastPathComponent.isEmpty ? currentURL.path : currentURL.lastPathComponent
        guard let name = UserPromptService.requestString(
            title: L10n.text(.newFile, for: language),
            message: L10n.createFileMessage(in: location, for: language),
            placeholder: L10n.text(.fileName, for: language),
            initialValue: L10n.text(.untitledFileName, for: language),
            confirmButton: L10n.text(.create, for: language),
            cancelButton: L10n.text(.cancel, for: language)
        ) else { return }

        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        do {
            startOperation(kind: .create, totalItems: 1, currentItemName: name)
            let file = try fileOperations.createEmptyFile(named: name, in: currentURL)
            finishOperation(message: L10n.created(file.lastPathComponent, for: language))
            await reload()
            selectedItemIDs = [file]
        } catch {
            failOperation(error)
        }
    }

    func renameSelectedFromPrompt() async {
        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        guard let item = selectedItems.first else { return }
        guard let name = UserPromptService.requestString(
            title: L10n.text(.rename, for: language),
            message: L10n.renameMessage(itemName: item.displayName, for: language),
            placeholder: L10n.text(.name, for: language),
            initialValue: item.displayName,
            confirmButton: L10n.text(.rename, for: language),
            cancelButton: L10n.text(.cancel, for: language)
        ) else { return }

        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        do {
            startOperation(kind: .rename, totalItems: 1, currentItemName: item.displayName)
            let renamed = try fileOperations.rename(item.url, to: name)
            finishOperation(message: L10n.renamed(to: renamed.lastPathComponent, for: language))
            await reload()
            selectedItemIDs = [renamed]
        } catch {
            failOperation(error)
        }
    }

    func copySelectedItems() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        fileClipboard = FileClipboard(urls: urls, operation: .copy)
        writeURLsToPasteboard(urls)
        operationMessage = L10n.copied(urls: urls, for: language)
    }

    func cutSelectedItems() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        fileClipboard = FileClipboard(urls: urls, operation: .cut)
        writeURLsToPasteboard(urls)
        operationMessage = L10n.cut(urls: urls, for: language)
    }

    func pasteItems() async {
        let clipboard = fileClipboard
        let urls = clipboard?.urls.isEmpty == false ? clipboard?.urls ?? [] : pasteboardURLs()
        guard !urls.isEmpty else { return }

        await transferItems(urls, operation: clipboard?.operation == .cut ? .cut : .copy)

        if clipboard?.operation == .cut {
            fileClipboard = nil
        }
    }

    func dropItems(_ urls: [URL], copy: Bool) async {
        await dropItems(urls, to: currentURL, copy: copy)
    }

    func dropItems(_ urls: [URL], to directory: URL, copy: Bool) async {
        await transferItems(urls, to: directory, operation: copy ? .copy : .cut)
    }

    private func transferItems(_ urls: [URL], to directory: URL? = nil, operation: FileClipboardOperation) async {
        guard !urls.isEmpty else { return }

        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        let destinationDirectory = directory ?? currentURL
        let conflicts = conflictingURLs(for: urls, in: destinationDirectory)
        let conflictResolution: FileConflictResolution
        if conflicts.isEmpty {
            conflictResolution = .keepBoth
        } else if let choice = UserPromptService.chooseConflictResolution(conflictCount: conflicts.count, language: language) {
            conflictResolution = choice
        } else {
            return
        }

        do {
            let task: Task<[URL], Error>
            if operation == .cut {
                startOperation(kind: .move, totalItems: urls.count, currentItemName: urls.first?.lastPathComponent)
                task = Task { [fileOperations, destinationDirectory] in
                    try await fileOperations.moveItems(
                        urls,
                        to: destinationDirectory,
                        conflictResolution: conflictResolution
                    ) { [weak self] progress in
                        await self?.updateOperation(progress)
                    }
                }
            } else {
                startOperation(kind: .copy, totalItems: urls.count, currentItemName: urls.first?.lastPathComponent)
                task = Task { [fileOperations, destinationDirectory] in
                    try await fileOperations.copyItems(
                        urls,
                        to: destinationDirectory,
                        conflictResolution: conflictResolution
                    ) { [weak self] progress in
                        await self?.updateOperation(progress)
                    }
                }
            }

            activeTransferTask = task
            let destinations = try await task.value
            activeTransferTask = nil

            if activeOperation?.state != .canceled {
                finishOperation(message: L10n.pasted(urls: destinations, for: language))
            }
            await reload()
            selectedItemIDs = destinationDirectory.standardizedFileURL == currentURL.standardizedFileURL
                ? Set(destinations)
                : []
        } catch is CancellationError {
            activeTransferTask = nil
            markActiveOperationCanceled()
        } catch {
            activeTransferTask = nil
            failOperation(error)
        }
    }

    func deleteSelectedToTrash() async {
        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }

        guard UserPromptService.confirmDestructive(
            title: L10n.text(.moveToTrash, for: language),
            message: L10n.trashConfirmation(urls: urls, for: language),
            confirmButton: L10n.text(.moveToTrash, for: language),
            cancelButton: L10n.text(.cancel, for: language)
        ) else { return }

        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        do {
            startOperation(kind: .trash, totalItems: urls.count, currentItemName: urls.first?.lastPathComponent)
            try await fileOperations.moveToTrash(urls)
            finishOperation(message: L10n.movedToTrash(count: urls.count, for: language))
            await reload()
        } catch {
            failOperation(error)
        }
    }

    func deleteSelectedPermanently() async {
        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }

        guard UserPromptService.confirmDestructive(
            title: L10n.text(.deletePermanently, for: language),
            message: L10n.permanentDeleteConfirmation(urls: urls, for: language),
            confirmButton: L10n.text(.deletePermanently, for: language),
            cancelButton: L10n.text(.cancel, for: language)
        ) else { return }

        guard canStartFileOperation else {
            showFileOperationBusyMessage()
            return
        }

        do {
            startOperation(kind: .delete, totalItems: urls.count, currentItemName: urls.first?.lastPathComponent)
            let task = Task { [fileOperations] in
                try await fileOperations.permanentlyDelete(urls) { [weak self] progress in
                    await self?.updateOperation(progress)
                }
            }
            activeTransferTask = task
            let deletedURLs = try await task.value
            activeTransferTask = nil

            if activeOperation?.state != .canceled {
                finishOperation(message: L10n.deletedPermanently(count: deletedURLs.count, for: language))
            }
            await reload()
        } catch is CancellationError {
            activeTransferTask = nil
            markActiveOperationCanceled()
            await reload()
        } catch {
            activeTransferTask = nil
            failOperation(error)
            await reload()
        }
    }

    private func load(url: URL, tabID: BrowserTab.ID, updatingHistory: Bool) async {
        guard selectedTabID == tabID,
              tabIndex(for: tabID) != nil else { return }

        applyDirectoryPreferences(for: url)

        let requestID = UUID()
        loadRequestID = requestID

        cancelSearchTask(clearResults: true)
        isLoading = true
        errorMessage = nil
        clearSelection()

        do {
            let loadedItems = try await fileSystem.contents(of: url, showHidden: showHiddenFiles, sort: sort, language: language)
            guard canApplyLoad(requestID: requestID, tabID: tabID),
                  let index = tabIndex(for: tabID) else { return }

            if updatingHistory, tabs[index].currentURL != url {
                tabs[index].backStack.append(tabs[index].currentURL)
                tabs[index].forwardStack.removeAll()
            }

            tabs[index].currentURL = url
            persistTabs()
            items = loadedItems
            recordRecentDirectory(url)
            startMonitoring(url)
            scheduleSearchIfNeeded()
        } catch {
            guard canApplyLoad(requestID: requestID, tabID: tabID) else { return }
            errorMessage = error.localizedDescription
            items = []
            directoryMonitor.stop()
        }

        isLoading = false
    }

    private var selectedTabIndex: Int? {
        tabIndex(for: selectedTabID)
    }

    private func tabIndex(for id: BrowserTab.ID) -> Int? {
        tabs.firstIndex { $0.id == id }
    }

    private func canApplyLoad(requestID: UUID, tabID: BrowserTab.ID) -> Bool {
        loadRequestID == requestID && selectedTabID == tabID && tabIndex(for: tabID) != nil
    }

    private var selectionAnchorIndex: Int? {
        if let lastSelectedItemID,
           let index = displayedItems.firstIndex(where: { $0.id == lastSelectedItemID }) {
            return index
        }

        guard let firstSelection = selectedItemIDs.first else { return nil }
        return displayedItems.firstIndex { $0.id == firstSelection }
    }

    private func clearSelection() {
        selectedItemIDs.removeAll()
        lastSelectedItemID = nil
    }

    private func clearSearchForLocationChange() {
        guard isSearchActive else { return }
        cancelSearch()
    }

    nonisolated private static func isExistingDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private func persistTabs() {
        preferences.save(tabs: tabs)
        preferences.save(selectedTabURL: currentURL)
    }

    private func recordRecentDirectory(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        recentDirectories.removeAll { $0.standardizedFileURL == standardizedURL }
        recentDirectories.insert(standardizedURL, at: 0)

        if recentDirectories.count > recentDirectoryLimit {
            recentDirectories.removeLast(recentDirectories.count - recentDirectoryLimit)
        }

        preferences.save(recentDirectories: recentDirectories)
    }

    private func displayName(for url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    private func refreshAfterLanguageChange() async {
        await reload()
        if isRecursiveSearchActive {
            scheduleSearchIfNeeded()
        }
    }

    private func applyDirectoryPreferences(for url: URL) {
        let directoryViewMode = preferences.loadViewMode(for: url) ?? preferences.loadViewMode()
        let directorySort = preferences.loadSort(for: url) ?? preferences.loadSort()

        isApplyingDirectoryPreferences = true
        viewMode = directoryViewMode
        sort = directorySort
        isApplyingDirectoryPreferences = false
    }

    private func conflictingURLs(for urls: [URL], in directory: URL) -> [URL] {
        urls.filter { source in
            let destination = directory.appendingPathComponent(source.lastPathComponent, isDirectory: source.hasDirectoryPath)
            return destination.standardizedFileURL != source.standardizedFileURL
                && FileManager.default.fileExists(atPath: destination.path)
        }
    }

    private func startOperation(kind: FileOperationKind, totalItems: Int, currentItemName: String?) {
        let operation = FileOperationTask(kind: kind, totalItems: totalItems, currentItemName: currentItemName)
        activeOperation = operation
        recordOperation(operation)
        operationMessage = nil
        errorMessage = nil
    }

    private func showFileOperationBusyMessage() {
        operationMessage = L10n.text(.anotherFileOperationRunning, for: language)
    }

    private func updateOperation(_ progress: FileOperationProgress) {
        guard var operation = activeOperation else { return }
        guard operation.state == .running else { return }
        operation.totalItems = max(progress.totalItems, 1)
        operation.completedItems = progress.completedItems
        operation.currentItemName = progress.currentItemName
        operation.state = .running
        operation.updatedAt = Date()
        activeOperation = operation
        recordOperation(operation)
    }

    private func finishOperation(message: String) {
        if var operation = activeOperation {
            operation.completedItems = operation.totalItems
            operation.currentItemName = nil
            operation.state = .finished
            operation.updatedAt = Date()
            activeOperation = operation
            recordOperation(operation)

            let completedOperationID = operation.id
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if activeOperation?.id == completedOperationID,
                   activeOperation?.state == .finished {
                    activeOperation = nil
                }
            }
        }
        operationMessage = message
    }

    private func failOperation(_ error: Error) {
        let message = operationErrorMessage(for: error)

        if var operation = activeOperation {
            operation.state = .failed
            operation.errorMessage = message
            operation.updatedAt = Date()
            activeOperation = operation
            recordOperation(operation)
        }
        errorMessage = message
        operationMessage = nil
    }

    private func operationErrorMessage(for error: Error) -> String {
        if let fileOperationError = error as? FileOperationServiceError {
            return fileOperationError.message(for: language)
        }

        return error.localizedDescription
    }

    private func markActiveOperationCanceled() {
        if var operation = activeOperation {
            operation.currentItemName = nil
            operation.state = .canceled
            operation.updatedAt = Date()
            activeOperation = operation
            recordOperation(operation)

            let canceledOperationID = operation.id
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if activeOperation?.id == canceledOperationID,
                   activeOperation?.state == .canceled {
                    activeOperation = nil
                }
            }
        }
        operationMessage = L10n.text(.operationCanceled, for: language)
    }

    private func recordOperation(_ operation: FileOperationTask) {
        if let index = operationHistory.firstIndex(where: { $0.id == operation.id }) {
            operationHistory[index] = operation
        } else {
            operationHistory.insert(operation, at: 0)
        }

        if operationHistory.count > 50 {
            operationHistory.removeLast(operationHistory.count - 50)
        }
    }

    private func startMonitoring(_ url: URL) {
        directoryMonitor.startMonitoring(url: url) { [weak self] in
            self?.scheduleMonitorReload()
        }
    }

    private func scheduleMonitorReload() {
        monitorReloadTask?.cancel()
        monitorReloadTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    private func scheduleSearchIfNeeded() {
        searchTask?.cancel()
        searchTask = nil
        searchResults = []
        scannedSearchItemCount = 0
        skippedSearchDirectoryCount = 0
        isSearchResultLimited = false

        guard isRecursiveSearchActive else {
            searchRequestID = UUID()
            isSearching = false
            return
        }

        let requestID = UUID()
        searchRequestID = requestID
        let query = searchQuery
        let rootURL = currentURL
        let showHidden = showHiddenFiles
        let sort = sort
        let filters = searchFilters
        let language = language
        let resultLimit = searchResultLimit

        isSearching = true
        searchTask = Task { [searchService] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
                for try await progress in searchService.searchProgress(
                    in: rootURL,
                    query: query,
                    filters: filters,
                    showHidden: showHidden,
                    sort: sort,
                    language: language,
                    resultLimit: resultLimit
                ) {
                    guard !Task.isCancelled, searchRequestID == requestID else { return }
                    searchResults = progress.items
                    scannedSearchItemCount = progress.scannedItemCount
                    skippedSearchDirectoryCount = progress.skippedDirectoryCount
                    isSearchResultLimited = progress.isLimited
                }

                guard !Task.isCancelled, searchRequestID == requestID else { return }
                isSearching = false
                searchTask = nil
            } catch is CancellationError {
                guard searchRequestID == requestID else { return }
                isSearching = false
                searchTask = nil
            } catch {
                guard searchRequestID == requestID else { return }
                errorMessage = error.localizedDescription
                isSearching = false
                searchTask = nil
            }
        }
    }

    private func matchesSearchText(_ item: FileItem) -> Bool {
        SearchMatcher.matches(item, query: searchQuery)
    }

    private func cancelSearchTask(clearResults: Bool) {
        searchTask?.cancel()
        searchTask = nil
        searchRequestID = UUID()
        isSearching = false
        if clearResults {
            searchResults = []
        }
        scannedSearchItemCount = 0
        skippedSearchDirectoryCount = 0
        isSearchResultLimited = false
    }

    private func writeURLsToPasteboard(_ urls: [URL]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls.map { $0 as NSURL })
    }

    private func pasteboardURLs() -> [URL] {
        let objects = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil)
        return objects?.compactMap { ($0 as? URL) ?? ($0 as? NSURL)?.absoluteURL } ?? []
    }
}
