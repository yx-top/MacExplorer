import SwiftUI

struct IconButton: View {
    let symbolName: String
    let title: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
    }
}

