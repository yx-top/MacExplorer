import AppKit

@MainActor
enum InputEventTracker {
    private static var monitor: Any?
    private static var latestMouseDownFlags: NSEvent.ModifierFlags = []
    private static var latestMouseDownAt = Date.distantPast

    static func install() {
        guard monitor == nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
            latestMouseDownFlags = event.modifierFlags
            latestMouseDownAt = Date()
            return event
        }
    }

    static var selectionModifierFlags: NSEvent.ModifierFlags {
        if Date().timeIntervalSince(latestMouseDownAt) < 1.5 {
            return latestMouseDownFlags
        }

        return NSEvent.modifierFlags
    }
}
