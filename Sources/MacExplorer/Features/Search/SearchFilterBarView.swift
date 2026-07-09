import SwiftUI

struct SearchFilterBarView: View {
    @EnvironmentObject private var browser: BrowserStore

    var body: some View {
        HStack(spacing: 10) {
            Label(L10n.text(.filters, for: browser.language), systemImage: "line.3.horizontal.decrease.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(
                L10n.text(.fileExtension, for: browser.language),
                text: Binding(
                    get: { browser.searchFilters.extensionText },
                    set: { browser.searchFilters.extensionText = $0 }
                )
            )
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .frame(width: 104, height: 26)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.subtleLine))

            FilterPicker(L10n.text(.type, for: browser.language), selection: Binding(
                get: { browser.searchFilters.type },
                set: { browser.searchFilters.type = $0 }
            )) {
                ForEach(FileTypeFilter.allCases) { filter in
                    Text(filter.title(for: browser.language)).tag(filter)
                }
            }
            .frame(width: 136)

            FilterPicker(L10n.text(.size, for: browser.language), selection: Binding(
                get: { browser.searchFilters.size },
                set: { browser.searchFilters.size = $0 }
            )) {
                ForEach(FileSizeFilter.allCases) { filter in
                    Text(filter.title(for: browser.language)).tag(filter)
                }
            }
            .frame(width: 132)

            FilterPicker(L10n.text(.modified, for: browser.language), selection: Binding(
                get: { browser.searchFilters.modified },
                set: { browser.searchFilters.modified = $0 }
            )) {
                ForEach(ModifiedDateFilter.allCases) { filter in
                    Text(filter.title(for: browser.language)).tag(filter)
                }
            }
            .frame(width: 136)

            Spacer()

            if browser.searchFilters.isActive {
                Button {
                    browser.resetSearchFilters()
                } label: {
                    Label(L10n.text(.reset, for: browser.language), systemImage: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct FilterPicker<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    @ViewBuilder let content: Content

    init(_ title: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        Picker(title, selection: $selection) {
            content
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
    }
}
