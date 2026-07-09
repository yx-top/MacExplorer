import Foundation

enum FileClipboardOperation: Sendable {
    case copy
    case cut
}

struct FileClipboard: Sendable {
    var urls: [URL]
    var operation: FileClipboardOperation
}

