import Foundation
import Quartz

@MainActor
final class QuickLookService: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var previewURLs: [URL] = []

    func show(urls: [URL]) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        previewURLs = urls
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURLs.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURLs[index] as NSURL
    }
}
