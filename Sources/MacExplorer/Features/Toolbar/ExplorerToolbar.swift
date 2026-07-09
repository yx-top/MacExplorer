import SwiftUI

struct ExplorerToolbar: View {
    @EnvironmentObject private var browser: BrowserStore

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                IconButton(symbolName: "chevron.left", title: L10n.text(.back, for: browser.language), isDisabled: !browser.canGoBack) {
                    Task { await browser.goBack() }
                }

                IconButton(symbolName: "chevron.right", title: L10n.text(.forward, for: browser.language), isDisabled: !browser.canGoForward) {
                    Task { await browser.goForward() }
                }

                IconButton(symbolName: "arrow.up", title: L10n.text(.up, for: browser.language)) {
                    Task { await browser.goUp() }
                }

                IconButton(symbolName: "arrow.clockwise", title: L10n.text(.refresh, for: browser.language)) {
                    Task { await browser.reload() }
                }
            }

            Divider()
                .frame(height: 22)

            Picker(L10n.text(.viewMode, for: browser.language), selection: $browser.viewMode) {
                ForEach(ExplorerViewMode.allCases) { mode in
                    Image(systemName: mode.symbolName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 86)
            .help(L10n.text(.viewMode, for: browser.language))

            Menu {
                Picker(L10n.text(.sortBy, for: browser.language), selection: sortFieldBinding) {
                    ForEach(FileSortField.allCases) { field in
                        Text(field.title(for: browser.language)).tag(field)
                    }
                }

                Picker(L10n.text(.sortDirection, for: browser.language), selection: sortDirectionBinding) {
                    ForEach(SortDirection.allCases, id: \.self) { direction in
                        Text(direction.title(for: browser.language)).tag(direction)
                    }
                }

                Divider()

                Toggle(L10n.text(.foldersFirst, for: browser.language), isOn: foldersFirstBinding)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .help(L10n.text(.sortBy, for: browser.language))

            Toggle(isOn: $browser.showHiddenFiles) {
                Image(systemName: "eye.slash")
            }
            .toggleStyle(.button)
            .help(L10n.text(.showHiddenFiles, for: browser.language))

            Toggle(isOn: $browser.showFileExtensions) {
                Image(systemName: "doc.text")
            }
            .toggleStyle(.button)
            .help(L10n.text(.showFileExtensions, for: browser.language))

            Toggle(isOn: $browser.isShowingDetailsPanel) {
                Image(systemName: "sidebar.right")
            }
            .toggleStyle(.button)
            .help(L10n.text(.detailsPanel, for: browser.language))

            IconButton(symbolName: "eye", title: L10n.text(.quickLook, for: browser.language), isDisabled: !browser.hasSelection) {
                browser.previewSelectedItems()
            }

            Toggle(isOn: $browser.isShowingSearchFilters) {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .toggleStyle(.button)
            .help(L10n.text(.searchFilters, for: browser.language))

            Spacer()

            IconButton(
                symbolName: "folder.badge.plus",
                title: L10n.text(.newFolder, for: browser.language),
                isDisabled: !browser.canStartFileOperation
            ) {
                Task { await browser.createFolderFromPrompt() }
            }

            Picker(L10n.text(.searchScope, for: browser.language), selection: $browser.searchScope) {
                ForEach(SearchScope.allCases) { scope in
                    Text(scope.title(for: browser.language)).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 132)
            .help(L10n.text(.searchScope, for: browser.language))

            Menu {
                Picker(L10n.text(.language, for: browser.language), selection: $browser.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
            } label: {
                Image(systemName: "globe")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .help(L10n.text(.language, for: browser.language))

            SearchFieldView()
                .frame(width: 230)
        }
        .frame(height: AppTheme.toolbarHeight)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sortFieldBinding: Binding<FileSortField> {
        Binding(
            get: { browser.sort.field },
            set: { browser.updateSortField($0) }
        )
    }

    private var sortDirectionBinding: Binding<SortDirection> {
        Binding(
            get: { browser.sort.direction },
            set: { browser.updateSortDirection($0) }
        )
    }

    private var foldersFirstBinding: Binding<Bool> {
        Binding(
            get: { browser.sort.foldersFirst },
            set: { browser.updateFoldersFirst($0) }
        )
    }
}
