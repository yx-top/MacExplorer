import Foundation

struct SearchOutcome: Sendable {
    let items: [FileItem]
    let scannedItemCount: Int
    let skippedDirectoryCount: Int
    let isLimited: Bool
}

struct SearchProgress: Sendable {
    let items: [FileItem]
    let scannedItemCount: Int
    let skippedDirectoryCount: Int
    let isLimited: Bool
    let isFinished: Bool
}

struct SearchService: Sendable {
    static let defaultResultLimit = 5_000

    private static let progressScanInterval = 150
    private static let resultBatchSize = 64

    func search(in rootURL: URL, query: String, filters: SearchFilters, showHidden: Bool, sort: FileSort, language: AppLanguage) async throws -> SearchOutcome {
        var latestProgress = SearchProgress(items: [], scannedItemCount: 0, skippedDirectoryCount: 0, isLimited: false, isFinished: true)

        for try await progress in searchProgress(
            in: rootURL,
            query: query,
            filters: filters,
            showHidden: showHidden,
            sort: sort,
            language: language
        ) {
            latestProgress = progress
        }

        return SearchOutcome(
            items: latestProgress.items,
            scannedItemCount: latestProgress.scannedItemCount,
            skippedDirectoryCount: latestProgress.skippedDirectoryCount,
            isLimited: latestProgress.isLimited
        )
    }

    func searchProgress(
        in rootURL: URL,
        query: String,
        filters: SearchFilters,
        showHidden: Bool,
        sort: FileSort,
        language: AppLanguage,
        resultLimit: Int = SearchService.defaultResultLimit
    ) -> AsyncThrowingStream<SearchProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    let outcome = try Self.performSearch(
                        in: rootURL,
                        query: query,
                        filters: filters,
                        showHidden: showHidden,
                        sort: sort,
                        language: language,
                        resultLimit: resultLimit
                    ) { progress in
                        continuation.yield(progress)
                    }

                    continuation.yield(
                        SearchProgress(
                            items: outcome.items,
                            scannedItemCount: outcome.scannedItemCount,
                            skippedDirectoryCount: outcome.skippedDirectoryCount,
                            isLimited: outcome.isLimited,
                            isFinished: true
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private static func performSearch(
        in rootURL: URL,
        query: String,
        filters: SearchFilters,
        showHidden: Bool,
        sort: FileSort,
        language: AppLanguage,
        resultLimit: Int,
        progress: @Sendable (SearchProgress) -> Void
    ) throws -> SearchOutcome {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty || filters.isActive else {
            return SearchOutcome(items: [], scannedItemCount: 0, skippedDirectoryCount: 0, isLimited: false)
        }

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isPackageKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .isHiddenKey,
            .isReadableKey,
            .isWritableKey,
            .isExecutableKey,
            .localizedTypeDescriptionKey
        ]

        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]

        if !showHidden {
            options.insert(.skipsHiddenFiles)
        }

        var skippedDirectoryCount = 0
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: options
        ) { _, _ in
            skippedDirectoryCount += 1
            return true
        }
        guard let enumerator else {
            return SearchOutcome(items: [], scannedItemCount: 0, skippedDirectoryCount: 1, isLimited: false)
        }

        if let rootReachable = try? rootURL.checkResourceIsReachable(), !rootReachable {
            return SearchOutcome(items: [], scannedItemCount: 0, skippedDirectoryCount: 1, isLimited: false)
        }

        let standardizedRootURL = rootURL.standardizedFileURL
        let limitedResultCount = max(1, resultLimit)
        var results: [FileItem] = []
        var scannedItemCount = 0
        var lastProgressScanCount = 0
        var lastProgressResultCount = 0
        var isLimited = false

        while let next = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            scannedItemCount += 1

            guard let values = try? next.resourceValues(forKeys: keys) else {
                skippedDirectoryCount += 1
                enumerator.skipDescendants()
                continue
            }

            let isHidden = values.isHidden ?? next.lastPathComponent.hasPrefix(".")
            if isHidden && !showHidden {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            let item = Self.fileItem(for: next, values: values, language: language)
            let locationText = Self.relativeSearchText(for: next, rootURL: standardizedRootURL)
            if SearchMatcher.matches(item, query: trimmedQuery, additionalText: locationText),
               filters.matches(item) {
                results.append(item)
            }

            if results.count >= limitedResultCount {
                isLimited = true
                break
            }

            let scannedSinceLastProgress = scannedItemCount - lastProgressScanCount
            let resultsSinceLastProgress = results.count - lastProgressResultCount
            if scannedSinceLastProgress >= progressScanInterval || resultsSinceLastProgress >= resultBatchSize {
                progress(
                    SearchProgress(
                        items: Self.sorted(results, by: sort),
                        scannedItemCount: scannedItemCount,
                        skippedDirectoryCount: skippedDirectoryCount,
                        isLimited: false,
                        isFinished: false
                    )
                )
                lastProgressScanCount = scannedItemCount
                lastProgressResultCount = results.count
            }
        }

        return SearchOutcome(
            items: Self.sorted(results, by: sort),
            scannedItemCount: scannedItemCount,
            skippedDirectoryCount: skippedDirectoryCount,
            isLimited: isLimited
        )
    }

    private static func fileItem(for url: URL, values: URLResourceValues?, language: AppLanguage) -> FileItem {
        let isPackage = values?.isPackage ?? false
        let isDirectory = (values?.isDirectory ?? false) && !isPackage
        let typeDescription = values?.localizedTypeDescription
            ?? L10n.fallbackFileType(isDirectory: isDirectory, fileExtension: url.pathExtension, for: language)

        return FileItem(
            url: url,
            name: url.lastPathComponent,
            isDirectory: isDirectory,
            isPackage: isPackage,
            fileSize: values?.fileSize.map(Int64.init),
            modificationDate: values?.contentModificationDate,
            creationDate: values?.creationDate,
            typeDescription: typeDescription,
            isHidden: values?.isHidden ?? url.lastPathComponent.hasPrefix("."),
            isReadable: values?.isReadable,
            isWritable: values?.isWritable,
            isExecutable: values?.isExecutable
        )
    }

    private static func relativeSearchText(for url: URL, rootURL: URL) -> [String] {
        let itemURL = url.standardizedFileURL
        let parentURL = itemURL.deletingLastPathComponent().standardizedFileURL
        let rootPath = rootURL.standardizedFileURL.path
        let parentPath = parentURL.path
        let rootPrefix = rootPath == "/" ? "/" : rootPath + "/"

        guard parentPath != rootPath, parentPath.hasPrefix(rootPrefix) else {
            return []
        }

        let relativeParentPath = String(parentPath.dropFirst(rootPrefix.count))
        guard !relativeParentPath.isEmpty else { return [] }

        return [
            relativeParentPath,
            relativeParentPath.replacingOccurrences(of: "/", with: " "),
            relativeParentPath + "/" + itemURL.lastPathComponent
        ]
    }

    private static func sorted(_ items: [FileItem], by sort: FileSort) -> [FileItem] {
        items.sorted { left, right in
            if sort.foldersFirst, left.isDirectory != right.isDirectory {
                return left.isDirectory
            }

            let comparison: ComparisonResult = {
                switch sort.field {
                case .name:
                    return left.displayName.localizedStandardCompare(right.displayName)
                case .type:
                    return left.typeDescription.localizedStandardCompare(right.typeDescription)
                case .size:
                    return compare(left.fileSize ?? -1, right.fileSize ?? -1)
                case .modified:
                    return compare(left.modificationDate ?? .distantPast, right.modificationDate ?? .distantPast)
                case .created:
                    return compare(left.creationDate ?? .distantPast, right.creationDate ?? .distantPast)
                }
            }()

            if comparison == .orderedSame {
                return left.displayName.localizedStandardCompare(right.displayName) == .orderedAscending
            }

            return sort.direction == .ascending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }
    }

    private static func compare<T: Comparable>(_ left: T, _ right: T) -> ComparisonResult {
        if left == right { return .orderedSame }
        return left < right ? .orderedAscending : .orderedDescending
    }
}
