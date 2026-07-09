import AppKit
import Foundation

enum FileOperationServiceError: LocalizedError, Sendable {
    case invalidFileName
    case createFileFailed(String)
    case cannotTransferItemIntoItself(String)

    var errorDescription: String? {
        message(for: .english)
    }

    func message(for language: AppLanguage) -> String {
        switch self {
        case .invalidFileName:
            switch language {
            case .chinese: "名称不能为空，且不能包含斜杠。"
            case .english: "The name cannot be empty or contain a slash."
            }
        case .createFileFailed(let name):
            switch language {
            case .chinese: "无法创建 \(name)。"
            case .english: "Could not create \(name)."
            }
        case .cannotTransferItemIntoItself(let name):
            switch language {
            case .chinese: "不能将 \(name) 复制或移动到它自身或其子文件夹中。"
            case .english: "Cannot copy or move \(name) into itself or one of its subfolders."
            }
        }
    }
}

@MainActor
struct FileOperationService {
    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func open(_ url: URL, withApplicationAt applicationURL: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openInTerminal(_ url: URL) {
        let target = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        let escapedPath = target.path.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(escapedPath)'"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    func moveToTrash(_ urls: [URL]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.recycle(urls) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func permanentlyDelete(
        _ urls: [URL],
        progress: (@Sendable (FileOperationProgress) async -> Void)? = nil
    ) async throws -> [URL] {
        try await Task.detached(priority: .userInitiated) {
            var deletedURLs: [URL] = []

            for (index, url) in urls.enumerated() {
                try Task.checkCancellation()
                await progress?(
                    FileOperationProgress(
                        totalItems: urls.count,
                        completedItems: index,
                        currentItemName: url.lastPathComponent
                    )
                )
                try FileManager.default.removeItem(at: url)
                deletedURLs.append(url)
                await progress?(
                    FileOperationProgress(
                        totalItems: urls.count,
                        completedItems: index + 1,
                        currentItemName: url.lastPathComponent
                    )
                )
            }

            return deletedURLs
        }.value
    }

    func createFolder(named name: String, in directory: URL) throws -> URL {
        let validName = try Self.validatedFileName(name)
        let folderURL = uniqueDestination(for: directory.appendingPathComponent(validName, isDirectory: true))
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        return folderURL
    }

    func createEmptyFile(named name: String, in directory: URL) throws -> URL {
        let validName = try Self.validatedFileName(name)
        let fileURL = uniqueDestination(for: directory.appendingPathComponent(validName, isDirectory: false))
        guard FileManager.default.createFile(atPath: fileURL.path, contents: Data()) else {
            throw FileOperationServiceError.createFileFailed(fileURL.lastPathComponent)
        }
        return fileURL
    }

    func rename(_ url: URL, to newName: String) throws -> URL {
        let validName = try Self.validatedFileName(newName)
        let destination = url.deletingLastPathComponent().appendingPathComponent(validName)
        if destination.standardizedFileURL == url.standardizedFileURL {
            return url
        }
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }

    func copyItems(
        _ urls: [URL],
        to directory: URL,
        conflictResolution: FileConflictResolution,
        progress: (@Sendable (FileOperationProgress) async -> Void)? = nil
    ) async throws -> [URL] {
        try await Task.detached(priority: .userInitiated) {
            try Self.validateTransferSources(urls, to: directory)

            var destinations: [URL] = []
            for (index, source) in urls.enumerated() {
                try Task.checkCancellation()
                await progress?(FileOperationProgress(totalItems: urls.count, completedItems: index, currentItemName: source.lastPathComponent))
                let proposed = directory.appendingPathComponent(source.lastPathComponent, isDirectory: source.hasDirectoryPath)
                guard let resolvedDestination = try Self.resolvedDestination(
                    proposedURL: proposed,
                    sourceURL: source,
                    operation: .copy,
                    conflictResolution: conflictResolution
                ) else {
                    await progress?(FileOperationProgress(totalItems: urls.count, completedItems: index + 1, currentItemName: source.lastPathComponent))
                    continue
                }
                try Task.checkCancellation()
                try Self.copyItem(at: source, to: resolvedDestination)
                destinations.append(resolvedDestination.url)
                await progress?(FileOperationProgress(totalItems: urls.count, completedItems: index + 1, currentItemName: source.lastPathComponent))
            }
            return destinations
        }.value
    }

    func moveItems(
        _ urls: [URL],
        to directory: URL,
        conflictResolution: FileConflictResolution,
        progress: (@Sendable (FileOperationProgress) async -> Void)? = nil
    ) async throws -> [URL] {
        try await Task.detached(priority: .userInitiated) {
            try Self.validateTransferSources(urls, to: directory)

            var destinations: [URL] = []
            for (index, source) in urls.enumerated() {
                try Task.checkCancellation()
                await progress?(FileOperationProgress(totalItems: urls.count, completedItems: index, currentItemName: source.lastPathComponent))
                guard source.deletingLastPathComponent().standardizedFileURL != directory.standardizedFileURL else {
                    destinations.append(source)
                    await progress?(FileOperationProgress(totalItems: urls.count, completedItems: index + 1, currentItemName: source.lastPathComponent))
                    continue
                }
                let proposed = directory.appendingPathComponent(source.lastPathComponent, isDirectory: source.hasDirectoryPath)
                guard let resolvedDestination = try Self.resolvedDestination(
                    proposedURL: proposed,
                    sourceURL: source,
                    operation: .cut,
                    conflictResolution: conflictResolution
                ) else {
                    await progress?(FileOperationProgress(totalItems: urls.count, completedItems: index + 1, currentItemName: source.lastPathComponent))
                    continue
                }
                try Task.checkCancellation()
                try Self.moveItem(at: source, to: resolvedDestination)
                destinations.append(resolvedDestination.url)
                await progress?(FileOperationProgress(totalItems: urls.count, completedItems: index + 1, currentItemName: source.lastPathComponent))
            }
            return destinations
        }.value
    }

    private nonisolated struct ResolvedDestination: Sendable {
        let url: URL
        let replacesExistingItem: Bool
    }

    private nonisolated static func validatedFileName(_ name: String) throws -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              trimmedName != ".",
              trimmedName != "..",
              !trimmedName.contains("/") else {
            throw FileOperationServiceError.invalidFileName
        }

        return trimmedName
    }

    private nonisolated static func validateTransferSources(_ urls: [URL], to directory: URL) throws {
        let destinationDirectory = directory.standardizedFileURL.resolvingSymlinksInPath()

        for source in urls {
            let sourceURL = source.standardizedFileURL.resolvingSymlinksInPath()
            guard isDirectory(sourceURL),
                  isSameOrDescendant(destinationDirectory, of: sourceURL) else {
                continue
            }

            throw FileOperationServiceError.cannotTransferItemIntoItself(source.lastPathComponent)
        }
    }

    private nonisolated func uniqueDestination(for proposedURL: URL) -> URL {
        Self.uniqueDestination(for: proposedURL)
    }

    private nonisolated static func uniqueDestination(for proposedURL: URL) -> URL {
        guard FileManager.default.fileExists(atPath: proposedURL.path) else {
            return proposedURL
        }

        let directory = proposedURL.deletingLastPathComponent()
        let treatsAsDirectory = proposedURL.hasDirectoryPath || isDirectory(proposedURL)
        let baseName = treatsAsDirectory ? proposedURL.lastPathComponent : proposedURL.deletingPathExtension().lastPathComponent
        let fileExtension = treatsAsDirectory ? "" : proposedURL.pathExtension

        for index in 1...9999 {
            let suffix = index == 1 ? " copy" : " copy \(index)"
            let candidateName = baseName + suffix
            let candidate = fileExtension.isEmpty
                ? directory.appendingPathComponent(candidateName)
                : directory.appendingPathComponent(candidateName).appendingPathExtension(fileExtension)

            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
    }

    private nonisolated static func resolvedDestination(
        proposedURL: URL,
        sourceURL: URL,
        operation: FileClipboardOperation,
        conflictResolution: FileConflictResolution
    ) throws -> ResolvedDestination? {
        guard FileManager.default.fileExists(atPath: proposedURL.path) else {
            return ResolvedDestination(url: proposedURL, replacesExistingItem: false)
        }

        if proposedURL.standardizedFileURL == sourceURL.standardizedFileURL {
            return operation == .copy
                ? ResolvedDestination(url: uniqueDestination(for: proposedURL), replacesExistingItem: false)
                : nil
        }

        switch conflictResolution {
        case .keepBoth:
            return ResolvedDestination(url: uniqueDestination(for: proposedURL), replacesExistingItem: false)
        case .replace:
            return ResolvedDestination(url: proposedURL, replacesExistingItem: true)
        case .skip:
            return nil
        }
    }

    private nonisolated static func copyItem(at source: URL, to destination: ResolvedDestination) throws {
        guard destination.replacesExistingItem else {
            try FileManager.default.copyItem(at: source, to: destination.url)
            return
        }

        let temporaryCopy = temporaryURL(in: destination.url.deletingLastPathComponent(), isDirectory: source.hasDirectoryPath)
        do {
            try FileManager.default.copyItem(at: source, to: temporaryCopy)
            try replaceExistingItem(at: destination.url, with: temporaryCopy)
        } catch {
            try? FileManager.default.removeItem(at: temporaryCopy)
            throw error
        }
    }

    private nonisolated static func moveItem(at source: URL, to destination: ResolvedDestination) throws {
        guard destination.replacesExistingItem else {
            try FileManager.default.moveItem(at: source, to: destination.url)
            return
        }

        try replaceExistingItem(at: destination.url, with: source)
    }

    private nonisolated static func replaceExistingItem(at destination: URL, with replacement: URL) throws {
        let backup = temporaryURL(in: destination.deletingLastPathComponent(), isDirectory: destination.hasDirectoryPath)
        try FileManager.default.moveItem(at: destination, to: backup)

        do {
            try FileManager.default.moveItem(at: replacement, to: destination)
            try? FileManager.default.removeItem(at: backup)
        } catch {
            if !FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.moveItem(at: backup, to: destination)
            }
            throw error
        }
    }

    private nonisolated static func temporaryURL(in directory: URL, isDirectory: Bool) -> URL {
        let name = ".MacExplorer-\(UUID().uuidString)"
        return directory.appendingPathComponent(name, isDirectory: isDirectory)
    }

    private nonisolated static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private nonisolated static func isSameOrDescendant(_ child: URL, of parent: URL) -> Bool {
        let childPath = child.standardizedFileURL.path
        let parentPath = parent.standardizedFileURL.path

        if childPath == parentPath {
            return true
        }

        let parentPrefix = parentPath == "/" ? "/" : parentPath + "/"
        return childPath.hasPrefix(parentPrefix)
    }
}
