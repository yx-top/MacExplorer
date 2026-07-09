import Foundation

enum FileTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case any
    case folders
    case documents
    case images
    case audio
    case video
    case archives
    case apps

    var id: String { rawValue }

    var title: String {
        title(for: .english)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .any: L10n.text(.anyType, for: language)
        case .folders: L10n.text(.folders, for: language)
        case .documents: L10n.text(.documents, for: language)
        case .images: L10n.text(.images, for: language)
        case .audio: L10n.text(.audio, for: language)
        case .video: L10n.text(.video, for: language)
        case .archives: L10n.text(.archives, for: language)
        case .apps: L10n.text(.apps, for: language)
        }
    }
}

enum FileSizeFilter: String, CaseIterable, Identifiable, Sendable {
    case any
    case tiny
    case small
    case medium
    case large
    case huge

    var id: String { rawValue }

    var title: String {
        title(for: .english)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .any: L10n.text(.anySize, for: language)
        case .tiny: "< 100 KB"
        case .small: "100 KB-10 MB"
        case .medium: "10-100 MB"
        case .large: "100 MB-1 GB"
        case .huge: "> 1 GB"
        }
    }
}

enum ModifiedDateFilter: String, CaseIterable, Identifiable, Sendable {
    case any
    case today
    case thisWeek
    case thisMonth
    case thisYear

    var id: String { rawValue }

    var title: String {
        title(for: .english)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .any: L10n.text(.anyDate, for: language)
        case .today: L10n.text(.today, for: language)
        case .thisWeek: L10n.text(.thisWeek, for: language)
        case .thisMonth: L10n.text(.thisMonth, for: language)
        case .thisYear: L10n.text(.thisYear, for: language)
        }
    }
}

struct SearchFilters: Equatable, Sendable {
    var extensionText = ""
    var type: FileTypeFilter = .any
    var size: FileSizeFilter = .any
    var modified: ModifiedDateFilter = .any

    var isActive: Bool {
        !extensionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || type != .any
            || size != .any
            || modified != .any
    }

    func matches(_ item: FileItem) -> Bool {
        matchesExtension(item)
            && matchesType(item)
            && matchesSize(item)
            && matchesModifiedDate(item)
    }

    private func matchesExtension(_ item: FileItem) -> Bool {
        let extensions = extensionText
            .split { character in
                character.isWhitespace || character == "," || character == ";"
            }
            .map(String.init)
            .map {
                $0.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    .lowercased()
            }
            .filter { !$0.isEmpty }

        guard !extensions.isEmpty else { return true }
        return extensions.contains(item.fileExtension)
    }

    private func matchesType(_ item: FileItem) -> Bool {
        switch type {
        case .any:
            return true
        case .folders:
            return item.isDirectory
        case .documents:
            return ["pdf", "txt", "rtf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "md", "csv", "json", "xml"].contains(item.fileExtension)
        case .images:
            return ["png", "jpg", "jpeg", "gif", "heic", "tiff", "bmp", "webp", "svg"].contains(item.fileExtension)
        case .audio:
            return ["mp3", "aac", "wav", "flac", "m4a", "aiff", "ogg"].contains(item.fileExtension)
        case .video:
            return ["mp4", "mov", "m4v", "avi", "mkv", "webm"].contains(item.fileExtension)
        case .archives:
            return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg"].contains(item.fileExtension)
        case .apps:
            return item.fileExtension == "app" || item.isPackage
        }
    }

    private func matchesSize(_ item: FileItem) -> Bool {
        guard size != .any else { return true }
        guard !item.isDirectory, let fileSize = item.fileSize else { return false }

        switch size {
        case .any:
            return true
        case .tiny:
            return fileSize < 100_000
        case .small:
            return fileSize >= 100_000 && fileSize < 10_000_000
        case .medium:
            return fileSize >= 10_000_000 && fileSize < 100_000_000
        case .large:
            return fileSize >= 100_000_000 && fileSize < 1_000_000_000
        case .huge:
            return fileSize >= 1_000_000_000
        }
    }

    private func matchesModifiedDate(_ item: FileItem) -> Bool {
        guard modified != .any else { return true }
        guard let modificationDate = item.modificationDate else { return false }

        let calendar = Calendar.current
        let now = Date()

        switch modified {
        case .any:
            return true
        case .today:
            return calendar.isDate(modificationDate, inSameDayAs: now)
        case .thisWeek:
            return calendar.isDate(modificationDate, equalTo: now, toGranularity: .weekOfYear)
        case .thisMonth:
            return calendar.isDate(modificationDate, equalTo: now, toGranularity: .month)
        case .thisYear:
            return calendar.isDate(modificationDate, equalTo: now, toGranularity: .year)
        }
    }
}
