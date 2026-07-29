import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ProfileStore()
    private let invocation = ProfileInvocation.parse(CommandLine.arguments)

    func applicationWillFinishLaunching(_ notification: Notification) {
        if invocation != nil {
            NSApp.setActivationPolicy(.prohibited)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let invocation else {
            store.bootstrap()
            return
        }

        Task {
            do {
                try await ProfileCommandRunner().run(invocation, using: store)
            } catch {
                FileHandle.standardError.write(
                    Data("f2t: \(error.localizedDescription)\n".utf8)
                )
            }
            NSApp.terminate(nil)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        invocation == nil
    }
}
