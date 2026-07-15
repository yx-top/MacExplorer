import Foundation
import UniformTypeIdentifiers

@MainActor
func loadDroppedFileURLs(from providers: [NSItemProvider]) async -> [URL] {
    var urls: [URL] = []

    for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        if let url = await loadFileURL(from: provider) {
            urls.append(url)
        }
    }

    return urls
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
