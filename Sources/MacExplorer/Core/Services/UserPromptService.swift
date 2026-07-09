import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum UserPromptService {
    static func requestString(
        title: String,
        message: String,
        placeholder: String,
        initialValue: String = "",
        confirmButton: String,
        cancelButton: String
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: confirmButton)
        alert.addButton(withTitle: cancelButton)

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        textField.placeholderString = placeholder
        textField.stringValue = initialValue
        alert.accessoryView = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }

        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func confirmDestructive(title: String, message: String, confirmButton: String, cancelButton: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmButton)
        alert.addButton(withTitle: cancelButton)
        alert.buttons.first?.hasDestructiveAction = true
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func chooseConflictResolution(conflictCount: Int, language: AppLanguage) -> FileConflictResolution? {
        let alert = NSAlert()
        alert.messageText = L10n.text(.nameConflict, for: language)
        alert.informativeText = L10n.conflictMessage(count: conflictCount, for: language)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text(.keepBoth, for: language))
        alert.addButton(withTitle: L10n.text(.replace, for: language))
        alert.addButton(withTitle: L10n.text(.skip, for: language))
        alert.addButton(withTitle: L10n.text(.cancel, for: language))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .keepBoth
        case .alertSecondButtonReturn:
            return .replace
        case .alertThirdButtonReturn:
            return .skip
        default:
            return nil
        }
    }

    static func chooseApplication(language: AppLanguage) -> URL? {
        let panel = NSOpenPanel()
        panel.title = L10n.text(.chooseApplication, for: language)
        panel.message = L10n.text(.chooseApplicationMessage, for: language)
        panel.prompt = L10n.text(.open, for: language)
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        if let applicationType = UTType(filenameExtension: "app") {
            panel.allowedContentTypes = [applicationType]
        }

        return panel.runModal() == .OK ? panel.url : nil
    }
}
