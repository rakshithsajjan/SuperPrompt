import SwiftUI

/// Represents the AI service provider for a pane.
enum AIProvider: String, CaseIterable, Identifiable {
    case you = "You.com"
    case chatGPT = "ChatGPT"
    // Add claude later
    case claude = "Claude"
    case aistudio = "AI Studio"
    case grok = "Grok"
    case perplexity = "Perplexity"
    case gemini = "Gemini"
    case mistral = "Mistral"

    var id: String { self.rawValue }

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
        case .perplexity:
            return URL(string: "https://www.perplexity.ai/")!
        case .gemini:
            return URL(string: "https://gemini.google.com/app")!
        case .mistral:
            return URL(string: "https://chat.mistral.ai/")!
        }
    }

    // Add other provider-specific details here if needed later
}

@MainActor
final class MainModel: ObservableObject {

    @Published var panes: [ChatPane] = []

    @Published var promptText: String = ""
    @Published var isBroadcasting: Bool = false
    @Published var focusedPaneIndex: Int? = nil // Index of the pane that should have focus

    func addPane(provider: AIProvider) {
        let newPane = ChatPane(provider: provider, title: provider.rawValue)
        newPane.isSelected = true
        panes.append(newPane)
        print("Added pane for: \(provider.rawValue). Total panes: \(panes.count)")
        // If this is the first pane added, focus it
        if focusedPaneIndex == nil && panes.count == 1 {
            focusedPaneIndex = 0
            print("Setting initial focus index to 0")
        }
    }

    func removePane(id: UUID) {
        guard let removedIndex = panes.firstIndex(where: { $0.id == id }) else { return }

        panes.removeAll { $0.id == id }
        print("Removed pane with ID: \(id). Total panes: \(panes.count)")

        // Adjust focus if the focused pane was removed or a later pane was removed
        if let currentFocus = focusedPaneIndex {
            if panes.isEmpty {
                focusedPaneIndex = nil // No panes left
            } else if removedIndex == currentFocus {
                // Focus the previous one (wrapping around if needed)
                focusedPaneIndex = (currentFocus - 1 + panes.count) % panes.count
            } else if removedIndex < currentFocus {
                // A pane before the focused one was removed, decrement focus index
                focusedPaneIndex = currentFocus - 1
            }
            // If removedIndex > currentFocus, focus index remains the same
             print("Adjusted focus index to: \(focusedPaneIndex ?? -1)")
        }
    }

    // Function to cycle focus between panes
    func cycleFocus(forward: Bool) {
        guard panes.count > 1, let currentIndex = focusedPaneIndex else { return } // Need at least 2 panes to cycle

        let offset = forward ? 1 : -1
        let nextIndex = (currentIndex + offset + panes.count) % panes.count
        focusedPaneIndex = nextIndex
        print("Cycling focus. New index: \(focusedPaneIndex ?? -1)")
    }

    // Function to directly set focus to a specific pane index
    func setFocus(to index: Int) {
        guard index >= 0 && index < panes.count else {
            print("SetFocus Error: Index \(index) out of bounds (0..\(panes.count-1))")
            return
        }
        focusedPaneIndex = index
        print("Setting focus directly to index: \(index)")
    }

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

            guard !panes.isEmpty else {
                 print("Broadcast: No panes open.")
                 return // Defer will still run
            }
            print("Broadcast: Sending to \(panes.count) open panes.")

            var allSendsAttempted = true // Flag to track if all sends were initiated
            for (index, pane) in panes.enumerated() {
                if index > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                }
                print("Sending '\(textToSend)' to \(pane.title)")
                let result = await pane.sendCurrentPrompt(promptText: textToSend)
                print("Result for \(pane.title): \(result)")
                // Check if the send attempt failed critically (e.g., JS error, couldn't find editor)
                if result.hasPrefix("JS_ERROR_") || result.hasPrefix("NO_EDITOR_") || result.hasPrefix("FAIL_") {
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
