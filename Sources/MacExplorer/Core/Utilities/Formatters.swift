import Foundation

enum ExplorerFormatters {
    static func fileSize(_ size: Int64?) -> String {
        guard let size else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: size)
    }

    static func date(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
