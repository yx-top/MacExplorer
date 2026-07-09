import Foundation

struct SidebarSection: Identifiable, Equatable {
    let id = UUID()
    let title: String
    var items: [SidebarItem]
}

enum SidebarItemRole: Equatable {
    case standard
    case favorite
    case recent
}

struct SidebarItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let symbolName: String
    let url: URL
    var isPinned: Bool = false
    var role: SidebarItemRole = .standard
}
