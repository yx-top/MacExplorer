import SwiftUI
import UniformTypeIdentifiers

struct TabBarView: View {
    @EnvironmentObject private var browser: BrowserStore
    @State private var draggedTabID: BrowserTab.ID?
    @State private var dropTargetTabID: BrowserTab.ID?

    private static let tabDragType = UTType(exportedAs: "com.maceexplorer.tab")

    var body: some View {
        HStack(spacing: 4) {
            ForEach(browser.tabs) { tab in
                Button {
                    browser.selectTab(tab.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 12, weight: .medium))
                        Text(tab.title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if browser.tabs.count > 1 && tab.id == browser.selectedTabID {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .onTapGesture {
                                    browser.closeSelectedTab()
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .frame(maxWidth: 190)
                    .background(tab.id == browser.selectedTabID ? AppTheme.selectedFill : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        if dropTargetTabID == tab.id && draggedTabID != tab.id {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.primary.opacity(0.22), lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .onDrag {
                    draggedTabID = tab.id

                    let provider = NSItemProvider()
                    provider.registerDataRepresentation(
                        forTypeIdentifier: Self.tabDragType.identifier,
                        visibility: .ownProcess
                    ) { completion in
                        completion(Data(tab.id.uuidString.utf8), nil)
                        return nil
                    }
                    return provider
                }
                .onDrop(
                    of: [Self.tabDragType],
                    delegate: TabDropDelegate(
                        targetTabID: tab.id,
                        draggedTabID: $draggedTabID,
                        dropTargetTabID: $dropTargetTabID,
                        browser: browser
                    )
                )
                .contextMenu {
                    Button(L10n.text(.duplicateTab, for: browser.language)) {
                        browser.duplicateTab(tab.id)
                    }

                    Divider()

                    Button(L10n.text(.closeTab, for: browser.language)) {
                        browser.closeTab(tab.id)
                    }
                    .disabled(!browser.canCloseTab(tab.id))

                    Button(L10n.text(.closeOtherTabs, for: browser.language)) {
                        browser.closeOtherTabs(keeping: tab.id)
                    }
                    .disabled(!browser.canCloseOtherTabs(keeping: tab.id))

                    Button(L10n.text(.closeTabsToRight, for: browser.language)) {
                        browser.closeTabsToRight(of: tab.id)
                    }
                    .disabled(!browser.canCloseTabsToRight(of: tab.id))
                }
            }

            IconButton(symbolName: "plus", title: L10n.text(.newTab, for: browser.language)) {
                browser.createTab()
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

@MainActor
private struct TabDropDelegate: DropDelegate {
    let targetTabID: BrowserTab.ID
    @Binding var draggedTabID: BrowserTab.ID?
    @Binding var dropTargetTabID: BrowserTab.ID?
    let browser: BrowserStore

    func validateDrop(info: DropInfo) -> Bool {
        draggedTabID != nil
    }

    func dropEntered(info: DropInfo) {
        dropTargetTabID = targetTabID

        guard let sourceID = draggedTabID, sourceID != targetTabID else { return }
        withAnimation(.easeInOut(duration: 0.12)) {
            browser.moveTab(sourceID, to: targetTabID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetTabID == targetTabID {
            dropTargetTabID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTabID = nil
        dropTargetTabID = nil
        return true
    }
}
