# Swift Codebase Extraction

Repository path: /Users/raka/Desktop/WORK/PROJECTS/Prompt-you/Prompt-you/Prompt-you
Extraction date: 2025-04-27 04:19:49



================================================================================
FILE: PromptSenderApp.swift
================================================================================

import SwiftUI

@main
struct PromptSenderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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


================================================================================
FILE: ChatPane.swift
================================================================================

import SwiftUI
import WebKit

/// One browser tab + its UI state.
@MainActor
final class ChatPane: ObservableObject, Identifiable {
    let id       = UUID()
    let title    : String
    let provider : AIProvider

    @Published var isSelected: Bool = true {
        didSet { webView.isHidden = !isSelected }
    }

    let webView: WKWebView = WKWebView(
        frame: .zero,
        configuration: SharedWebKit.configuration()
    )

    init(provider: AIProvider, title: String) {
        self.provider = provider
        self.title = title // Use provided title

        guard let url = provider.defaultUrl else {
            // Handle error case: maybe load about:blank or show an error message?
            print("Error: Could not get default URL for provider \(provider.rawValue)")
            // For now, just create the webview without loading
            return
        }

        let request = URLRequest(url: url)
        Task {
            // Ensure webView is initialized before loading
            await self.webView.load(request)
        }
    }

    /// Sets prompt and clicks submit based on the provider.
    func sendCurrentPrompt(promptText: String) async -> String {
        // 1. Sanitize promptText (common for all providers)
        let sanitizedPrompt = promptText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")

        // 2. Construct provider-specific JavaScript
        let javascriptString: String

        // +++ ADDED: Provider Switch +++
        switch provider {
        case .you:
            // --- Logic for You.com (Existing) ---
            javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`;
                const editorSelector = '#search-input-textarea'; // You.com uses textarea
                const sendButtonSelector = 'button[type="submit"]'; // You.com uses submit button

                console.log("PromptSenderApp (You.com): Starting native setter/submit sequence.");

                const editor = document.querySelector(editorSelector);
                if (!editor) {
                    console.error(`PromptSenderApp (You.com): Could not find editor: ${editorSelector}`);
                    return 'NO_EDITOR_YOU';
                }
                console.log("PromptSenderApp (You.com): Found editor.");

                try {
                    const nativeTextAreaValueSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, "value").set;
                    if (nativeTextAreaValueSetter) {
                        nativeTextAreaValueSetter.call(editor, promptText);
                        console.log("PromptSenderApp (You.com): Called native value setter.");
                    } else {
                         console.warn("PromptSenderApp (You.com): Could not get native value setter. Falling back...");
                         editor.value = promptText;
                    }
                } catch (e) {
                     console.error("PromptSenderApp (You.com): Error during native value setting:", e, ". Falling back...");
                     editor.value = promptText;
                }

                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (You.com): Dispatched input event.");

                setTimeout(() => {
                    const buttons = document.querySelectorAll(sendButtonSelector);
                    if (buttons.length === 0) {
                        console.error(`PromptSenderApp (You.com): Could not find button: ${sendButtonSelector}`);
                        return; // No button found - implicitly returns undefined -> JS_NON_STRING
                    }
                    const sendButton = buttons[0];
                    if (sendButton.disabled || sendButton.hasAttribute('disabled')) {
                        console.warn("PromptSenderApp (You.com): Send button disabled.");
                        return; // Button disabled - implicitly returns undefined -> JS_NON_STRING
                    }
                    sendButton.click();
                    console.log("PromptSenderApp (You.com): Clicked button.");
                }, 200);

                return 'OK_YOU';
            })();
            """

        case .chatGPT:
            // --- Logic for ChatGPT (Restoring specific user-provided version) ---
             javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`;
                // Use selectors from the user-provided working version
                const editorSelector = '#prompt-textarea'; 
                const sendButtonSelector = 'button[data-testid="composer-speech-button"]'; 

                console.log("PromptSenderApp (ChatGPT - User Restore): Starting interaction sequence.");

                const editor = document.querySelector(editorSelector);
                if (!editor) {
                    console.error(`PromptSenderApp (ChatGPT - User Restore): Could not find editor div: ${editorSelector}`);
                    return 'NO_EDITOR_CHATGPT_USER_RESTORE';
                }
                console.log("PromptSenderApp (ChatGPT - User Restore): Found editor div.");

                // Use textContent setting from user-provided version
                editor.textContent = promptText;
                console.log("PromptSenderApp (ChatGPT - User Restore): Set textContent on editor div.");

                // Dispatch 'input' event
                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (ChatGPT - User Restore): Dispatched input event on editor div.");

                // Use button logic from user-provided version
                setTimeout(() => {
                    const sendButton = document.querySelector(sendButtonSelector);
                    if (!sendButton) {
                        console.error(`PromptSenderApp (ChatGPT - User Restore): Could not find button: ${sendButtonSelector}`);
                        return; // implicit undefined -> JS_NON_STRING
                    }
                    console.log("PromptSenderApp (ChatGPT - User Restore): Found button (composer-speech-button).");

                    // Check the 'state' attribute 
                    const isDisabled = sendButton.getAttribute('state') === 'disabled';
                    if (isDisabled) {
                        console.warn("PromptSenderApp (ChatGPT - User Restore): Button is disabled (state='disabled'). Not clicking.");
                    } else {
                        console.log("PromptSenderApp (ChatGPT - User Restore): Button state not disabled. Simulating click.");
                        sendButton.click();
                        console.log("PromptSenderApp (ChatGPT - User Restore): Click simulated.");
                    }
                }, 300); // Use delay from that version

                return 'OK_ATTEMPTED_CHATGPT_USER_RESTORE'; // Status for this version
            })();
            """
        // Add case for .claude later
        /*
        case .claude:
            javascriptString = """
            // Claude-specific JS here
            """
        */
        }
        // +++ END ADDED CODE +++

        // 3. Call evaluateJavaScript with the chosen string
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(javascriptString) { result, error in
                if let error = error {
                    // Add provider info to error message
                    print("Error evaluating JS for \(self.provider.rawValue): \(error)")
                    // Return a provider-specific error code if needed, or generic
                    continuation.resume(returning: "JS_ERROR_\(self.provider.rawValue)")
                    return
                }
                if let resultString = result as? String {
                    continuation.resume(returning: resultString)
                } else {
                    print("JS evaluation for \(self.provider.rawValue) returned non-string: \(type(of: result)), value: \(result ?? "nil")")
                    // Return a provider-specific code if needed
                    continuation.resume(returning: "JS_NON_STRING_\(self.provider.rawValue)")
                }
            }
        }
    }
}


================================================================================
FILE: MainModel.swift
================================================================================

import SwiftUI

/// Represents the AI service provider for a pane.
enum AIProvider: String, CaseIterable {
    case you = "You.com"
    case chatGPT = "ChatGPT"
    // Add claude later
    // case claude = "Claude"

    var defaultUrl: URL? {
        switch self {
        case .you:
            return URL(string: "https://chat.you.com")!
        case .chatGPT:
            return URL(string: "https://chat.openai.com")!
        // case .claude:
        //     return URL(string: "https://claude.ai")!
        }
    }

    // Add other provider-specific details here if needed later
}

@MainActor
final class MainModel: ObservableObject {

    @Published var panes: [ChatPane] = [
        ChatPane(provider: .you, title: "You.com"),
        ChatPane(provider: .chatGPT, title: "ChatGPT"),
        ChatPane(provider: .you, title: "You.com 2") // Example: Add another You.com pane
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


================================================================================
FILE: SharedWebKit.swift
================================================================================

import WebKit

/// Single source of truth for cookies, local- & sessionStorage, and
/// JavaScript JIT permission across all WKWebViews in this process.
enum SharedWebKit {

    /// One global WKProcessPool => all panes share js/localStorage.
    static let pool: WKProcessPool = WKProcessPool()

    /// Convenience builder for a fully wired configuration.
    static func configuration() -> WKWebViewConfiguration {
        let cfg         = WKWebViewConfiguration()
        cfg.processPool = pool
        cfg.websiteDataStore = .default()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        return cfg
    }

    // --- JavaScript Snippets ---

    /// Gets the current value from the target text area.
    static let getJS: String =
    #"""
    (function() {
        const editor = document.querySelector('#search-input-textarea');
        return editor ? editor.value : null; // Return text or null if not found
    })();
    """#

    // NOTE: The following sendJS is NOT used by the current ChatPane implementation
    // (which generates JS dynamically), but kept here for reference of the
    // argument-passing approach.
    /// Sets the text area's value and simulates Cmd/Ctrl + Enter.
    static let sendJS_UNUSED: String =
    #"""
    (function(promptText) { // Expects promptText as the first argument
        const editor = document.querySelector('#search-input-textarea');
        if (!editor) {
            console.error("PromptSenderApp: Could not find editor #search-input-textarea");
            return 'NO_EDITOR';
        }
        if (typeof promptText !== 'string') {
             console.error("PromptSenderApp: Invalid or missing promptText argument.");
             return 'INVALID_ARG';
        }

        editor.value = promptText;
        const inputEvent = new Event('input', { bubbles: true, cancelable: true });
        editor.dispatchEvent(inputEvent);
        editor.focus();

        setTimeout(() => {
             ['metaKey','ctrlKey'].forEach(mod => {
                const keyDownEvent = new KeyboardEvent('keydown', {
                    key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
                    bubbles: true, cancelable: true, composed: true,
                    [mod]: true
                });
                console.log(`PromptSenderApp: Dispatching keydown with ${mod}=true after setting text`);
                editor.dispatchEvent(keyDownEvent);
            });
            // Optional keyup
            const keyUpEvent = new KeyboardEvent('keyup', {
                 key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true, composed: true
            });
            console.log("PromptSenderApp: Dispatching keyup");
            editor.dispatchEvent(keyUpEvent);

        }, 100);

        return 'OK';
    })();
    """#
}


================================================================================
FILE: ContentView.swift
================================================================================

import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var model = MainModel()

    var body: some View {
        // Overall container
        VStack(spacing: 0) {

            /*───── Browser grid (now occupies most space) ─────*/
            GeometryReader { geo in
                let visiblePanes = model.panes.filter { $0.isSelected }
                let count = CGFloat(visiblePanes.count)
                let width = count > 0 ? geo.size.width / count : geo.size.width

                HStack(spacing: 0) {
                    ForEach(model.panes) { pane in
                        if pane.isSelected {
                             WebViewWrapper(pane.webView)
                                .frame(width: width)
                        }
                    }
                }
            }
            // Allow GeometryReader to expand
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider() // Divider above the bottom controls

            /*───── Bottom Control Bar ─────*/
            VStack(spacing: 8) {
                // Checkboxes (Top row within the bottom bar)
                HStack {
                    ForEach($model.panes) { $pane in
                        Toggle(pane.title, isOn: $pane.isSelected)
                            .toggleStyle(.checkbox)
                            .disabled(model.isBroadcasting)
                    }
                    Spacer() // Pushes checkboxes left
                }

                // Input + Send Button (Bottom row within the bottom bar)
                HStack(spacing: 8) {
                    TextField("Enter prompt here...", text: $model.promptText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(model.isBroadcasting)
                        .onSubmit {
                            if !model.isBroadcasting {
                                model.broadcast()
                            }
                        }

                    Button { model.broadcast() } label: {
                         // Use an SF Symbol for a sleeker look
                         Image(systemName: "paperplane.fill")
                             .imageScale(.medium)
                             .frame(height: 20) // Ensure consistent height
                    }
                    .buttonStyle(.borderedProminent) // Style the button
                    .tint(.accentColor) // Use accent color
                    .disabled(model.isBroadcasting || model.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(10) // Add padding around the bottom control area
            .background(.regularMaterial) // Give it a distinct background
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

/* SwiftUI wrapper that embeds the existing WKWebView instance. */
private struct WebViewWrapper: NSViewRepresentable {
    let wk: WKWebView
    init(_ w: WKWebView) { self.wk = w }

    func makeNSView(context: Context) -> WKWebView { wk }
    func updateNSView(_ nsView: WKWebView, context: Context) { }
}


================================================================================
SUMMARY: Extracted 5 Swift files from the codebase.
