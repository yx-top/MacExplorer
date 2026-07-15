import Foundation
import UniformTypeIdentifiers

let macExplorerDraggedFileURLsType = UTType(exportedAs: "top.yx.macexplorer.dragged-file-urls")

@MainActor
func loadDroppedFileURLs(from providers: [NSItemProvider]) async -> [URL] {
    let internalURLs = await loadInternalDraggedFileURLs(from: providers)
    if !internalURLs.isEmpty {
        return internalURLs
    }

    var urls: [URL] = []

    for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        if let url = await loadFileURL(from: provider) {
            urls.append(url)
        }
    }

    return uniqueFileURLs(urls)
}

@MainActor
func makeFileDragItemProvider(for urls: [URL], fallbackURL: URL) -> NSItemProvider {
    let provider = NSItemProvider(object: fallbackURL as NSURL)
    let dragURLs = uniqueFileURLs(urls.isEmpty ? [fallbackURL] : urls)

    if let data = try? JSONEncoder().encode(dragURLs.map(\.path)) {
        provider.registerDataRepresentation(
            forTypeIdentifier: macExplorerDraggedFileURLsType.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(data, nil)
            return nil
        }
    }

    return provider
}

@MainActor
private func loadInternalDraggedFileURLs(from providers: [NSItemProvider]) async -> [URL] {
    var urls: [URL] = []

    for provider in providers where provider.hasItemConformingToTypeIdentifier(macExplorerDraggedFileURLsType.identifier) {
        urls.append(contentsOf: await loadInternalDraggedFileURLs(from: provider))
    }

    return uniqueFileURLs(urls)
}

@MainActor
private func loadInternalDraggedFileURLs(from provider: NSItemProvider) async -> [URL] {
    await withCheckedContinuation { continuation in
        provider.loadItem(forTypeIdentifier: macExplorerDraggedFileURLsType.identifier, options: nil) { item, _ in
            let data: Data?
            if let itemData = item as? Data {
                data = itemData
            } else if let itemData = item as? NSData {
                data = itemData as Data
            } else {
                data = nil
            }

            guard let data,
                  let paths = try? JSONDecoder().decode([String].self, from: data) else {
                continuation.resume(returning: [])
                return
            }

            continuation.resume(returning: paths.map { URL(fileURLWithPath: $0) })
        }
    }
}

@MainActor
private func loadFileURL(from provider: NSItemProvider) async -> URL? {
    await withCheckedContinuation { continuation in
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let url = item as? URL {
                continuation.resume(returning: url)
            } else if let nsURL = item as? NSURL {
                continuation.resume(returning: nsURL as URL)
            } else if let data = item as? Data {
                continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}

private func uniqueFileURLs(_ urls: [URL]) -> [URL] {
    var seen: Set<URL> = []
    var uniqueURLs: [URL] = []

    for url in urls {
        let standardizedURL = url.standardizedFileURL
        guard seen.insert(standardizedURL).inserted else { continue }
        uniqueURLs.append(standardizedURL)
    }

    return uniqueURLs
}
