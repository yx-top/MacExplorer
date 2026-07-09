import CoreGraphics
import Foundation

struct PreferencesStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadViewMode() -> ExplorerViewMode {
        guard let rawValue = defaults.string(forKey: Keys.viewMode),
              let value = ExplorerViewMode(rawValue: rawValue) else {
            return .details
        }
        return value
    }

    func loadViewMode(for directoryURL: URL) -> ExplorerViewMode? {
        let path = normalizedPath(for: directoryURL)
        guard let rawValue = loadDirectoryViewModes()[path] else { return nil }
        return ExplorerViewMode(rawValue: rawValue)
    }

    func save(viewMode: ExplorerViewMode) {
        defaults.set(viewMode.rawValue, forKey: Keys.viewMode)
    }

    func save(viewMode: ExplorerViewMode, for directoryURL: URL) {
        let path = normalizedPath(for: directoryURL)
        var viewModes = loadDirectoryViewModes()
        viewModes[path] = viewMode.rawValue
        defaults.set(viewModes, forKey: Keys.directoryViewModes)
    }

    func loadSort() -> FileSort {
        let field = defaults.string(forKey: Keys.sortField).flatMap(FileSortField.init(rawValue:)) ?? .name
        let direction = defaults.string(forKey: Keys.sortDirection).flatMap(SortDirection.init(rawValue:)) ?? .ascending
        let foldersFirst = defaults.object(forKey: Keys.foldersFirst) as? Bool ?? true
        return FileSort(field: field, direction: direction, foldersFirst: foldersFirst)
    }

    func loadSort(for directoryURL: URL) -> FileSort? {
        let path = normalizedPath(for: directoryURL)
        return loadDirectorySorts()[path]?.sort
    }

    func save(sort: FileSort) {
        defaults.set(sort.field.rawValue, forKey: Keys.sortField)
        defaults.set(sort.direction.rawValue, forKey: Keys.sortDirection)
        defaults.set(sort.foldersFirst, forKey: Keys.foldersFirst)
    }

    func save(sort: FileSort, for directoryURL: URL) {
        let path = normalizedPath(for: directoryURL)
        var sorts = loadDirectorySorts()
        sorts[path] = StoredSort(sort: sort)

        if let data = try? JSONEncoder().encode(sorts) {
            defaults.set(data, forKey: Keys.directorySorts)
        }
    }

    func loadShowHiddenFiles() -> Bool {
        defaults.bool(forKey: Keys.showHiddenFiles)
    }

    func save(showHiddenFiles: Bool) {
        defaults.set(showHiddenFiles, forKey: Keys.showHiddenFiles)
    }

    func loadShowFileExtensions() -> Bool {
        guard defaults.object(forKey: Keys.showFileExtensions) != nil else {
            return true
        }
        return defaults.bool(forKey: Keys.showFileExtensions)
    }

    func save(showFileExtensions: Bool) {
        defaults.set(showFileExtensions, forKey: Keys.showFileExtensions)
    }

    func loadDetailsPanelVisibility() -> Bool {
        guard defaults.object(forKey: Keys.detailsPanelVisible) != nil else {
            return true
        }
        return defaults.bool(forKey: Keys.detailsPanelVisible)
    }

    func save(detailsPanelVisible: Bool) {
        defaults.set(detailsPanelVisible, forKey: Keys.detailsPanelVisible)
    }

    func loadSidebarWidth(defaultValue: CGFloat, minValue: CGFloat, maxValue: CGFloat) -> CGFloat {
        guard defaults.object(forKey: Keys.sidebarWidth) != nil else {
            return defaultValue
        }

        let savedWidth = CGFloat(defaults.double(forKey: Keys.sidebarWidth))
        return min(max(savedWidth, minValue), maxValue)
    }

    func save(sidebarWidth: CGFloat) {
        defaults.set(Double(sidebarWidth), forKey: Keys.sidebarWidth)
    }

    func loadSearchScope() -> SearchScope {
        guard let rawValue = defaults.string(forKey: Keys.searchScope),
              let value = SearchScope(rawValue: rawValue) else {
            return .currentFolder
        }
        return value
    }

    func save(searchScope: SearchScope) {
        defaults.set(searchScope.rawValue, forKey: Keys.searchScope)
    }

    func loadLanguage() -> AppLanguage {
        guard let rawValue = defaults.string(forKey: Keys.language),
              let value = AppLanguage(rawValue: rawValue) else {
            return .chinese
        }
        return value
    }

    func save(language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Keys.language)
    }

    func loadRecentDirectories() -> [URL] {
        guard let paths = defaults.stringArray(forKey: Keys.recentDirectories) else {
            return []
        }

        return paths
            .map { ($0 as NSString).expandingTildeInPath }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            .filter(Self.isExistingDirectory)
    }

    func save(recentDirectories: [URL]) {
        defaults.set(recentDirectories.map(\.path), forKey: Keys.recentDirectories)
    }

    func loadFavoriteDirectories() -> [URL] {
        guard let paths = defaults.stringArray(forKey: Keys.favoriteDirectories) else {
            return []
        }

        return paths
            .map { ($0 as NSString).expandingTildeInPath }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            .filter(Self.isExistingDirectory)
    }

    func save(favoriteDirectories: [URL]) {
        defaults.set(favoriteDirectories.map(\.path), forKey: Keys.favoriteDirectories)
    }

    func loadTabs() -> [URL] {
        guard let paths = defaults.stringArray(forKey: Keys.tabs) else {
            return []
        }

        return paths
            .map { ($0 as NSString).expandingTildeInPath }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func save(tabs: [BrowserTab]) {
        let paths = tabs.map(\.currentURL.path)
        defaults.set(paths, forKey: Keys.tabs)
    }

    func loadSelectedTabPath() -> String? {
        defaults.string(forKey: Keys.selectedTabPath)
    }

    func save(selectedTabURL: URL) {
        defaults.set(selectedTabURL.path, forKey: Keys.selectedTabPath)
    }

    private enum Keys {
        static let viewMode = "viewMode"
        static let sortField = "sortField"
        static let sortDirection = "sortDirection"
        static let foldersFirst = "foldersFirst"
        static let directoryViewModes = "directoryViewModes"
        static let directorySorts = "directorySorts"
        static let showHiddenFiles = "showHiddenFiles"
        static let showFileExtensions = "showFileExtensions"
        static let detailsPanelVisible = "detailsPanelVisible"
        static let sidebarWidth = "sidebarWidth"
        static let searchScope = "searchScope"
        static let language = "language"
        static let recentDirectories = "recentDirectories"
        static let favoriteDirectories = "favoriteDirectories"
        static let tabs = "tabs"
        static let selectedTabPath = "selectedTabPath"
    }

    private struct StoredSort: Codable {
        let field: String
        let direction: String
        let foldersFirst: Bool

        init(sort: FileSort) {
            self.field = sort.field.rawValue
            self.direction = sort.direction.rawValue
            self.foldersFirst = sort.foldersFirst
        }

        var sort: FileSort {
            FileSort(
                field: FileSortField(rawValue: field) ?? .name,
                direction: SortDirection(rawValue: direction) ?? .ascending,
                foldersFirst: foldersFirst
            )
        }
    }

    private func loadDirectoryViewModes() -> [String: String] {
        defaults.dictionary(forKey: Keys.directoryViewModes) as? [String: String] ?? [:]
    }

    private func loadDirectorySorts() -> [String: StoredSort] {
        guard let data = defaults.data(forKey: Keys.directorySorts),
              let sorts = try? JSONDecoder().decode([String: StoredSort].self, from: data) else {
            return [:]
        }
        return sorts
    }

    private func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private static func isExistingDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
