import SwiftUI

struct SearchFieldView: View {
    @EnvironmentObject private var browser: BrowserStore
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(
                browser.searchScope == .recursive ? L10n.text(.searchRecursively, for: browser.language) : L10n.text(.searchCurrentFolder, for: browser.language),
                text: Binding(
                    get: { browser.searchQuery },
                    set: { browser.updateSearchQuery($0) }
                )
            )
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    browser.requestFocus(.fileArea)
                }

            if browser.isSearchActive {
                Button {
                    browser.cancelSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                .stroke(isFocused ? Color.accentColor.opacity(0.70) : AppTheme.subtleLine, lineWidth: isFocused ? 1.5 : 1)
        )
        .onChange(of: browser.focusRequest) { _, request in
            guard let request else { return }
            switch request.target {
            case .searchField:
                isFocused = true
            case .addressBar, .fileArea:
                isFocused = false
            }
        }
    }
}
