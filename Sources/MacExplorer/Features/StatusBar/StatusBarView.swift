import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var browser: BrowserStore
    @State private var isShowingOperationCenter = false

    var body: some View {
        HStack(spacing: 14) {
            Text(L10n.itemCount(browser.displayedItems.count, for: browser.language))

            if browser.isSearching {
                Label(L10n.text(.searching, for: browser.language), systemImage: "magnifyingglass")
            }

            if browser.searchScope == .recursive && browser.isSearchActive {
                Text(L10n.text(.recursiveSearch, for: browser.language))
            }

            if browser.scannedSearchItemCount > 0 && browser.isRecursiveSearchActive {
                Label(
                    L10n.scannedSearchItems(browser.scannedSearchItemCount, for: browser.language),
                    systemImage: "doc.text.magnifyingglass"
                )
            }

            if browser.skippedSearchDirectoryCount > 0 {
                Label(
                    L10n.skippedSearchLocations(browser.skippedSearchDirectoryCount, for: browser.language),
                    systemImage: "exclamationmark.triangle"
                )
            }

            if browser.isSearchResultLimited {
                Label(
                    L10n.searchResultLimitReached(browser.searchResultLimit, for: browser.language),
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }

            if !browser.selectedItems.isEmpty {
                Text(L10n.selectedCount(browser.selectedItems.count, for: browser.language))
                Text(selectedSize)
            }

            if browser.showHiddenFiles {
                Label(L10n.text(.hiddenFilesVisible, for: browser.language), systemImage: "eye")
            }

            if let operationMessage = browser.operationMessage {
                Text(operationMessage)
                    .foregroundStyle(.primary)
            }

            Spacer()

            if let activeOperation = browser.activeOperation {
                OperationProgressPill(operation: activeOperation, language: browser.language, canCancel: browser.canCancelActiveOperation) {
                    browser.cancelActiveOperation()
                }
            }

            if !browser.operationHistory.isEmpty {
                Button {
                    isShowingOperationCenter.toggle()
                } label: {
                    OperationCenterButton(count: browser.operationHistory.count, hasRunningOperation: browser.activeOperation?.state == .running)
                }
                .buttonStyle(.plain)
                .help(L10n.text(.operationCenter, for: browser.language))
                .popover(isPresented: $isShowingOperationCenter, arrowEdge: .bottom) {
                    OperationCenterView()
                        .environmentObject(browser)
                }
            }

            Text(browser.currentURL.path)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: AppTheme.statusBarHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var selectedSize: String {
        let total = browser.selectedItems.compactMap(\.fileSize).reduce(Int64(0), +)
        return ExplorerFormatters.fileSize(total)
    }
}

private struct OperationCenterButton: View {
    let count: Int
    let hasRunningOperation: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .symbolEffect(.pulse, options: .repeating, value: hasRunningOperation)

            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .padding(.horizontal, 5)
                .frame(height: 16)
                .background(Color.primary.opacity(0.07), in: Capsule())
        }
        .padding(.horizontal, 6)
        .frame(height: 20)
        .background(hasRunningOperation ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct OperationCenterView: View {
    @EnvironmentObject private var browser: BrowserStore

    private var recentOperations: [FileOperationTask] {
        browser.operationHistory.filter { operation in
            operation.id != browser.activeOperation?.id
        }
    }

    private var hasCompletedOperations: Bool {
        browser.operationHistory.contains { $0.state.isTerminal }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text(.operationCenter, for: browser.language))
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.itemCount(browser.operationHistory.count, for: browser.language))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(L10n.text(.clearCompleted, for: browser.language)) {
                    browser.clearCompletedOperations()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(!hasCompletedOperations)

                Button(L10n.text(.clear, for: browser.language)) {
                    browser.clearOperationHistory()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                if let activeOperation = browser.activeOperation {
                    OperationCenterSectionTitle(title: L10n.text(.activeOperation, for: browser.language))
                    OperationCenterCard(
                        operation: activeOperation,
                        language: browser.language,
                        isProminent: true,
                        canCancel: browser.canCancelActiveOperation
                    ) {
                        browser.cancelActiveOperation()
                    }
                }

                if recentOperations.isEmpty && browser.activeOperation == nil {
                    ContentUnavailableView(
                        L10n.text(.noOperations, for: browser.language),
                        systemImage: "clock",
                        description: Text(L10n.text(.operationHistory, for: browser.language))
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else if !recentOperations.isEmpty {
                    OperationCenterSectionTitle(title: L10n.text(.recentOperations, for: browser.language))

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(recentOperations) { operation in
                                OperationCenterCard(operation: operation, language: browser.language, isProminent: false)
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .frame(maxHeight: browser.activeOperation == nil ? 310 : 220)
                }
            }
            .padding(14)
        }
        .frame(width: 430)
    }
}

private struct OperationCenterSectionTitle: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

private struct OperationCenterCard: View {
    let operation: FileOperationTask
    let language: AppLanguage
    let isProminent: Bool
    var canCancel = false
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: isProminent ? 16 : 14, weight: .semibold))
                    .foregroundStyle(symbolColor)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(operation.summary(for: language))
                        .font(.system(size: isProminent ? 13 : 12, weight: .semibold))
                        .lineLimit(2)
                        .truncationMode(.middle)

                    HStack(spacing: 8) {
                        OperationStateBadge(state: operation.state, language: language)
                        Text("\(L10n.text(.updated, for: language)) \(ExplorerFormatters.time(operation.updatedAt))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if operation.state == .running, canCancel, let onCancel {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.text(.cancelOperation, for: language))
                }
            }

            HStack(spacing: 10) {
                ProgressView(value: operation.progress)
                    .progressViewStyle(.linear)

                Text("\(operation.completedItems)/\(operation.totalItems)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .padding(10)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.subtleLine)
        )
    }

    private var cardBackground: Color {
        if isProminent {
            return Color.accentColor.opacity(0.08)
        }

        return Color.primary.opacity(0.035)
    }

    private var symbolName: String {
        switch operation.state {
        case .running:
            return "arrow.triangle.2.circlepath"
        case .finished:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .canceled:
            return "xmark.circle.fill"
        }
    }

    private var symbolColor: Color {
        switch operation.state {
        case .running:
            return .accentColor
        case .finished:
            return .green
        case .failed:
            return .red
        case .canceled:
            return .orange
        }
    }
}

private struct OperationStateBadge: View {
    let state: FileOperationState
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 9, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .frame(height: 18)
        .background(color.opacity(0.12), in: Capsule())
    }

    private var title: String {
        switch state {
        case .running:
            return L10n.text(.running, for: language)
        case .finished:
            return L10n.text(.finished, for: language)
        case .failed:
            return L10n.text(.failed, for: language)
        case .canceled:
            return L10n.text(.canceled, for: language)
        }
    }

    private var symbolName: String {
        switch state {
        case .running:
            return "arrow.triangle.2.circlepath"
        case .finished:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        case .canceled:
            return "xmark.circle"
        }
    }

    private var color: Color {
        switch state {
        case .running:
            return .accentColor
        case .finished:
            return .green
        case .failed:
            return .red
        case .canceled:
            return .orange
        }
    }
}

private struct OperationProgressPill: View {
    let operation: FileOperationTask
    let language: AppLanguage
    let canCancel: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))

            Text(operation.summary(for: language))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 180, alignment: .leading)

            ProgressView(value: operation.progress)
                .progressViewStyle(.linear)
                .frame(width: 82)

            Text("\(operation.completedItems)/\(operation.totalItems)")
                .monospacedDigit()
                .foregroundStyle(.secondary)

            if operation.state == .running && canCancel {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .help(L10n.text(.cancelOperation, for: language))
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 9)
        .frame(height: 20)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppTheme.subtleLine)
        )
    }

    private var symbolName: String {
        switch operation.state {
        case .running:
            return "arrow.triangle.2.circlepath"
        case .finished:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        case .canceled:
            return "xmark.circle"
        }
    }

    private var backgroundColor: Color {
        switch operation.state {
        case .running:
            return Color.accentColor.opacity(0.10)
        case .finished:
            return Color.green.opacity(0.12)
        case .failed:
            return Color.red.opacity(0.12)
        case .canceled:
            return Color.orange.opacity(0.12)
        }
    }
}
