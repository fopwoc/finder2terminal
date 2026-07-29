import SwiftUI

@main
struct finder2terminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            FinderActionsView(store: appDelegate.store)
        }
        .defaultSize(width: 900, height: 600)
        .windowIdealSize(.maximum)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appSettings) {
                Divider()
                Button("commands.delete_all_data") {
                    appDelegate.store.isPurgeConfirmationPresented = true
                }
            }
        }
    }
}
