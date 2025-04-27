# Project Context Dump (End of Session - Groq Cloud Removed)

## Project Vision

To create a macOS SwiftUI application that acts as a central hub for interacting with multiple AI chat services (like You.com, ChatGPT, Claude, AI Studio, Grok, Perplexity, Gemini, Mistral). The core functionality involves:
*   Displaying each AI service in its own `WKWebView` pane.
*   Providing a single native text input field.
*   Broadcasting the text from the native input field to selected `WKWebView` panes simultaneously.
*   Injecting JavaScript into each `WKWebView` to programmatically insert the prompt text into the respective service's input field and trigger the send action.

## Current Functional State (Post Groq Cloud Removal)

*   The application successfully loads You.com, ChatGPT, Claude.ai, aistudio.google.com, grok.com, perplexity.ai, gemini.google.com/app, and **chat.mistral.ai** into separate panes.
*   Groq Cloud provider (`console.groq.com/playground`) has been **removed** due to persistent integration difficulties.
*   A central native input field exists.
*   A broadcasting mechanism (`MainModel.broadcast`) sends the prompt text to selected panes.
*   JavaScript injection logic exists and is functional for:
    *   **You.com:** Targets `<textarea>`, native setter, `input` event, click button.
    *   **ChatGPT:** Targets `contenteditable` div, `.textContent`, `input` event, `setTimeout`, click button.
    *   **Claude:** Targets `contenteditable` div (ProseMirror), focus, `.textContent`, `input` event, `setTimeout`, click button.
    *   **AI Studio:** Targets `<textarea>` (dynamic `aria-label`), `.value`, `input` event, `setTimeout`, click button.
    *   **Grok:** Targets `<textarea>` (React), focus, **native setter**, specific **`InputEvent(inputType:'insertFromPaste')`**, `setTimeout(0)`, click button.
    *   **Perplexity:** Targets `<textarea>` (React), **native setter**, standard `input` event, `setTimeout(60)` (due to button replacement), query for *enabled* button, click (fallback: Enter key).
    *   **Gemini:** Targets `contenteditable` div (Quill/Angular), focus, `.textContent`, standard `InputEvent`, `setTimeout(50)`, query button, check `aria-disabled`, click.
    *   **Mistral:** Targets `<textarea>` (React, **Shadow DOM**), uses **helper functions** (`waitFor`, `getVisibleTextarea`, `setReactValue`) to find textarea (including shadow roots), focus, **native setter**, dispatch `input`+`change` events, wait for enabled button using `waitFor` on root node (`document` or shadow root), click.
*   The `AIProvider` enum and `MainModel` manage the remaining providers and their URLs.
*   Basic error handling (returning codes like `JS_ERROR_PROVIDER`, `NO_EDITOR_PROVIDER`, provider-specific codes) is implemented.

## Significant Challenges Overcome (Session Summary)

1.  **Framework Interactions:** Successfully integrated Perplexity, Gemini, and Mistral, each requiring specific handling for React/Angular/Quill/ProseMirror (native setters, event types, timing, `disabled`/`aria-disabled` checks).
2.  **DOM Node Replacement (Perplexity):** Addressed issue where React replaced the send button after input by using `setTimeout(60)` before querying for the new, enabled button.
3.  **Shadow DOM (Mistral):** Overcame challenge where the textarea was hidden in shadow DOM by implementing a recursive `getVisibleTextarea` helper and using `waitFor`.
4.  **WKWebView Return Types (Groq Cloud Debugging):** Encountered issues (potentially `WKError 5`) related to complex return types from JS. Refined logic to ensure only simple strings were returned via promise resolution (though Groq Cloud was ultimately removed).
5.  **Responsive UI Issues (Groq Cloud Debugging):** Identified that UI changes based on viewport width (hiding textarea, showing dialog button on mobile) were likely causing selector failures.

## Learnings & Assumptions

*   **Framework Diversity:** No single JS injection method works for all sites. Deep inspection and tailored approaches are necessary.
*   **Native Setters:** Crucial for React/framework-controlled inputs.
*   **Shadow DOM:** Requires specific traversal techniques.
*   **Timing & DOM State:** Asynchronous waits (`waitFor`, `setTimeout`, etc.) are vital to handle framework updates before interacting with elements.
*   **Responsive Design:** Automation must account for UI variations at different viewport sizes if the `WKWebView` might render narrowly.
*   **WKWebView JS Bridge:** Care must be taken with JS return types; stick to primitives or simple objects when returning results from `evaluateJavaScript`.
*   **Assumption:** Current selectors/logic for remaining providers are functional but vulnerable to website updates.

## Potential Next Steps (Not Yet Implemented)

*   Refining error handling (more specific codes, UI feedback).
*   UI/UX improvements (e.g., loading indicators, result parsing).
*   Persistence (e.g., saving window size/position).
*   Adding other providers (if desired).
