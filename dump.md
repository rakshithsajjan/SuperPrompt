# Project Context Dump (End of AI Studio Integration Session)

## Project Vision

To create a macOS SwiftUI application that acts as a central hub for interacting with multiple AI chat services (like You.com, ChatGPT, Claude, AI Studio). The core functionality involves:
*   Displaying each AI service in its own `WKWebView` pane.
*   Providing a single native text input field.
*   Broadcasting the text from the native input field to selected `WKWebView` panes simultaneously.
*   Injecting JavaScript into each `WKWebView` to programmatically insert the prompt text into the respective service's input field and trigger the send action.

## Current Functional State

*   The application successfully loads You.com, ChatGPT, Claude.ai, and aistudio.google.com into separate panes.
*   A central native input field exists.
*   A broadcasting mechanism (`MainModel.broadcast`) sends the prompt text to selected panes.
*   JavaScript injection logic exists and is functional for:
    *   **You.com:** Targets `#search-input-textarea`, uses native value setter, dispatches `input`, clicks `button[type="submit"]`.
    *   **ChatGPT:** Targets `div#prompt-textarea[contenteditable="true"]`, sets `.textContent`, dispatches `input`, waits, finds `button[data-testid="send-button"]`, checks `disabled`, clicks.
    *   **Claude:** Targets `div.ProseMirror[contenteditable="true"]`, focuses, sets `.textContent`, dispatches `input`, waits (`setTimeout`), finds `button[aria-label="Send message"]`, checks `disabled`, clicks.
    *   **AI Studio:** Targets `textarea` using combined selector `textarea[aria-label="Type something"], textarea[aria-label="Type something or pick one from prompt gallery"]`, sets `.value`, dispatches `input`, waits (`setTimeout`), finds `button[aria-label="Run"]`, checks `disabled`, clicks.
*   The `AIProvider` enum and `MainModel` manage the different providers and their URLs.
*   Basic error handling (returning codes like `JS_ERROR_PROVIDER`, `NO_EDITOR_PROVIDER`) is implemented in the JavaScript evaluation callback.

## Significant Challenges Overcome

1.  **Rich Text Editor Interactions (ChatGPT/Claude):** Required specific handling for `contenteditable` divs, including setting `.textContent`, dispatching `input` events, and using `setTimeout` before clicking buttons due to framework state updates (ProseMirror).
2.  **JavaScript Syntax Errors (Claude):** Debugged and fixed errors caused by extraneous backslashes in Swift multi-line string literals.
3.  **Dynamic Selectors (AI Studio):** The `aria-label` for the AI Studio input `<textarea>` changed after the first prompt submission. This required identifying the change via web inspection and implementing a combined CSS selector (`selector1, selector2`) in the JavaScript to reliably target the element in both its initial and subsequent states.

## Learnings & Assumptions

*   **Frameworks & State:** Modern web apps heavily rely on frameworks (React, Angular, Vue) and JavaScript events (`input`) to manage state. Direct DOM manipulation often requires careful event dispatching and sometimes delays (`setTimeout`) or observers (`MutationObserver`) to work correctly with framework lifecycles.
*   **`contenteditable` Complexity:** These elements require different interaction patterns than standard `<textarea>`s.
*   **Selector Stability:** Attributes like `aria-label` or `data-testid` are *usually* more stable than generated classes, but they *can* be dynamic, as seen with AI Studio. Using combined selectors or more structural selectors (with caution) might be necessary.
*   **Workflow:** The established workflow (helper LLM analysis -> implementation -> testing -> debugging with web inspector) remains effective.
*   **Assumption:** Current selectors and interaction logic are functional but may require updates if the target websites change significantly.
*   **Assumption:** Basic text sanitization is sufficient.

## Potential Next Steps (Not Yet Implemented)

*   Refining error handling (more specific codes, `MutationObserver` for button states).
*   Adding more AI providers.
*   UI/UX improvements (broadcast feedback, pane management).
*   Persistence.
