import Foundation

enum BrowserFocusTarget: Equatable, Sendable {
    case addressBar
    case searchField
    case fileArea
}

struct BrowserFocusRequest: Identifiable, Equatable, Sendable {
    let id = UUID()
    let target: BrowserFocusTarget
}
