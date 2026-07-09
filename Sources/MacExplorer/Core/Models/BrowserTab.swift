import Foundation

struct BrowserTab: Identifiable, Equatable {
    let id: UUID
    var currentURL: URL
    var backStack: [URL]
    var forwardStack: [URL]

    init(id: UUID = UUID(), currentURL: URL, backStack: [URL] = [], forwardStack: [URL] = []) {
        self.id = id
        self.currentURL = currentURL
        self.backStack = backStack
        self.forwardStack = forwardStack
    }

    var title: String {
        let name = currentURL.lastPathComponent
        return name.isEmpty ? currentURL.path : name
    }
}
