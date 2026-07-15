import AppKit
import SwiftUI

struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedObject private var browserStore: BrowserStore?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L10n.text(.newWindow, for: language)) {
                openWindow(id: "browser")
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button(L10n.text(.newFolder, for: language)) {
                Task { await browserStore?.createFolderFromPrompt() }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(browserStore?.canStartFileOperation != true)

            Button(L10n.text(.newEmptyFile, for: language)) {
                Task { await browserStore?.createFileFromPrompt() }
            }
            .disabled(browserStore?.canStartFileOperation != true)

            Divider()

            Button(L10n.text(.newTab, for: language)) {
                browserStore?.createTab()
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(browserStore == nil)

            Button(L10n.text(.duplicateTab, for: language)) {
                browserStore?.duplicateSelectedTab()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(browserStore == nil)

            Button(L10n.text(.closeTab, for: language)) {
                browserStore?.closeSelectedTab()
            }
            .keyboardShortcut("w", modifiers: [.command, .control])
            .disabled(browserStore?.canCloseSelectedTab != true)
        }

        CommandGroup(after: .pasteboard) {
            Button(L10n.text(.copy, for: language)) {
                browserStore?.copySelectedItems()
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(browserStore?.hasSelection != true)

            Button(L10n.text(.cut, for: language)) {
                browserStore?.cutSelectedItems()
            }
            .keyboardShortcut("x", modifiers: .command)
            .disabled(browserStore?.hasSelection != true)

            Button(L10n.text(.paste, for: language)) {
                Task { await browserStore?.pasteItems() }
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(browserStore?.canPaste != true)

            Button(L10n.text(.open, for: language)) {
                Task { await browserStore?.openSelectedItems() }
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(browserStore?.selectedItems.count != 1)

            Button(L10n.text(.openWith, for: language)) {
                Task { await browserStore?.openSelectedWithApplicationFromPrompt() }
            }
            .disabled(browserStore?.selectedItems.count != 1)

            Button(L10n.text(.rename, for: language)) {
                Task { await browserStore?.renameSelectedFromPrompt() }
            }
            .keyboardShortcut(functionKey(NSF2FunctionKey), modifiers: [])
            .disabled(browserStore?.selectedItems.count != 1 || browserStore?.canStartFileOperation != true)

            Button(L10n.text(.moveToTrash, for: language)) {
                Task { await browserStore?.deleteSelectedToTrash() }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(browserStore?.hasSelection != true || browserStore?.canStartFileOperation != true)

            Button(L10n.text(.deletePermanently, for: language)) {
                Task { await browserStore?.deleteSelectedPermanently() }
            }
            .keyboardShortcut(.delete, modifiers: [.command, .option])
            .disabled(browserStore?.hasSelection != true || browserStore?.canStartFileOperation != true)

            Button(L10n.text(.quickLook, for: language)) {
                browserStore?.previewSelectedItems()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(browserStore?.hasSelection != true)

            Button(L10n.text(.selectAll, for: language)) {
                browserStore?.selectAll()
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(browserStore?.hasDisplayedItems != true)
        }

        CommandMenu(L10n.text(.selection, for: language)) {
            Button(L10n.text(.selectNextItem, for: language)) {
                browserStore?.moveSelection(by: 1)
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .disabled(browserStore?.hasDisplayedItems != true)

            Button(L10n.text(.selectPreviousItem, for: language)) {
                browserStore?.moveSelection(by: -1)
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .disabled(browserStore?.hasDisplayedItems != true)

            Button(L10n.text(.extendSelectionDown, for: language)) {
                browserStore?.moveSelection(by: 1, extending: true)
            }
            .keyboardShortcut(.downArrow, modifiers: .shift)
            .disabled(browserStore?.hasDisplayedItems != true)

            Button(L10n.text(.extendSelectionUp, for: language)) {
                browserStore?.moveSelection(by: -1, extending: true)
            }
            .keyboardShortcut(.upArrow, modifiers: .shift)
            .disabled(browserStore?.hasDisplayedItems != true)
        }

        CommandMenu(L10n.text(.navigation, for: language)) {
            Button(L10n.text(.back, for: language)) {
                Task { await browserStore?.goBack() }
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(browserStore?.canGoBack != true)

            Button(L10n.text(.forward, for: language)) {
                Task { await browserStore?.goForward() }
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(browserStore?.canGoForward != true)

            Button(L10n.text(.up, for: language)) {
                Task { await browserStore?.goUp() }
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
            .disabled(browserStore == nil)

            Button(L10n.text(.refresh, for: language)) {
                Task { await browserStore?.reload() }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(browserStore == nil)

            Divider()

            Button(L10n.text(.focusAddressBar, for: language)) {
                browserStore?.requestFocus(.addressBar)
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(browserStore == nil)

            Button(L10n.text(.focusSearch, for: language)) {
                browserStore?.requestFocus(.searchField)
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(browserStore == nil)

            Button(L10n.text(.focusFileArea, for: language)) {
                browserStore?.requestFocus(.fileArea)
            }
            .keyboardShortcut("0", modifiers: [.command, .option])
            .disabled(browserStore == nil)
        }

        CommandMenu(L10n.text(.display, for: language)) {
            Picker(L10n.text(.viewMode, for: language), selection: viewModeBinding) {
                ForEach(ExplorerViewMode.allCases) { mode in
                    Text(mode.title(for: language)).tag(mode)
                }
            }
            .disabled(browserStore == nil)

            Picker(L10n.text(.sortBy, for: language), selection: sortFieldBinding) {
                ForEach(FileSortField.allCases) { field in
                    Text(field.title(for: language)).tag(field)
                }
            }
            .disabled(browserStore == nil)

            Picker(L10n.text(.sortDirection, for: language), selection: sortDirectionBinding) {
                ForEach(SortDirection.allCases, id: \.self) { direction in
                    Text(direction.title(for: language)).tag(direction)
                }
            }
            .disabled(browserStore == nil)

            Toggle(L10n.text(.foldersFirst, for: language), isOn: foldersFirstBinding)
                .disabled(browserStore == nil)

            Divider()

            Toggle(L10n.text(.showHiddenFiles, for: language), isOn: showHiddenFilesBinding)
                .keyboardShortcut(".", modifiers: [.command, .shift])
                .disabled(browserStore == nil)

            Toggle(L10n.text(.showFileExtensions, for: language), isOn: showFileExtensionsBinding)
                .disabled(browserStore == nil)

            Toggle(L10n.text(.detailsPanel, for: language), isOn: detailsPanelBinding)
                .disabled(browserStore == nil)

            Divider()

            Picker(L10n.text(.language, for: language), selection: languageBinding) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .disabled(browserStore == nil)
        }
    }

    private var language: AppLanguage {
        browserStore?.language ?? .chinese
    }

    private func functionKey(_ value: Int) -> KeyEquivalent {
        KeyEquivalent(Character(UnicodeScalar(value)!))
    }

    private var viewModeBinding: Binding<ExplorerViewMode> {
        Binding(
            get: { browserStore?.viewMode ?? .details },
            set: { browserStore?.viewMode = $0 }
        )
    }

    private var sortFieldBinding: Binding<FileSortField> {
        Binding(
            get: { browserStore?.sort.field ?? .name },
            set: { browserStore?.updateSortField($0) }
        )
    }

    private var sortDirectionBinding: Binding<SortDirection> {
        Binding(
            get: { browserStore?.sort.direction ?? .ascending },
            set: { browserStore?.updateSortDirection($0) }
        )
    }

    private var foldersFirstBinding: Binding<Bool> {
        Binding(
            get: { browserStore?.sort.foldersFirst ?? true },
            set: { browserStore?.updateFoldersFirst($0) }
        )
    }

    private var showHiddenFilesBinding: Binding<Bool> {
        Binding(
            get: { browserStore?.showHiddenFiles ?? false },
            set: { browserStore?.showHiddenFiles = $0 }
        )
    }

    private var showFileExtensionsBinding: Binding<Bool> {
        Binding(
            get: { browserStore?.showFileExtensions ?? true },
            set: { browserStore?.showFileExtensions = $0 }
        )
    }

    private var detailsPanelBinding: Binding<Bool> {
        Binding(
            get: { browserStore?.isShowingDetailsPanel ?? true },
            set: { browserStore?.isShowingDetailsPanel = $0 }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { browserStore?.language ?? .chinese },
            set: { browserStore?.language = $0 }
        )
    }
}
