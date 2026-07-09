import Foundation

struct FolderStatistics: Equatable, Sendable {
    let fileCount: Int
    let folderCount: Int
    let totalSize: Int64
    let skippedDirectoryCount: Int
}

struct FolderStatisticsService: Sendable {
    func statistics(for rootURL: URL) async throws -> FolderStatistics {
        try await Task.detached(priority: .utility) {
            let keys: Set<URLResourceKey> = [
                .isDirectoryKey,
                .isPackageKey,
                .fileSizeKey,
                .totalFileSizeKey
            ]

            var skippedDirectoryCount = 0
            let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsPackageDescendants]
            ) { _, _ in
                skippedDirectoryCount += 1
                return true
            }

            guard let enumerator else {
                return FolderStatistics(fileCount: 0, folderCount: 0, totalSize: 0, skippedDirectoryCount: 1)
            }

            var fileCount = 0
            var folderCount = 0
            var totalSize: Int64 = 0

            while let url = enumerator.nextObject() as? URL {
                try Task.checkCancellation()

                guard let values = try? url.resourceValues(forKeys: keys) else {
                    skippedDirectoryCount += 1
                    enumerator.skipDescendants()
                    continue
                }

                let isPackage = values.isPackage ?? false
                let isDirectory = (values.isDirectory ?? false) && !isPackage

                if isDirectory {
                    folderCount += 1
                } else {
                    fileCount += 1
                    totalSize += Int64(values.totalFileSize ?? values.fileSize ?? 0)
                }
            }

            return FolderStatistics(
                fileCount: fileCount,
                folderCount: folderCount,
                totalSize: totalSize,
                skippedDirectoryCount: skippedDirectoryCount
            )
        }.value
    }
}
