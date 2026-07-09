import Foundation

enum SearchMatcher {
    static func matches(_ item: FileItem, query: String, additionalText: [String] = []) -> Bool {
        let tokens = normalizedTokens(from: query)
        guard !tokens.isEmpty else { return true }

        let searchableText = [
            item.displayName,
            item.typeDescription,
            item.fileExtension
        ] + additionalText

        let normalizedSearchableText = searchableText
            .filter { !$0.isEmpty }
            .map(normalize)

        return tokens.allSatisfy { token in
            normalizedSearchableText.contains { $0.contains(token) }
        }
    }

    private static func normalizedTokens(from query: String) -> [String] {
        query
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalize)
            .filter { !$0.isEmpty }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
