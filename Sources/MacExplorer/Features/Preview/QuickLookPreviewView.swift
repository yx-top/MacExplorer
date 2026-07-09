import Quartz
import SwiftUI

struct QuickLookPreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView(frame: .zero, style: .normal)
        previewView?.autostarts = true
        return previewView ?? QLPreviewView()
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
        nsView.refreshPreviewItem()
    }
}

