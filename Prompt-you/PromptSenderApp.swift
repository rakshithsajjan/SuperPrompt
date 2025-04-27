import SwiftUI

@main
struct PromptSenderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar) // Hides the title bar, content goes to the top
        /* Enable the Web Inspector at runtime with ⌥⌘I */
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Toggle Web Inspector") {
                    UserDefaults.standard.set(true, forKey: "WebKitDeveloperExtras")
                    print("WebKitDeveloperExtras enabled. Relaunch might be needed. Use Option+Cmd+I on a WKWebView.")
                }
                .keyboardShortcut("i", modifiers: [.command, .option]) // Cmd+Option+I
            }
        }
    }
}
