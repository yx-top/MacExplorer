import Darwin
import Foundation

@MainActor
final class DirectoryMonitor {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1

    func startMonitoring(url: URL, onChange: @escaping @MainActor () -> Void) {
        stop()

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        fileDescriptor = descriptor

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .attrib, .extend],
            queue: .main
        )

        source.setEventHandler {
            Task { @MainActor in
                onChange()
            }
        }

        source.setCancelHandler { [descriptor] in
            close(descriptor)
        }

        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }
}
