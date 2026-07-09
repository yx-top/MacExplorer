import Foundation

struct FileItem: Identifiable, Equatable, Sendable {
    var id: URL { url }

    let url: URL
    let name: String
    let isDirectory: Bool
    let isPackage: Bool
    let fileSize: Int64?
    let modificationDate: Date?
    let creationDate: Date?
    let typeDescription: String
    let isHidden: Bool
    let isReadable: Bool?
    let isWritable: Bool?
    let isExecutable: Bool?

    var displayName: String {
        name.isEmpty ? url.lastPathComponent : name
    }

    func displayName(showFileExtensions: Bool) -> String {
        guard !showFileExtensions, !isDirectory, !fileExtension.isEmpty else {
            return displayName
        }

        let hiddenExtensionName = (displayName as NSString).deletingPathExtension
        return hiddenExtensionName.isEmpty ? displayName : hiddenExtensionName
    }

    var fileExtension: String {
        url.pathExtension.lowercased()
    }
}
