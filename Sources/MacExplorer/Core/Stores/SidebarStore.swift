import AppKit
import Combine
import Foundation

@MainActor
final class SidebarStore: ObservableObject {
    @Published private(set) var sections: [SidebarSection] = []

    private var cancellables: Set<AnyCancellable> = []

    init() {
        reloadSections()
        observeVolumeChanges()
    }

    func refresh() {
        reloadSections()
    }

    private func reloadSections() {
        var sections = [
            SidebarSection(title: "Quick Access", items: quickAccessItems()),
            SidebarSection(title: "Libraries", items: libraryItems())
        ]

        let volumeItems = mountedVolumeItems()
        if !volumeItems.isEmpty {
            sections.append(SidebarSection(title: "Locations", items: volumeItems))
        }

        self.sections = sections
    }

    private func quickAccessItems() -> [SidebarItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var quickAccess: [SidebarItem] = [
            SidebarItem(title: "Home", symbolName: "house", url: home, isPinned: true),
            SidebarItem(title: "Desktop", symbolName: "desktopcomputer", url: home.appendingPathComponent("Desktop"), isPinned: true),
            SidebarItem(title: "Downloads", symbolName: "arrow.down.circle", url: home.appendingPathComponent("Downloads"), isPinned: true),
            SidebarItem(title: "Documents", symbolName: "doc.text", url: home.appendingPathComponent("Documents"), isPinned: true)
        ]

        let icloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: icloud.path) {
            quickAccess.append(SidebarItem(title: "iCloud Drive", symbolName: "icloud", url: icloud, isPinned: true))
        }

        return quickAccess
    }

    private func libraryItems() -> [SidebarItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            SidebarItem(title: "Pictures", symbolName: "photo", url: home.appendingPathComponent("Pictures")),
            SidebarItem(title: "Movies", symbolName: "film", url: home.appendingPathComponent("Movies")),
            SidebarItem(title: "Music", symbolName: "music.note", url: home.appendingPathComponent("Music")),
            SidebarItem(title: "Applications", symbolName: "app", url: URL(fileURLWithPath: "/Applications"))
        ]
    }

    private func mountedVolumeItems() -> [SidebarItem] {
        let keys: Set<URLResourceKey> = [
            .volumeIsRootFileSystemKey,
            .volumeNameKey
        ]
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []

        return volumes.compactMap { volumeURL -> SidebarItem? in
            let values = try? volumeURL.resourceValues(forKeys: keys)
            guard values?.volumeIsRootFileSystem != true else { return nil }

            let title = values?.volumeName ?? volumeURL.lastPathComponent
            return SidebarItem(
                title: title.isEmpty ? volumeURL.path : title,
                symbolName: "externaldrive",
                url: volumeURL
            )
        }
        .sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    private func observeVolumeChanges() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ].forEach { notificationName in
            notificationCenter.publisher(for: notificationName)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        self?.reloadSections()
                    }
                }
                .store(in: &cancellables)
        }
    }
}
