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

    // Use the custom subclass that prevents horizontal scroll hijacking
    let webView: PaneWebView = PaneWebView(
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
            // --- Logic for ChatGPT (Revised based on contenteditable div analysis) ---
             javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`; // Keep sanitization
                // Use the specific selector from the new analysis
                const editorSelector = 'div#prompt-textarea[contenteditable="true"]'; 

                console.log("PromptSenderApp (ChatGPT - ProseMirror): Starting interaction with contenteditable div.");

                const editorDiv = document.querySelector(editorSelector);
                if (!editorDiv) {
                    console.error(`PromptSenderApp (ChatGPT - PM): Could not find contenteditable div: ${editorSelector}`);
                    return 'NO_EDITOR_DIV_PM';
                }
                console.log("PromptSenderApp (ChatGPT - PM): Found contenteditable div.");

                // 1. Focus the editor
                editorDiv.focus();
                console.log("PromptSenderApp (ChatGPT - PM): Focused editor div.");

                // 2. Set the content (Try textContent first)
                //    If placeholder <p> causes issues, might need: editorDiv.innerHTML = ''; first
                editorDiv.textContent = promptText;
                // Alternative: editorDiv.innerHTML = `<p>${promptText}</p>`;
                console.log(`PromptSenderApp (ChatGPT - PM): Set textContent to: ${promptText}`);

                // 3. Dispatch an 'input' event
                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editorDiv.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (ChatGPT - PM): Dispatched input event on editor div.");

                // 4. Add a delay BEFORE attempting button interaction
                setTimeout(() => {
                    const sendButtonSelector = 'button[data-testid="send-button"]'; // Target the actual send button
                    const sendButton = document.querySelector(sendButtonSelector);
                    if (!sendButton) {
                        console.error(`PromptSenderApp (ChatGPT - PM): Could not find button: ${sendButtonSelector}. (Is text long enough to enable it?)`);
                        return; // Implicitly returns JS_NON_STRING
                    }
                    console.log("PromptSenderApp (ChatGPT - PM): Found button.");

                    // Check the standard disabled attribute
                    if (sendButton.disabled || sendButton.hasAttribute('disabled')) {
                        console.warn("PromptSenderApp (ChatGPT - PM): Button is disabled after setting text and dispatching input. Framework likely did not fully recognize input.");
                    } else {
                        console.log("PromptSenderApp (ChatGPT - PM): Button appears enabled. Simulating click.");
                        sendButton.click();
                        console.log("PromptSenderApp (ChatGPT - PM): Click simulated.");
                    }
                }, 250); // Use suggested delay

                return 'OK_ATTEMPTED_DIV_SET_PM'; // New status code
            })();
            """
        case .claude:
            javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`;
                const editorSelector = 'div.ProseMirror[contenteditable="true"]';
                const sendButtonSelector = 'button[aria-label="Send message"]';

                console.log("PromptSenderApp (Claude): Starting interaction.");

                const editor = document.querySelector(editorSelector);
                if (!editor) {
                    console.error(`PromptSenderApp (Claude): Could not find editor: ${editorSelector}`);
                    return 'NO_EDITOR_CLAUDE';
                }
                console.log("PromptSenderApp (Claude): Found editor.");

                // 1. Focus (Recommended)
                editor.focus();
                console.log("PromptSenderApp (Claude): Focused editor.");

                // 2. Set Content (Using textContent, might need innerHTML/<p> if complex)
                //    Clear existing content might be needed if placeholder interferes
                //    editor.innerHTML = ''; // Optional: Clear first
                editor.textContent = promptText;
                console.log(`PromptSenderApp (Claude): Set textContent to: ${promptText}`);

                // 3. Dispatch Input Event
                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (Claude): Dispatched input event.");

                // 4. Wait and Click Button
                setTimeout(() => {
                    const sendButton = document.querySelector(sendButtonSelector);
                    if (!sendButton) {
                        console.error(`PromptSenderApp (Claude): Could not find button: ${sendButtonSelector}`);
                        return; // Implicitly returns JS_NON_STRING_CLAUDE
                    }
                    console.log("PromptSenderApp (Claude): Found button.");

                    if (sendButton.disabled || sendButton.hasAttribute('disabled')) {
                        console.warn("PromptSenderApp (Claude): Send button is disabled after dispatching input. Framework interaction likely incomplete or needs more time.");
                        // Consider adding MutationObserver logic here in the future if needed
                        return; // Implicitly returns JS_NON_STRING_CLAUDE (or a specific code like BUTTON_DISABLED_CLAUDE)
                    }

                    console.log("PromptSenderApp (Claude): Button appears enabled. Clicking.");
                    sendButton.click();
                    console.log("PromptSenderApp (Claude): Clicked button.");
                }, 250); // Use a delay similar to ChatGPT

                return 'OK_CLAUDE'; // Indicate success
            })();
            """
        case .aistudio:
            javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`;
                // Use a selector that matches EITHER aria-label
                const editorSelector = 'textarea[aria-label="Type something"], textarea[aria-label="Type something or pick one from prompt gallery"]';
                const sendButtonSelector = 'button[aria-label="Run"]';

                console.log("PromptSenderApp (AI Studio): Starting interaction.");

                // Query for the editor using the combined selector
                const editor = document.querySelector(editorSelector);
                if (!editor) {
                    console.error(`PromptSenderApp (AI Studio): Could not find editor with selectors: ${editorSelector}`);
                    return 'NO_EDITOR_AISTUDIO';
                }
                console.log(`PromptSenderApp (AI Studio): Found editor with aria-label: ${editor.getAttribute('aria-label')}`);

                // 1. Set Value for <textarea>
                editor.value = promptText;
                console.log(`PromptSenderApp (AI Studio): Set editor value.`);

                // 2. Dispatch Input Event (Crucial for Angular/frameworks)
                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (AI Studio): Dispatched input event.");

                // 3. Wait and Click Button (Logic remains the same)
                setTimeout(() => {
                    const sendButton = document.querySelector(sendButtonSelector);
                    if (!sendButton) {
                        console.error(`PromptSenderApp (AI Studio): Could not find button: ${sendButtonSelector}`);
                        return; // Implicitly returns JS_NON_STRING_AISTUDIO
                    }
                    console.log("PromptSenderApp (AI Studio): Found button.");

                    if (sendButton.disabled || sendButton.hasAttribute('disabled')) {
                        console.warn("PromptSenderApp (AI Studio): Send button is disabled. Framework likely needs more time or input not fully registered.");
                        return; // Implicitly returns JS_NON_STRING_AISTUDIO or BUTTON_DISABLED_AISTUDIO
                    }

                    console.log("PromptSenderApp (AI Studio): Button appears enabled. Clicking.");
                    sendButton.click();
                    console.log("PromptSenderApp (AI Studio): Clicked button.");
                }, 250);

                return 'OK_AISTUDIO';
            })();
            """
        case .grok:
            javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`;
                const editorSelector = 'textarea[aria-label="Ask Grok anything"]';
                const sendButtonSelector = 'button[aria-label="Submit"]';

                console.log("PromptSenderApp (Grok): Starting native setter + InputEvent simulation.");

                const box = document.querySelector(editorSelector);
                const sendBtn = document.querySelector(sendButtonSelector);

                if (!box) {
                    console.error(`PromptSenderApp (Grok): Could not find editor: ${editorSelector}`);
                    return 'NO_EDITOR_GROK';
                }
                if (!sendBtn) {
                    // Log this but continue, as the button might appear later
                    console.warn(`PromptSenderApp (Grok): Could not find send button initially: ${sendButtonSelector}`);
                }
                console.log("PromptSenderApp (Grok): Found editor.");

                /* 1. put focus on the box */
                box.focus();
                console.log("PromptSenderApp (Grok): Focused editor.");

                /* 2. set the value through the native prototype's setter */
                const nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
                if (!nativeSetter) {
                    console.error("PromptSenderApp (Grok): Could not get native value setter.");
                    return 'NO_NATIVE_SETTER_GROK';
                }
                nativeSetter.call(box, promptText);
                console.log("PromptSenderApp (Grok): Called native value setter.");

                /* 3. dispatch a real looking InputEvent */
                const ev = new InputEvent('input', {
                    bubbles: true,
                    cancelable: false, // As per analysis
                    inputType: 'insertFromPaste',
                    data: promptText
                });
                box.dispatchEvent(ev);
                console.log("PromptSenderApp (Grok): Dispatched targeted InputEvent.");

                /* 4. wait one macrotask */
                setTimeout(() => {
                    // Re-query button inside timeout as it might have changed state/appeared
                    const currentSendBtn = document.querySelector(sendButtonSelector);
                    if (!currentSendBtn) {
                         console.error(`PromptSenderApp (Grok): Could not find button inside timeout: ${sendButtonSelector}`);
                         return; // Implicitly returns JS_NON_STRING_GROK
                    }
                    console.log("PromptSenderApp (Grok): Found button inside timeout.");

                    if (currentSendBtn.disabled || currentSendBtn.hasAttribute('disabled')) {
                        console.warn("PromptSenderApp (Grok): Submit button STILL disabled after native set + InputEvent. State update likely failed.");
                        return; // Implicitly returns JS_NON_STRING_GROK or BUTTON_DISABLED_GROK
                    }

                    console.log("PromptSenderApp (Grok): Button appears enabled. Clicking.");
                    currentSendBtn.click();
                    console.log("PromptSenderApp (Grok): Clicked button.");

                }, 0); // Use timeout 0 for the next macrotask

                return 'OK_GROK_NATIVE_INPUT'; // New status code
            })();
            """
        case .perplexity:
            // --- Logic for Perplexity (Using setTimeout before query) ---
            javascriptString = """
            (function() { // Changed back to regular function
                const promptText = `\(sanitizedPrompt)`;
                const editorSelector = 'textarea#ask-input';
                // Keep both selectors for clarity
                const sendButtonSelector = 'button[aria-label="Send"][type="submit"]';
                const enabledSendButtonSelector = 'button[aria-label="Send"][type="submit"]:not([disabled])';

                console.log("PromptSenderApp (Perplexity): Starting native setter + InputEvent + setTimeout(60).");

                const editor = document.querySelector(editorSelector);
                if (!editor) { // Simpler check is sufficient now
                    console.error(`PromptSenderApp (Perplexity): Could not find editor: ${editorSelector}`);
                    return 'NO_EDITOR_PERPLEXITY';
                }
                console.log("PromptSenderApp (Perplexity): Found editor.");

                // 1. Set the value through the native prototype's setter
                const nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
                if (!nativeSetter) {
                    console.error("PromptSenderApp (Perplexity): Could not get native value setter.");
                    return 'NO_NATIVE_SETTER_PERPLEXITY';
                }
                nativeSetter.call(editor, promptText);
                console.log("PromptSenderApp (Perplexity): Called native value setter.");

                // 2. Dispatch a standard 'input' event
                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (Perplexity): Dispatched standard input event.");

                // 3. Wait ~60ms for React to update DOM, then query and click/fallback
                setTimeout(() => {
                    // Query for the *enabled* button *inside* the timeout
                    const sendButton = document.querySelector(enabledSendButtonSelector);

                    if (sendButton) {
                        // Found the enabled button
                        console.log("PromptSenderApp (Perplexity): Found enabled button after timeout. Clicking.");
                        sendButton.click();
                        console.log("PromptSenderApp (Perplexity): Clicked button.");
                        // Decide on return code - maybe OK_PERPLEXITY_TIMEOUT_CLICK?
                        // Using a distinct one helps debugging if it works vs observer
                        return 'OK_PERPLEXITY_TIMEOUT_CLICK';
                    } else {
                        // Enabled button not found, try fallback
                        console.warn(`PromptSenderApp (Perplexity): Enabled button not found after 60ms (${enabledSendButtonSelector}). Falling back to Enter key.`);
                        try {
                            ['keydown','keyup'].forEach(type =>
                                editor.dispatchEvent(new KeyboardEvent(type, {
                                    key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true, cancelable: true
                                }))
                            );
                            console.log("PromptSenderApp (Perplexity): Simulated Enter key events.");
                             // Use distinct code for fallback success
                            return 'OK_PERPLEXITY_ENTER_FALLBACK_TIMEOUT';
                        } catch (keyError) {
                            console.error("PromptSenderApp (Perplexity): Error simulating Enter key:", keyError);
                             // Use distinct code for fallback failure
                            return 'FAIL_PERPLEXITY_BOTH_TIMEOUT';
                        }
                    }
                    // Note: return statements inside setTimeout don't return from the outer function.
                    // The main function implicitly returns undefined here (JS_NON_STRING...)
                    // which is acceptable as the action was attempted.
                }, 60); // 60ms delay

                // The main function returns *before* the timeout completes.
                // We need a status code indicating the attempt was initiated.
                 return 'OK_PERPLEXITY_ATTEMPT_INITIATED';
            })();
            """
        case .gemini:
             // --- Logic for Gemini (Quill/Angular) ---
             javascriptString = """
             (function() {
                const promptText = `\(sanitizedPrompt)`;
                const editorSelector = 'div[contenteditable="true"][aria-label="Enter a prompt here"]';
                const sendButtonSelector = 'button.send-button[aria-label="Send message"]'; // Using slightly more specific selector

                console.log("PromptSenderApp (Gemini): Starting interaction.");

                const editor = document.querySelector(editorSelector);
                if (!editor) {
                    console.error(`PromptSenderApp (Gemini): Could not find editor: ${editorSelector}`);
                    return 'NO_EDITOR_GEMINI';
                }
                console.log("PromptSenderApp (Gemini): Found editor.");

                // 1. Focus the editor
                editor.focus();
                console.log("PromptSenderApp (Gemini): Focused editor.");

                // 2. Set Content (using textContent for Quill)
                editor.textContent = promptText;
                console.log(`PromptSenderApp (Gemini): Set textContent to: ${promptText}`);

                // 3. Dispatch Input Event (Quill/Angular listens for this)
                // Using InputEvent as suggested
                const inputEvent = new InputEvent('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (Gemini): Dispatched input event.");

                // 4. Wait for Angular change detection, then click button
                setTimeout(() => {
                    const sendButton = document.querySelector(sendButtonSelector);
                    if (!sendButton) {
                        console.error(`PromptSenderApp (Gemini): Could not find button inside timeout: ${sendButtonSelector}`);
                        return; // Implicitly returns JS_NON_STRING_GEMINI
                    }
                    console.log("PromptSenderApp (Gemini): Found button inside timeout.");

                    // Check aria-disabled state
                    const isDisabled = sendButton.getAttribute('aria-disabled') === 'true';
                    if (isDisabled) {
                        console.warn("PromptSenderApp (Gemini): Send button is aria-disabled='true' after dispatching input. Framework interaction likely incomplete or needs more time.");
                        return; // Implicitly returns JS_NON_STRING_GEMINI or BUTTON_DISABLED_GEMINI
                    }

                    console.log("PromptSenderApp (Gemini): Button appears enabled (aria-disabled!=true). Clicking.");
                    sendButton.click();
                    console.log("PromptSenderApp (Gemini): Clicked button.");
                }, 50); // Use suggested 50ms delay

                return 'OK_GEMINI_ATTEMPTED'; // Indicate success attempt
             })();
             """
        case .mistral:
            // --- Logic for Mistral (Le Chat - Shadow DOM Aware) ---
            javascriptString = """
            (async function() { // Use async IIFE
                const promptText = `\(sanitizedPrompt)`;

                // --- Helper Functions ---
                function waitFor(fn, timeout = 2000, interval = 50) {
                    return new Promise(res => {
                        const t0 = performance.now();
                        const id = setInterval(() => {
                            const r = typeof fn === 'function' ? fn() : fn;
                            if (r) {
                                clearInterval(id);
                                res(r);
                            } else if (performance.now() - t0 > timeout) {
                                clearInterval(id);
                                res(null); // Resolve with null on timeout
                            }
                        }, interval);
                    });
                }

                function getVisibleTextarea(doc = document) {
                    let areas = [...doc.querySelectorAll('textarea[name="message.text"]')];
                    doc.querySelectorAll('*').forEach(el => {
                        if (el.shadowRoot) {
                            try {
                                areas = areas.concat(
                                    [...el.shadowRoot.querySelectorAll('textarea[name="message.text"]')]
                                );
                            } catch (e) {
                                 console.warn("Error accessing shadowRoot for", el, e);
                            }
                        }
                    });
                    // Return the one that's actually on screen (rendered and visible)
                    return areas.find(t => t.offsetParent);
                }

                function setReactValue(el, value) {
                    // Use window.HTMLTextAreaElement for safety
                    const proto = window.HTMLTextAreaElement.prototype;
                    const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
                    if (setter) {
                         setter.call(el, value);
                    } else {
                        console.warn("Could not get native value setter for", el);
                        // Fallback? Or rely on error handling below?
                        el.value = value; // Less reliable fallback
                    }
                }

                async function fillMistral(prompt) {
                    console.log("PromptSenderApp (Mistral): Waiting for textarea...");
                    const ta = await waitFor(getVisibleTextarea, 3000);
                    if (!ta) {
                        console.error('PromptSenderApp (Mistral): Textarea not found after wait.');
                        throw new Error('Mistral textarea not found');
                    }
                    console.log("PromptSenderApp (Mistral): Textarea found. Filling...");
                    ta.focus();
                    setReactValue(ta, prompt);
                    ta.dispatchEvent(new Event('input',  { bubbles: true }));
                    ta.dispatchEvent(new Event('change', { bubbles: true }));
                    console.log("PromptSenderApp (Mistral): Textarea filled and events dispatched.");
                }

                async function sendMistral() {
                    const ta = getVisibleTextarea(); // Assume it exists if fill succeeded
                    if (!ta) throw new Error("Textarea vanished before send?"); // Should not happen
                    const root = ta.getRootNode(); // Find root (document or shadowRoot)

                    const btnSel = 'button[type="submit"][aria-label="Send question"]:not([disabled])';
                    console.log("PromptSenderApp (Mistral): Waiting for enabled send button...");
                    const btn = await waitFor(() => root.querySelector(btnSel), 1500); // Shorter timeout for button
                    if (!btn) {
                         console.error('PromptSenderApp (Mistral): Send button still disabled after wait.');
                         throw new Error('Send button still disabled');
                    }
                    console.log("PromptSenderApp (Mistral): Enabled button found. Clicking...");
                    btn.click();
                    console.log("PromptSenderApp (Mistral): Button clicked.");
                }

                // --- Main Execution Logic ---
                try {
                    console.log("PromptSenderApp (Mistral): Starting fill/send sequence...");
                    await fillMistral(promptText);
                    await sendMistral();
                    console.log("PromptSenderApp (Mistral): Fill/send sequence completed successfully.");
                    return 'OK_MISTRAL_SHADOW_ATTEMPTED'; // New success code
                } catch (e) {
                    console.error("PromptSenderApp (Mistral): Error during fill/send:", e);
                    // Return a specific error based on the message if possible
                    if (e.message.includes('textarea not found')) {
                        return 'FAIL_MISTRAL_NO_TEXTAREA';
                    } else if (e.message.includes('still disabled')) {
                         return 'FAIL_MISTRAL_BUTTON_DISABLED';
                    } else {
                         return 'FAIL_MISTRAL_UNKNOWN_ERROR';
                    }
                }
            })();
            """
        }
        // +++ END ADDED CODE ---

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
