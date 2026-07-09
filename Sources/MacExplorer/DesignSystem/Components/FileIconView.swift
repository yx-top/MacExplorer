import AppKit
import SwiftUI

struct FileIconView: View {
    let url: URL
    var size: CGFloat = 20

    var body: some View {
        Image(nsImage: FileIconCache.shared.icon(for: url))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
