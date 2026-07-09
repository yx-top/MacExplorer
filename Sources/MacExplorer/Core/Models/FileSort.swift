import Foundation

enum FileSortField: String, CaseIterable, Identifiable, Sendable {
    case name
    case type
    case size
    case modified
    case created

    var id: String { rawValue }

    var title: String {
        title(for: .english)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .name: L10n.text(.name, for: language)
        case .type: L10n.text(.type, for: language)
        case .size: L10n.text(.size, for: language)
        case .modified: L10n.text(.modified, for: language)
        case .created: L10n.text(.created, for: language)
        }
    }
}

enum SortDirection: String, CaseIterable, Sendable {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .ascending: L10n.text(.ascending, for: language)
        case .descending: L10n.text(.descending, for: language)
        }
    }
}

struct FileSort: Equatable, Sendable {
    var field: FileSortField = .name
    var direction: SortDirection = .ascending
    var foldersFirst: Bool = true
}
