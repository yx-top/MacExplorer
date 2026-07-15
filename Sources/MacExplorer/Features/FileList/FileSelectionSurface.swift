import SwiftUI

let fileSelectionCoordinateSpaceName = "MacExplorer.FileSelection"

struct FileItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [FileItem.ID: CGRect] = [:]

    static func reduce(value: inout [FileItem.ID: CGRect], nextValue: () -> [FileItem.ID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct FileSelectionDragState {
    let startLocation: CGPoint
    var location: CGPoint

    var selectionRect: CGRect {
        CGRect(
            x: min(startLocation.x, location.x),
            y: min(startLocation.y, location.y),
            width: abs(location.x - startLocation.x),
            height: abs(location.y - startLocation.y)
        )
    }

    var isSelectingRange: Bool {
        hypot(location.x - startLocation.x, location.y - startLocation.y) > 4
    }
}

struct FileSelectionMarquee: View {
    let rect: CGRect

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.accentColor.opacity(0.10))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.accentColor.opacity(0.75), lineWidth: 1)
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }
}

extension View {
    func reportsFileItemFrame(id: FileItem.ID) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FileItemFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named(fileSelectionCoordinateSpaceName))]
                )
            }
        }
    }
}
