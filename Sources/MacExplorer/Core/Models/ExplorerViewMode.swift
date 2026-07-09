import Foundation

enum ExplorerViewMode: String, CaseIterable, Identifiable {
    case details
    case icons

    var id: String { rawValue }

    var title: String {
        title(for: .english)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .details: L10n.text(.details, for: language)
        case .icons: L10n.text(.icons, for: language)
        }
    }

    var symbolName: String {
        switch self {
        case .details: "list.bullet.rectangle"
        case .icons: "square.grid.2x2"
        }
    }
}
