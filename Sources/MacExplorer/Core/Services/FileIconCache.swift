import AppKit
import Foundation

@MainActor
final class FileIconCache {
    static let shared = FileIconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 2_048
        cache.totalCostLimit = 64 * 1_024 * 1_024
    }

    func icon(for url: URL) -> NSImage {
        let key = cacheKey(for: url)
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(icon, forKey: key, cost: estimatedCost(of: icon))
        return icon
    }

    private func cacheKey(for url: URL) -> NSString {
        url.standardizedFileURL.path as NSString
    }

    private func estimatedCost(of image: NSImage) -> Int {
        let pixelCount = image.representations
            .map { max($0.pixelsWide, 1) * max($0.pixelsHigh, 1) }
            .max() ?? 1
        return pixelCount * 4
    }
}
