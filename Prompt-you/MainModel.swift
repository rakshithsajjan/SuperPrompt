import SwiftUI

/// Represents the AI service provider for a pane.
enum AIProvider: String, CaseIterable {
    case you = "You.com"
    case chatGPT = "ChatGPT"
    // Add claude later
    case claude = "Claude"
    case aistudio = "AI Studio"
    case grok = "Grok"

    var defaultUrl: URL? {
        switch self {
        case .you:
            return URL(string: "https://chat.you.com")!
        case .chatGPT:
            return URL(string: "https://chat.openai.com")!
        case .claude:
            return URL(string: "https://claude.ai")!
        case .aistudio:
            return URL(string: "https://aistudio.google.com/app/prompts/new_chat")!
        case .grok:
            return URL(string: "https://grok.com")!
        }
    }

    // Add other provider-specific details here if needed later
}

@MainActor
final class MainModel: ObservableObject {

    @Published var panes: [ChatPane] = [
        ChatPane(provider: .you, title: "You.com"),
        ChatPane(provider: .chatGPT, title: "ChatGPT"),
        ChatPane(provider: .claude, title: "Claude"),
        ChatPane(provider: .aistudio, title: "AI Studio"),
        ChatPane(provider: .grok, title: "Grok")
    ]

    @Published var promptText: String = ""
    @Published var isBroadcasting: Bool = false

    /// Sends the text from the app's input field to all selected panes.
    func broadcast() {
        let textToSend = promptText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !isBroadcasting else {
            print("Broadcast: Already in progress, ignoring trigger.")
            return
        }
        guard !textToSend.isEmpty else {
            print("Broadcast: Prompt text is empty.")
            return
        }

        // Set flag immediately on the main actor
        isBroadcasting = true
        print("Broadcast: >>> Setting isBroadcasting = true <<<")
        print("Broadcast: Text to send = '\(textToSend)'")

        Task {
            // Use defer to ensure the flag is reset when the Task scope exits
            defer {
                 // Directly assign on the main actor since MainModel is @MainActor
                 self.isBroadcasting = false
                 print("Broadcast: <<< Setting isBroadcasting = false (deferred) <<<")
            }

            let selectedPanes = panes.filter { $0.isSelected }
            guard !selectedPanes.isEmpty else {
                 print("Broadcast: No panes selected.")
                 return // Defer will still run
            }

            print("Broadcast: Sending to \(selectedPanes.count) selected panes.")

            var allSendsAttempted = true // Flag to track if all sends were initiated
            for (index, pane) in selectedPanes.enumerated() {
                if index > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                }
                print("Sending '\(textToSend)' to \(pane.title)")
                let result = await pane.sendCurrentPrompt(promptText: textToSend)
                print("Result for \(pane.title): \(result)")
                // Check if the send attempt failed critically (e.g., JS error, couldn't find editor)
                if result == "JS_ERROR" || result == "NO_EDITOR" {
                    allSendsAttempted = false
                    // Decide if you want to stop the broadcast early on critical error
                    // print("Broadcast: Critical error sending to \(pane.title). Stopping broadcast.")
                    // break // Uncomment to stop early
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds post-send delay
            }
            print("Broadcast: Finished sending loop.")

            // --- ADDED CODE ---
            // Clear the input field only if all send attempts were initiated
            // (We don't know if they *succeeded* on the website, but the JS ran)
            if allSendsAttempted {
                 self.promptText = ""
                 print("Broadcast: Cleared prompt text field.")
            } else {
                 print("Broadcast: Not clearing prompt text field due to errors during send attempts.")
            }
            // --- END ADDED CODE ---

            // Defer runs after this line
        }
    }
}
