import Foundation

enum L10n {
    enum Key: String {
        case newFolder
        case newEmptyFile
        case newFile
        case newWindow
        case newTab
        case duplicateTab
        case closeTab
        case closeOtherTabs
        case closeTabsToRight
        case copy
        case cut
        case paste
        case open
        case openWith
        case rename
        case moveToTrash
        case deletePermanently
        case quickLook
        case selectAll
        case selection
        case selectNextItem
        case selectPreviousItem
        case extendSelectionDown
        case extendSelectionUp
        case navigation
        case back
        case forward
        case up
        case refresh
        case focusAddressBar
        case focusSearch
        case focusFileArea
        case display
        case viewMode
        case sortBy
        case sortDirection
        case ascending
        case descending
        case foldersFirst
        case showHiddenFiles
        case showFileExtensions
        case detailsPanel
        case language
        case path
        case editPath
        case searchScope
        case searchFilters
        case filters
        case fileExtension
        case type
        case size
        case modified
        case created
        case reset
        case searchRecursively
        case searchCurrentFolder
        case cannotOpenFolder
        case emptyFolder
        case noResults
        case tryDifferentSearch
        case noVisibleItems
        case openInTerminal
        case revealInFinder
        case openCurrentFolderInTerminal
        case copyPath
        case inspectorMode
        case details
        case preview
        case noSelection
        case selectItemToPreview
        case general
        case contents
        case location
        case hidden
        case permissions
        case readable
        case writable
        case executable
        case noAccess
        case files
        case calculating
        case skipped
        case yes
        case no
        case currentFolder
        case items
        case name
        case operations
        case operationCenter
        case operationHistory
        case activeOperation
        case recentOperations
        case noOperations
        case clearCompleted
        case updated
        case started
        case running
        case finished
        case clear
        case cancelOperation
        case searching
        case recursiveSearch
        case hiddenFilesVisible
        case folderName
        case fileName
        case create
        case cancel
        case nameConflict
        case keepBoth
        case replace
        case skip
        case fileFolder
        case file
        case quickAccess
        case favorites
        case addToFavorites
        case removeFromFavorites
        case recent
        case clearRecent
        case removeFromRecent
        case moveUp
        case moveDown
        case libraries
        case locations
        case home
        case desktop
        case downloads
        case documents
        case pictures
        case movies
        case music
        case applications
        case chooseApplication
        case chooseApplicationMessage
        case anyType
        case folders
        case images
        case audio
        case video
        case archives
        case apps
        case anySize
        case anyDate
        case today
        case thisWeek
        case thisMonth
        case thisYear
        case current
        case recursive
        case icons
        case copying
        case moving
        case movingToTrash
        case deletingPermanently
        case creating
        case renaming
        case complete
        case failed
        case canceled
        case operationCanceled
        case anotherFileOperationRunning
        case untitledFileName
    }

    static func text(_ key: Key, for language: AppLanguage) -> String {
        switch language {
        case .chinese:
            zh[key] ?? en[key] ?? key.rawValue
        case .english:
            en[key] ?? key.rawValue
        }
    }

    static func itemCount(_ count: Int, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "\(count) 项"
        case .english: "\(count) item\(count == 1 ? "" : "s")"
        }
    }

    static func selectedCount(_ count: Int, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "已选择 \(count) 项"
        case .english: "\(count) selected"
        }
    }

    static func skippedSearchLocations(_ count: Int, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "已跳过 \(count) 个无法访问的位置"
        case .english: "Skipped \(count) inaccessible location\(count == 1 ? "" : "s")"
        }
    }

    static func scannedSearchItems(_ count: Int, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "已扫描 \(count) 项"
        case .english: "Scanned \(count) item\(count == 1 ? "" : "s")"
        }
    }

    static func searchResultLimitReached(_ count: Int, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "已显示前 \(count) 项"
        case .english: "Showing first \(count) results"
        }
    }

    static func createFolderMessage(in location: String, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "在 \(location) 中创建文件夹。"
        case .english: "Create a folder in \(location)."
        }
    }

    static func createFileMessage(in location: String, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "在 \(location) 中创建空文件。"
        case .english: "Create an empty file in \(location)."
        }
    }

    static func renameMessage(itemName: String, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "输入 \(itemName) 的新名称。"
        case .english: "Enter a new name for \(itemName)."
        }
    }

    static func created(_ name: String, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "已创建 \(name)"
        case .english: "Created \(name)"
        }
    }

    static func renamed(to name: String, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "已重命名为 \(name)"
        case .english: "Renamed to \(name)"
        }
    }

    static func copied(urls: [URL], for language: AppLanguage) -> String {
        switch language {
        case .chinese:
            return urls.count == 1 ? "已复制 \(urls[0].lastPathComponent)" : "已复制 \(urls.count) 项"
        case .english:
            return urls.count == 1 ? "Copied \(urls[0].lastPathComponent)" : "Copied \(urls.count) items"
        }
    }

    static func cut(urls: [URL], for language: AppLanguage) -> String {
        switch language {
        case .chinese:
            return urls.count == 1 ? "已剪切 \(urls[0].lastPathComponent)" : "已剪切 \(urls.count) 项"
        case .english:
            return urls.count == 1 ? "Cut \(urls[0].lastPathComponent)" : "Cut \(urls.count) items"
        }
    }

    static func pasted(urls: [URL], for language: AppLanguage) -> String {
        switch language {
        case .chinese:
            return urls.count == 1 ? "已粘贴 \(urls[0].lastPathComponent)" : "已粘贴 \(urls.count) 项"
        case .english:
            return urls.count == 1 ? "Pasted \(urls[0].lastPathComponent)" : "Pasted \(urls.count) items"
        }
    }

    static func trashConfirmation(urls: [URL], for language: AppLanguage) -> String {
        switch language {
        case .chinese:
            return urls.count == 1 ? "将 \(urls[0].lastPathComponent) 移到废纸篓？" : "将选中的 \(urls.count) 项移到废纸篓？"
        case .english:
            return urls.count == 1 ? "Move \(urls[0].lastPathComponent) to the Trash?" : "Move \(urls.count) selected items to the Trash?"
        }
    }

    static func permanentDeleteConfirmation(urls: [URL], for language: AppLanguage) -> String {
        switch language {
        case .chinese:
            if urls.count == 1 {
                return "永久删除 \(urls[0].lastPathComponent)？此操作无法撤销。"
            }
            return "永久删除选中的 \(urls.count) 项？此操作无法撤销。"
        case .english:
            if urls.count == 1 {
                return "Permanently delete \(urls[0].lastPathComponent)? This cannot be undone."
            }
            return "Permanently delete \(urls.count) selected items? This cannot be undone."
        }
    }

    static func movedToTrash(count: Int, for language: AppLanguage) -> String {
        switch language {
        case .chinese: count == 1 ? "已移到废纸篓" : "已将 \(count) 项移到废纸篓"
        case .english: count == 1 ? "Moved to Trash" : "Moved \(count) items to Trash"
        }
    }

    static func deletedPermanently(count: Int, for language: AppLanguage) -> String {
        switch language {
        case .chinese: count == 1 ? "已永久删除" : "已永久删除 \(count) 项"
        case .english: count == 1 ? "Permanently deleted" : "Permanently deleted \(count) items"
        }
    }

    static func addedToFavorites(_ name: String, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "已将 \(name) 加入收藏夹"
        case .english: "Added \(name) to Favorites"
        }
    }

    static func removedFromFavorites(_ name: String, for language: AppLanguage) -> String {
        switch language {
        case .chinese: "已将 \(name) 从收藏夹移除"
        case .english: "Removed \(name) from Favorites"
        }
    }

    static func conflictMessage(count: Int, for language: AppLanguage) -> String {
        switch language {
        case .chinese:
            return count == 1 ? "此文件夹中已存在同名项目。" : "此文件夹中已有 \(count) 个同名项目。"
        case .english:
            return count == 1 ? "An item with the same name already exists in this folder." : "\(count) items have names that already exist in this folder."
        }
    }

    static func permissions(readable: Bool?, writable: Bool?, executable: Bool?, for language: AppLanguage) -> String {
        let values: [(Bool?, Key)] = [
            (readable, .readable),
            (writable, .writable),
            (executable, .executable)
        ]

        let granted = values.compactMap { isGranted, key in
            isGranted == true ? text(key, for: language) : nil
        }

        if !granted.isEmpty {
            return granted.joined(separator: language == .chinese ? "、" : ", ")
        }

        if values.contains(where: { $0.0 == false }) {
            return text(.noAccess, for: language)
        }

        return "--"
    }

    static func fallbackFileType(isDirectory: Bool, fileExtension: String, for language: AppLanguage) -> String {
        if isDirectory {
            return text(.fileFolder, for: language)
        }

        guard !fileExtension.isEmpty else {
            return text(.file, for: language)
        }

        switch language {
        case .chinese: return "\(fileExtension.uppercased()) 文件"
        case .english: return "\(fileExtension.uppercased()) File"
        }
    }

    static func sidebarTitle(_ title: String, for language: AppLanguage) -> String {
        let key: Key? = switch title {
        case "Quick Access": .quickAccess
        case "Favorites": .favorites
        case "Recent": .recent
        case "Libraries": .libraries
        case "Locations": .locations
        case "Home": .home
        case "Desktop": .desktop
        case "Downloads": .downloads
        case "Documents": .documents
        case "Pictures": .pictures
        case "Movies": .movies
        case "Music": .music
        case "Applications": .applications
        default: nil
        }

        guard let key else { return title }
        return text(key, for: language)
    }

    private static let zh: [Key: String] = [
        .newFolder: "新建文件夹",
        .newEmptyFile: "新建空文件",
        .newFile: "新建文件",
        .newWindow: "新建窗口",
        .newTab: "新建标签页",
        .duplicateTab: "复制标签页",
        .closeTab: "关闭标签页",
        .closeOtherTabs: "关闭其他标签页",
        .closeTabsToRight: "关闭右侧标签页",
        .copy: "复制",
        .cut: "剪切",
        .paste: "粘贴",
        .open: "打开",
        .openWith: "打开方式...",
        .rename: "重命名",
        .moveToTrash: "移到废纸篓",
        .deletePermanently: "永久删除",
        .quickLook: "快速预览",
        .selectAll: "全选",
        .selection: "选择",
        .selectNextItem: "选择下一项",
        .selectPreviousItem: "选择上一项",
        .extendSelectionDown: "向下扩展选择",
        .extendSelectionUp: "向上扩展选择",
        .navigation: "导航",
        .back: "后退",
        .forward: "前进",
        .up: "上一级",
        .refresh: "刷新",
        .focusAddressBar: "聚焦地址栏",
        .focusSearch: "聚焦搜索",
        .focusFileArea: "聚焦文件区",
        .display: "显示选项",
        .viewMode: "视图模式",
        .sortBy: "排序方式",
        .sortDirection: "排序方向",
        .ascending: "升序",
        .descending: "降序",
        .foldersFirst: "文件夹优先",
        .showHiddenFiles: "显示隐藏文件",
        .showFileExtensions: "显示文件扩展名",
        .detailsPanel: "详情面板",
        .language: "语言",
        .path: "路径",
        .editPath: "编辑路径",
        .searchScope: "搜索范围",
        .searchFilters: "搜索筛选",
        .filters: "筛选",
        .fileExtension: "扩展名",
        .type: "类型",
        .size: "大小",
        .modified: "修改时间",
        .created: "创建时间",
        .reset: "重置",
        .searchRecursively: "递归搜索",
        .searchCurrentFolder: "搜索当前文件夹",
        .cannotOpenFolder: "无法打开文件夹",
        .emptyFolder: "空文件夹",
        .noResults: "没有结果",
        .tryDifferentSearch: "请尝试其他搜索词或清除筛选条件。",
        .noVisibleItems: "此位置没有可见项目。",
        .openInTerminal: "在终端中打开",
        .revealInFinder: "在 Finder 中显示",
        .openCurrentFolderInTerminal: "在终端中打开当前文件夹",
        .copyPath: "复制路径",
        .inspectorMode: "检查器模式",
        .details: "详情",
        .preview: "预览",
        .noSelection: "未选择",
        .selectItemToPreview: "选择一个项目进行预览。",
        .general: "常规",
        .contents: "内容",
        .location: "位置",
        .hidden: "隐藏",
        .permissions: "权限",
        .readable: "可读",
        .writable: "可写",
        .executable: "可执行",
        .noAccess: "无权限",
        .files: "文件",
        .calculating: "正在计算...",
        .skipped: "已跳过",
        .yes: "是",
        .no: "否",
        .currentFolder: "当前文件夹",
        .items: "项目",
        .name: "名称",
        .operations: "操作",
        .operationCenter: "操作中心",
        .operationHistory: "操作历史",
        .activeOperation: "活动任务",
        .recentOperations: "最近任务",
        .noOperations: "暂无操作记录",
        .clearCompleted: "清理已完成",
        .updated: "更新于",
        .started: "开始于",
        .running: "进行中",
        .finished: "已完成",
        .clear: "清空",
        .cancelOperation: "取消操作",
        .searching: "搜索中",
        .recursiveSearch: "递归搜索",
        .hiddenFilesVisible: "已显示隐藏文件",
        .folderName: "文件夹名称",
        .fileName: "文件名称",
        .create: "创建",
        .cancel: "取消",
        .nameConflict: "名称冲突",
        .keepBoth: "保留两者",
        .replace: "替换",
        .skip: "跳过",
        .fileFolder: "文件夹",
        .file: "文件",
        .quickAccess: "快速访问",
        .favorites: "收藏夹",
        .addToFavorites: "添加到收藏夹",
        .removeFromFavorites: "从收藏夹移除",
        .recent: "最近访问",
        .clearRecent: "清空最近访问",
        .removeFromRecent: "从最近访问移除",
        .moveUp: "上移",
        .moveDown: "下移",
        .libraries: "资料库",
        .locations: "位置",
        .home: "主页",
        .desktop: "桌面",
        .downloads: "下载",
        .documents: "文档",
        .pictures: "图片",
        .movies: "影片",
        .music: "音乐",
        .applications: "应用程序",
        .chooseApplication: "选择应用程序",
        .chooseApplicationMessage: "选择用于打开所选项目的应用程序。",
        .anyType: "任意类型",
        .folders: "文件夹",
        .images: "图片",
        .audio: "音频",
        .video: "视频",
        .archives: "压缩包",
        .apps: "应用",
        .anySize: "任意大小",
        .anyDate: "任意日期",
        .today: "今天",
        .thisWeek: "本周",
        .thisMonth: "本月",
        .thisYear: "今年",
        .current: "当前",
        .recursive: "递归",
        .icons: "图标",
        .copying: "正在复制",
        .moving: "正在移动",
        .movingToTrash: "正在移到废纸篓",
        .deletingPermanently: "正在永久删除",
        .creating: "正在创建",
        .renaming: "正在重命名",
        .complete: "已完成",
        .failed: "失败",
        .canceled: "已取消",
        .operationCanceled: "操作已取消",
        .anotherFileOperationRunning: "已有文件操作正在运行",
        .untitledFileName: "未命名.txt"
    ]

    private static let en: [Key: String] = [
        .newFolder: "New Folder",
        .newEmptyFile: "New Empty File",
        .newFile: "New File",
        .newWindow: "New Window",
        .newTab: "New Tab",
        .duplicateTab: "Duplicate Tab",
        .closeTab: "Close Tab",
        .closeOtherTabs: "Close Other Tabs",
        .closeTabsToRight: "Close Tabs to the Right",
        .copy: "Copy",
        .cut: "Cut",
        .paste: "Paste",
        .open: "Open",
        .openWith: "Open With...",
        .rename: "Rename",
        .moveToTrash: "Move to Trash",
        .deletePermanently: "Delete Permanently",
        .quickLook: "Quick Look",
        .selectAll: "Select All",
        .selection: "Selection",
        .selectNextItem: "Select Next Item",
        .selectPreviousItem: "Select Previous Item",
        .extendSelectionDown: "Extend Selection Down",
        .extendSelectionUp: "Extend Selection Up",
        .navigation: "Navigation",
        .back: "Back",
        .forward: "Forward",
        .up: "Up",
        .refresh: "Refresh",
        .focusAddressBar: "Focus Address Bar",
        .focusSearch: "Focus Search",
        .focusFileArea: "Focus File Area",
        .display: "Display Options",
        .viewMode: "View Mode",
        .sortBy: "Sort By",
        .sortDirection: "Sort Direction",
        .ascending: "Ascending",
        .descending: "Descending",
        .foldersFirst: "Folders First",
        .showHiddenFiles: "Show Hidden Files",
        .showFileExtensions: "Show File Extensions",
        .detailsPanel: "Details Panel",
        .language: "Language",
        .path: "Path",
        .editPath: "Edit Path",
        .searchScope: "Search Scope",
        .searchFilters: "Search Filters",
        .filters: "Filters",
        .fileExtension: "Extension",
        .type: "Type",
        .size: "Size",
        .modified: "Modified",
        .created: "Created",
        .reset: "Reset",
        .searchRecursively: "Search recursively",
        .searchCurrentFolder: "Search current folder",
        .cannotOpenFolder: "Cannot Open Folder",
        .emptyFolder: "Empty Folder",
        .noResults: "No Results",
        .tryDifferentSearch: "Try a different search term or clear the filters.",
        .noVisibleItems: "This location has no visible items.",
        .openInTerminal: "Open in Terminal",
        .revealInFinder: "Reveal in Finder",
        .openCurrentFolderInTerminal: "Open Current Folder in Terminal",
        .copyPath: "Copy Path",
        .inspectorMode: "Inspector Mode",
        .details: "Details",
        .preview: "Preview",
        .noSelection: "No Selection",
        .selectItemToPreview: "Select an item to preview.",
        .general: "General",
        .contents: "Contents",
        .location: "Location",
        .hidden: "Hidden",
        .permissions: "Permissions",
        .readable: "Read",
        .writable: "Write",
        .executable: "Execute",
        .noAccess: "No access",
        .files: "Files",
        .calculating: "Calculating...",
        .skipped: "Skipped",
        .yes: "Yes",
        .no: "No",
        .currentFolder: "Current Folder",
        .items: "Items",
        .name: "Name",
        .operations: "Operations",
        .operationCenter: "Operation Center",
        .operationHistory: "Operation History",
        .activeOperation: "Active Operation",
        .recentOperations: "Recent Operations",
        .noOperations: "No operations yet",
        .clearCompleted: "Clear Completed",
        .updated: "Updated",
        .started: "Started",
        .running: "Running",
        .finished: "Finished",
        .clear: "Clear",
        .cancelOperation: "Cancel Operation",
        .searching: "Searching",
        .recursiveSearch: "Recursive search",
        .hiddenFilesVisible: "Hidden files visible",
        .folderName: "Folder name",
        .fileName: "File name",
        .create: "Create",
        .cancel: "Cancel",
        .nameConflict: "Name Conflict",
        .keepBoth: "Keep Both",
        .replace: "Replace",
        .skip: "Skip",
        .fileFolder: "File folder",
        .file: "File",
        .quickAccess: "Quick Access",
        .favorites: "Favorites",
        .addToFavorites: "Add to Favorites",
        .removeFromFavorites: "Remove from Favorites",
        .recent: "Recent",
        .clearRecent: "Clear Recent",
        .removeFromRecent: "Remove from Recent",
        .moveUp: "Move Up",
        .moveDown: "Move Down",
        .libraries: "Libraries",
        .locations: "Locations",
        .home: "Home",
        .desktop: "Desktop",
        .downloads: "Downloads",
        .documents: "Documents",
        .pictures: "Pictures",
        .movies: "Movies",
        .music: "Music",
        .applications: "Applications",
        .chooseApplication: "Choose Application",
        .chooseApplicationMessage: "Choose an application to open the selected item.",
        .anyType: "Any Type",
        .folders: "Folders",
        .images: "Images",
        .audio: "Audio",
        .video: "Video",
        .archives: "Archives",
        .apps: "Apps",
        .anySize: "Any Size",
        .anyDate: "Any Date",
        .today: "Today",
        .thisWeek: "This Week",
        .thisMonth: "This Month",
        .thisYear: "This Year",
        .current: "Current",
        .recursive: "Recursive",
        .icons: "Icons",
        .copying: "Copying",
        .moving: "Moving",
        .movingToTrash: "Moving to Trash",
        .deletingPermanently: "Deleting Permanently",
        .creating: "Creating",
        .renaming: "Renaming",
        .complete: "complete",
        .failed: "failed",
        .canceled: "canceled",
        .operationCanceled: "Operation canceled",
        .anotherFileOperationRunning: "Another file operation is already running",
        .untitledFileName: "Untitled.txt"
    ]
}
