import Foundation

enum FileOperationKind: String, Sendable {
    case copy
    case move
    case trash
    case delete
    case create
    case rename

    var title: String {
        title(for: .english)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .copy: L10n.text(.copying, for: language)
        case .move: L10n.text(.moving, for: language)
        case .trash: L10n.text(.movingToTrash, for: language)
        case .delete: L10n.text(.deletingPermanently, for: language)
        case .create: L10n.text(.creating, for: language)
        case .rename: L10n.text(.renaming, for: language)
        }
    }

    var supportsCancellation: Bool {
        switch self {
        case .copy, .move, .delete:
            return true
        case .trash, .create, .rename:
            return false
        }
    }
}

enum FileOperationState: Sendable {
    case running
    case finished
    case failed
    case canceled

    var isTerminal: Bool {
        switch self {
        case .running:
            return false
        case .finished, .failed, .canceled:
            return true
        }
    }
}

struct FileOperationTask: Identifiable, Equatable, Sendable {
    let id: UUID
    var kind: FileOperationKind
    var totalItems: Int
    var completedItems: Int
    var currentItemName: String?
    var state: FileOperationState
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: FileOperationKind,
        totalItems: Int,
        completedItems: Int = 0,
        currentItemName: String? = nil,
        state: FileOperationState = .running,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.totalItems = max(totalItems, 1)
        self.completedItems = completedItems
        self.currentItemName = currentItemName
        self.state = state
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var progress: Double {
        min(max(Double(completedItems) / Double(totalItems), 0), 1)
    }

    var summary: String {
        summary(for: .english)
    }

    func summary(for language: AppLanguage) -> String {
        switch state {
        case .running:
            if let currentItemName {
                return "\(kind.title(for: language)) \(currentItemName)"
            }
            return kind.title(for: language)
        case .finished:
            return "\(kind.title(for: language)) \(L10n.text(.complete, for: language))"
        case .failed:
            return errorMessage ?? "\(kind.title(for: language)) \(L10n.text(.failed, for: language))"
        case .canceled:
            return "\(kind.title(for: language)) \(L10n.text(.canceled, for: language))"
        }
    }
}

struct FileOperationProgress: Sendable {
    let totalItems: Int
    let completedItems: Int
    let currentItemName: String?
}
