import Foundation

struct FileSystemService: Sendable {
    func contents(of directoryURL: URL, showHidden: Bool, sort: FileSort, language: AppLanguage) async throws -> [FileItem] {
        try await Task.detached(priority: .userInitiated) {
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

            let urls = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: Array(keys),
                options: options
            )

            let items = urls.compactMap { url -> FileItem? in
                let values = try? url.resourceValues(forKeys: keys)
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

            return Self.sorted(items, by: sort)
        }.value
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

            if sort.direction == .ascending {
                return comparison == .orderedAscending
            } else {
                return comparison == .orderedDescending
            }
        }
    }

    private static func compare<T: Comparable>(_ left: T, _ right: T) -> ComparisonResult {
        if left == right { return .orderedSame }
        return left < right ? .orderedAscending : .orderedDescending
    }
}
