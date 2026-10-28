import SwiftUI

@main
struct mortalpagesStudioApp: App {
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .frame(minWidth: 920, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) { } // No new document window
        }
    }
}
