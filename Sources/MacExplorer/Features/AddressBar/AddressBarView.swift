import SwiftUI

struct AddressBarView: View {
    @EnvironmentObject private var browser: BrowserStore
    @FocusState private var isFocused: Bool
    @State private var isEditing = false
    @State private var draftPath = ""
    @State private var suggestions: [URL] = []
    @State private var highlightedSuggestionIndex: Int?

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 10) {
                Group {
                    if isEditing {
                        TextField(L10n.text(.path, for: browser.language), text: $draftPath)
                            .textFieldStyle(.plain)
                            .focused($isFocused)
                            .onSubmit { submitPath() }
                            .onExitCommand { cancelEditing() }
                            .onKeyPress(.downArrow) {
                                moveSuggestionHighlight(by: 1)
                                return .handled
                            }
                            .onKeyPress(.upArrow) {
                                moveSuggestionHighlight(by: -1)
                                return .handled
                            }
                            .onChange(of: draftPath) { _, _ in
                                refreshSuggestions()
                            }
                    } else {
                        breadcrumbBar
                            .onTapGesture(count: 2) {
                                beginEditing()
                            }
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: AppTheme.addressBarHeight)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                        .stroke(isEditing ? Color.accentColor.opacity(0.65) : AppTheme.subtleLine)
                )

                Button {
                    browser.toggleCurrentDirectoryFavorite()
                } label: {
                    Image(systemName: browser.isCurrentDirectoryFavorite ? "star.fill" : "star")
                        .foregroundStyle(browser.isCurrentDirectoryFavorite ? Color.yellow : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(
                    browser.isCurrentDirectoryFavorite
                        ? L10n.text(.removeFromFavorites, for: browser.language)
                        : L10n.text(.addToFavorites, for: browser.language)
                )

                Button {
                    beginEditing()
                } label: {
                    Image(systemName: "text.cursor")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(L10n.text(.editPath, for: browser.language))
            }

            if isEditing && !suggestions.isEmpty {
                suggestionList
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: browser.currentURL) { _, newURL in
            if !isEditing {
                draftPath = newURL.path
            }
        }
        .onChange(of: browser.focusRequest) { _, request in
            guard let request else { return }
            switch request.target {
            case .addressBar:
                beginEditing()
            case .fileArea, .searchField:
                if isEditing {
                    cancelEditing()
                }
            }
        }
        .onAppear {
            draftPath = browser.currentURL.path
        }
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(breadcrumbs) { crumb in
                    Button {
                        Task { await browser.navigate(to: crumb.url) }
                    } label: {
                        HStack(spacing: 5) {
                            if crumb.isRoot {
                                Image(systemName: "internaldrive")
                                    .font(.system(size: 12))
                            }
                            Text(crumb.title)
                                .lineLimit(1)
                            if !crumb.isLast {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 4)
                        .frame(height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var breadcrumbs: [PathCrumb] {
        var result: [PathCrumb] = []
        var partial = URL(fileURLWithPath: "/", isDirectory: true)
        let components = browser.currentURL.pathComponents

        for (index, component) in components.enumerated() {
            let title = component == "/" ? "Macintosh HD" : component
            if component != "/" {
                partial.appendPathComponent(component, isDirectory: true)
            }
            result.append(PathCrumb(title: title, url: partial, isRoot: index == 0, isLast: index == components.count - 1))
        }

        return result
    }

    private func beginEditing() {
        draftPath = browser.currentURL.path
        isEditing = true
        isFocused = true
        refreshSuggestions()
    }

    private func cancelEditing() {
        draftPath = browser.currentURL.path
        isEditing = false
        isFocused = false
        suggestions = []
        highlightedSuggestionIndex = nil
    }

    private func submitPath() {
        let url = highlightedSuggestionURL ?? submittedURL
        isEditing = false
        isFocused = false
        suggestions = []
        highlightedSuggestionIndex = nil
        Task { await browser.navigate(to: url) }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element) { index, suggestion in
                Button {
                    draftPath = displayPath(for: suggestion)
                    submitPath()
                } label: {
                    HStack(spacing: 8) {
                        FileIconView(url: suggestion, size: 16)
                        Text(displayPath(for: suggestion))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .contentShape(Rectangle())
                    .background(index == highlightedSuggestionIndex ? AppTheme.selectedFill : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.subtleLine))
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    private var submittedURL: URL {
        let expandedPath = (draftPath as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expandedPath, isDirectory: true)
    }

    private func refreshSuggestions() {
        let input = draftPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            suggestions = []
            return
        }

        let expanded = (input as NSString).expandingTildeInPath
        let directoryPath: String
        let prefix: String

        if expanded.hasSuffix("/") {
            directoryPath = expanded
            prefix = ""
        } else {
            directoryPath = (expanded as NSString).deletingLastPathComponent
            prefix = (expanded as NSString).lastPathComponent
        }

        let directoryURL = URL(fileURLWithPath: directoryPath.isEmpty ? "/" : directoryPath, isDirectory: true)
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isHiddenKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        suggestions = urls
            .filter { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                let isDirectory = (values?.isDirectory ?? false) && !(values?.isPackage ?? false)
                let matchesPrefix = prefix.isEmpty || url.lastPathComponent.localizedCaseInsensitiveContains(prefix)
                return isDirectory && matchesPrefix
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .prefix(6)
            .map { $0 }

        if suggestions.isEmpty {
            highlightedSuggestionIndex = nil
        } else if let highlightedSuggestionIndex {
            self.highlightedSuggestionIndex = min(highlightedSuggestionIndex, suggestions.count - 1)
        } else {
            highlightedSuggestionIndex = 0
        }
    }

    private func displayPath(for url: URL) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if url.path == homePath {
            return "~"
        }
        if url.path.hasPrefix(homePath + "/") {
            return "~" + String(url.path.dropFirst(homePath.count))
        }
        return url.path
    }

    private var highlightedSuggestionURL: URL? {
        guard let highlightedSuggestionIndex,
              suggestions.indices.contains(highlightedSuggestionIndex) else {
            return nil
        }
        return suggestions[highlightedSuggestionIndex]
    }

    private func moveSuggestionHighlight(by offset: Int) {
        guard !suggestions.isEmpty else { return }
        let current = highlightedSuggestionIndex ?? (offset > 0 ? -1 : suggestions.count)
        let next = min(max(current + offset, 0), suggestions.count - 1)
        highlightedSuggestionIndex = next
        draftPath = displayPath(for: suggestions[next])
    }
}

private struct PathCrumb: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let isRoot: Bool
    let isLast: Bool
}
