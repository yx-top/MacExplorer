import Foundation

enum SearchScope: String, CaseIterable, Identifiable {
    case currentFolder
    case recursive

    var id: String { rawValue }

    var title: String {
        title(for: .english)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .currentFolder: L10n.text(.current, for: language)
        case .recursive: L10n.text(.recursive, for: language)
        }
    }
}
