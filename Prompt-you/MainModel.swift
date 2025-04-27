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

    // UserDefaults keys
    private let savedProvidersKey = "savedPaneProviders_v1"
    private let savedFocusIndexKey = "savedFocusedIndex_v1"

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
        savePanesState() // Save after adding
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
        savePanesState() // Save after removing and adjusting focus
    }

    // Function to cycle focus between panes
    func cycleFocus(forward: Bool) {
        guard panes.count > 1, let currentIndex = focusedPaneIndex else { return } // Need at least 2 panes to cycle

        let offset = forward ? 1 : -1
        let nextIndex = (currentIndex + offset + panes.count) % panes.count
        // Use setFocus to ensure save is called
        setFocus(to: nextIndex)
        // focusedPaneIndex = nextIndex // Directly setting bypasses save
        // print("Cycling focus. New index: \(focusedPaneIndex ?? -1)")
        // savePanesState() // Save after cycling focus - Handled by setFocus
    }

    // Function to directly set focus to a specific pane index
    func setFocus(to index: Int) {
        guard index >= 0 && index < panes.count else {
            print("SetFocus Error: Index \(index) out of bounds (0..\(panes.count-1))")
            return
        }
        // Only save if the index actually changes
        if focusedPaneIndex != index {
            focusedPaneIndex = index
            print("Setting focus directly to index: \(index)")
            savePanesState() // Save after setting focus
        }
    }

    // MARK: - Persistence (UserDefaults)

    func savePanesState() {
        let providerRawValues = panes.map { $0.provider.rawValue }
        UserDefaults.standard.set(providerRawValues, forKey: savedProvidersKey)

        if let index = focusedPaneIndex {
            UserDefaults.standard.set(index, forKey: savedFocusIndexKey)
        } else {
            // If no focus, remove the key
            UserDefaults.standard.removeObject(forKey: savedFocusIndexKey)
        }
        print("Persistence: Saved \(providerRawValues.count) panes and focus index \(focusedPaneIndex ?? -1)")
    }

    func loadPanesState() {
        guard let providerRawValues = UserDefaults.standard.array(forKey: savedProvidersKey) as? [String] else {
            print("Persistence: No saved pane provider data found.")
            return // No saved state
        }

        // Only load if panes are currently empty to avoid duplication on hot reload/previews
        guard panes.isEmpty else {
            print("Persistence: Panes not empty, skipping load.")
            return
        }

        print("Persistence: Loading saved pane state...")
        var loadedFocusIndex: Int? = UserDefaults.standard.object(forKey: savedFocusIndexKey) as? Int

        for rawValue in providerRawValues {
            if let provider = AIProvider(rawValue: rawValue) {
                // Use a temporary non-publishing add method or simply call addPane
                // directly since we are controlling the loading sequence.
                // Calling addPane here will trigger focus logic, which is fine.
                addPane(provider: provider) // This adds the pane
            } else {
                print("Persistence Warning: Unknown provider rawValue loaded: \(rawValue)")
            }
        }

        // Validate and restore focus AFTER panes are added
        if let index = loadedFocusIndex, index >= 0 && index < panes.count {
            focusedPaneIndex = index
            print("Persistence: Restored focus index to \(index)")
        } else {
            // If saved index is invalid or missing, default to first pane if any
            if !panes.isEmpty && focusedPaneIndex == nil {
                focusedPaneIndex = 0
                print("Persistence: Saved focus invalid/missing, defaulting focus to 0.")
            }
        }
        print("Persistence: Finished loading state. Total panes: \(panes.count), Focus: \(focusedPaneIndex ?? -1)")
    }

    /// Sends the text from the app's input field to all selected panes CONCURRENTLY.
    func broadcast() {
        let textToSend = promptText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !isBroadcasting else {
            print("Broadcast (Parallel): Already in progress, ignoring trigger.")
            return
        }
        guard !textToSend.isEmpty else {
            print("Broadcast (Parallel): Prompt text is empty.")
            return
        }
        guard !panes.isEmpty else {
            print("Broadcast (Parallel): No panes open.")
            return
        }

        // Set flag immediately on the main actor
        isBroadcasting = true
        print("Broadcast (Parallel): >>> Setting isBroadcasting = true <<<")
        print("Broadcast (Parallel): Text to send = '\(textToSend)'")

        // Launch a detached task to perform the concurrent sends off the main thread initially
        Task.detached(priority: .userInitiated) {
            // Fetch the panes array from the MainActor *before* starting the TaskGroup
            let panesToBroadcast = await self.panes
            print("Broadcast (Parallel): Sending concurrently to \(panesToBroadcast.count) panes.")

            // Use a TaskGroup to manage concurrent sends
            await withTaskGroup(of: Void.self) { group in
                // Iterate over the local copy of the array
                for pane in panesToBroadcast {
                    // Add a task to the group for sending the prompt to this pane
                    group.addTask {
                        print("Broadcast (Parallel): Starting send to \(pane.title)")
                        // Call sendCurrentPrompt (which is MainActor isolated)
                        // The await here happens within the child task.
                        let result = await pane.sendCurrentPrompt(promptText: textToSend)
                        print("Broadcast (Parallel): Result for \(pane.title): \(result)")
                        // TODO: Consider collecting results or handling errors if needed
                    }
                }
                // The TaskGroup automatically waits for all added tasks to complete here.
                 print("Broadcast (Parallel): TaskGroup finished.")
            }

            // After all tasks in the group are complete, switch back to the main actor
            // to update the UI state (reset flag and clear text).
            await MainActor.run {
                print("Broadcast (Parallel): <<< Setting isBroadcasting = false >>>")
                self.isBroadcasting = false
                // Clear the text field after attempting all sends.
                // We are not currently checking for errors within the group.
                self.promptText = ""
                print("Broadcast (Parallel): Cleared prompt text field.")
            }
        }
    }
}
