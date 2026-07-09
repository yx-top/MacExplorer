import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        }
    }
}
