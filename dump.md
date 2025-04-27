# Project Context Dump (End of Grok Integration Session)

## Project Vision

To create a macOS SwiftUI application that acts as a central hub for interacting with multiple AI chat services (like You.com, ChatGPT, Claude, AI Studio, Grok). The core functionality involves:
*   Displaying each AI service in its own `WKWebView` pane.
*   Providing a single native text input field.
*   Broadcasting the text from the native input field to selected `WKWebView` panes simultaneously.
*   Injecting JavaScript into each `WKWebView` to programmatically insert the prompt text into the respective service's input field and trigger the send action.

## Current Functional State

*   The application successfully loads You.com, ChatGPT, Claude.ai, aistudio.google.com, and grok.com into separate panes.
*   A central native input field exists.
*   A broadcasting mechanism (`MainModel.broadcast`) sends the prompt text to selected panes.
*   JavaScript injection logic exists and is functional for:
    *   **You.com:** Targets `#search-input-textarea`, uses native value setter, dispatches `input`, clicks `button[type="submit"]`.
    *   **ChatGPT:** Targets `div#prompt-textarea[contenteditable="true"]`, sets `.textContent`, dispatches `input`, waits, finds `button[data-testid="send-button"]`, checks `disabled`, clicks.
    *   **Claude:** Targets `div.ProseMirror[contenteditable="true"]`, focuses, sets `.textContent`, dispatches `input`, waits (`setTimeout`), finds `button[aria-label="Send message"]`, checks `disabled`, clicks.
    *   **AI Studio:** Targets `textarea` using combined selector `textarea[aria-label="Type something"], textarea[aria-label="Type something or pick one from prompt gallery"]`, sets `.value`, dispatches `input`, waits (`setTimeout`), finds `button[aria-label="Run"]`, checks `disabled`, clicks.
    *   **Grok:** Targets `textarea[aria-label="Ask Grok anything"]`, focuses, uses **native prototype value setter**, dispatches specific **`InputEvent('input', {inputType: 'insertFromPaste', ...})`**, waits (`setTimeout 0`), finds `button[aria-label="Submit"]`, checks `disabled`, clicks.
*   The `AIProvider` enum and `MainModel` manage the different providers and their URLs.
*   Basic error handling (returning codes like `JS_ERROR_PROVIDER`, `NO_EDITOR_PROVIDER`) is implemented in the JavaScript evaluation callback.

## Significant Challenges Overcome

1.  **Rich Text Editor Interactions (ChatGPT/Claude):** Required specific handling for `contenteditable` divs, event dispatching, and delays.
2.  **Dynamic Selectors (AI Studio):** Handled changing `aria-label` using combined CSS selectors.
3.  **Complex Framework Interaction (Grok/React):**
    *   Initial attempts (setting `.value`, dispatching simple `input`/`change`/`key` events, character simulation) failed to update React's internal state, leaving placeholder text visible and the submit button disabled.
    *   Manual Backspace observation provided the key clue.
    *   **Solution:** Required using the `window.HTMLTextAreaElement.prototype.value` native setter (to update React's internal value tracker) combined with dispatching a specific `InputEvent` configured with `inputType: 'insertFromPaste'` to correctly mimic trusted input and trigger React's state update mechanism.

## Learnings & Assumptions

*   **Framework Nuances:** Deep framework knowledge (React's controlled components, value tracking, SyntheticEvent system) can be crucial for reliable automation. Standard DOM manipulation/event dispatching is often insufficient.
*   **Native Setters:** For frameworks that wrap input handling (like React), directly using the element's `.value = ...` might bypass internal state tracking. Using the native prototype setter (`Object.getOwnPropertyDescriptor(...).set.call(...)`) can be necessary.
*   **Specific Event Types/Properties:** Frameworks might expect specific event types (`InputEvent` vs `Event`) or properties (`inputType`) for certain actions, especially when trying to mimic trusted events like pasting.
*   **`isTrusted`:** Cannot be forged, but frameworks might ignore this flag for specific event types (like `InputEvent` with `insertFromPaste` for Grok) while checking it for others (like keyboard events).
*   **Debugging Clues:** Seemingly minor manual interactions (like Backspace fixing the state) can provide critical clues about the underlying event handling logic.
*   **Workflow:** The iterative process (implement, test, debug with inspector, consult helper LLM for deeper analysis, refine) remains essential.
*   **Assumption:** Current selectors/logic are functional but vulnerable to website updates.

## Potential Next Steps (Not Yet Implemented)

*   Refining error handling (`MutationObserver`?).
*   Adding more providers.
*   UI/UX improvements.
*   Persistence.

# Project Context Dump (End of Perplexity Integration Session)

## Project Vision

To create a macOS SwiftUI application that acts as a central hub for interacting with multiple AI chat services (like You.com, ChatGPT, Claude, AI Studio, Grok, Perplexity). The core functionality involves:
*   Displaying each AI service in its own `WKWebView` pane.
*   Providing a single native text input field.
*   Broadcasting the text from the native input field to selected `WKWebView` panes simultaneously.
*   Injecting JavaScript into each `WKWebView` to programmatically insert the prompt text into the respective service's input field and trigger the send action.

## Current Functional State

*   The application successfully loads You.com, ChatGPT, Claude.ai, aistudio.google.com, grok.com, and **perplexity.ai** into separate panes.
*   A central native input field exists.
*   A broadcasting mechanism (`MainModel.broadcast`) sends the prompt text to selected panes.
*   JavaScript injection logic exists and is functional for:
    *   **You.com:** Targets `#search-input-textarea`, uses native value setter, dispatches `input`, clicks `button[type="submit"]`.
    *   **ChatGPT:** Targets `div#prompt-textarea[contenteditable="true"]`, sets `.textContent`, dispatches `input`, waits, finds `button[data-testid="send-button"]`, checks `disabled`, clicks.
    *   **Claude:** Targets `div.ProseMirror[contenteditable="true"]`, focuses, sets `.textContent`, dispatches `input`, waits (`setTimeout`), finds `button[aria-label="Send message"]`, checks `disabled`, clicks.
    *   **AI Studio:** Targets `textarea` using combined selector, sets `.value`, dispatches `input`, waits (`setTimeout`), finds `button[aria-label="Run"]`, checks `disabled`, clicks.
    *   **Grok:** Targets `textarea[aria-label="Ask Grok anything"]`, focuses, uses **native prototype value setter**, dispatches specific **`InputEvent` with `inputType: 'insertFromPaste'`**, waits (`setTimeout 0`), finds `button[aria-label="Submit"]`, checks `disabled`, clicks.
    *   **Perplexity:** Targets `textarea#ask-input`, uses **native prototype value setter**, dispatches standard `input` event, waits (`setTimeout 60`), queries for **enabled** `button[aria-label="Send"][type="submit"]:not([disabled])`, clicks (or falls back to Enter key simulation).
*   The `AIProvider` enum and `MainModel` manage the different providers and their URLs.
*   Basic error handling (returning codes like `JS_ERROR_PROVIDER`, `NO_EDITOR_PROVIDER`, provider-specific codes) is implemented.

## Significant Challenges Overcome

1.  **Rich Text Editor Interactions (ChatGPT/Claude):** Required specific handling for `contenteditable` divs, event dispatching, and delays.
2.  **Dynamic Selectors (AI Studio):** Handled changing `aria-label` using combined CSS selectors.
3.  **Complex Framework Interaction (Grok/React):** Required native setter + specific `InputEvent` to update internal state.
4.  **DOM Node Replacement (Perplexity/React):** The initial button click failed because React replaced the button node after the `input` event. Waiting with `setTimeout(0)` was unreliable. `MutationObserver` worked but added latency. **Solution:** Using `setTimeout(60)` before querying for the *new*, *enabled* button node proved effective.

## Learnings & Assumptions

*   **Framework Nuances:** Deep framework knowledge (React's controlled components, state updates, DOM node replacement patterns) is crucial.
*   **Native Setters:** Essential for React inputs.
*   **Event Timing & DOM Updates:** Frameworks might update the DOM *after* the event that triggered the update has finished processing. Caching element references before the update can lead to stale references. Waiting (via `setTimeout` or `MutationObserver`) before interacting with potentially changed elements is necessary.
*   **Debugging Clues:** Observing failed interactions (like clicking a non-existent button) and relating them to framework behavior (node replacement) is key.
*   **Iterative Refinement:** Trying different approaches (`setTimeout(0)`, `MutationObserver`, `setTimeout(fixed_delay)`) is sometimes needed to find the optimal balance between reliability and performance.
*   **Assumption:** Current selectors/logic are functional but vulnerable to website updates.

## Potential Next Steps (Not Yet Implemented)

*   Integrate Gemini.
*   Integrate Mistral (Le Chat).
*   Refining error handling (more specific codes, UI feedback).
*   UI/UX improvements.
*   Persistence.

# Project Context Dump (End of Gemini Integration Session)

## Project Vision

To create a macOS SwiftUI application that acts as a central hub for interacting with multiple AI chat services (like You.com, ChatGPT, Claude, AI Studio, Grok, Perplexity, Gemini). The core functionality involves:
*   Displaying each AI service in its own `WKWebView` pane.
*   Providing a single native text input field.
*   Broadcasting the text from the native input field to selected `WKWebView` panes simultaneously.
*   Injecting JavaScript into each `WKWebView` to programmatically insert the prompt text into the respective service's input field and trigger the send action.

## Current Functional State

*   The application successfully loads You.com, ChatGPT, Claude.ai, aistudio.google.com, grok.com, perplexity.ai, and **gemini.google.com/app** into separate panes.
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
*   The `AIProvider` enum and `MainModel` manage the different providers and their URLs.
*   Basic error handling (returning codes like `JS_ERROR_PROVIDER`, `NO_EDITOR_PROVIDER`, provider-specific codes) is implemented.

## Significant Challenges Overcome

1.  **Rich Text Editor Interactions (ChatGPT/Claude/Gemini):** Required specific handling for `contenteditable` divs (ProseMirror, Quill), event dispatching (`input`, `InputEvent`), and delays (`setTimeout`). Gemini required checking `aria-disabled`.
2.  **Dynamic Selectors (AI Studio):** Handled changing `aria-label` using combined CSS selectors.
3.  **Complex Framework Interaction (Grok/React):** Required native setter + specific `InputEvent` to update internal state.
4.  **DOM Node Replacement (Perplexity/React):** Required `setTimeout(60)` before querying for the *new, enabled* button node after `input` event.

## Learnings & Assumptions

*   **Framework Nuances:** Deep framework knowledge (React, Angular, Quill, ProseMirror) is crucial. Different frameworks require different combinations of native setters, event types (`input`, `InputEvent`), event properties (`inputType`), attribute checks (`disabled`, `aria-disabled`), and timing (`setTimeout`).
*   **Native Setters:** Essential for React inputs.
*   **Event Timing & DOM Updates:** Frameworks might update the DOM *after* the event. Waiting (`setTimeout`) before interacting with potentially changed elements is often necessary.
*   **Attribute Variations:** Use `disabled` for standard elements, but check for `aria-disabled` in frameworks like Angular/Material.
*   **Iterative Refinement:** Testing and adjusting timing (`setTimeout`) or interaction methods (Observer vs. fixed delay) is key.
*   **Assumption:** Current selectors/logic are functional but vulnerable to website updates.

## Potential Next Steps (Not Yet Implemented)

*   Integrate Mistral (Le Chat).
*   Refining error handling (more specific codes, UI feedback).
*   UI/UX improvements.
*   Persistence.

# Project Context Dump (End of Mistral Integration Session)

## Project Vision

To create a macOS SwiftUI application that acts as a central hub for interacting with multiple AI chat services (like You.com, ChatGPT, Claude, AI Studio, Grok, Perplexity, Gemini, Mistral). The core functionality involves:
*   Displaying each AI service in its own `WKWebView` pane.
*   Providing a single native text input field.
*   Broadcasting the text from the native input field to selected `WKWebView` panes simultaneously.
*   Injecting JavaScript into each `WKWebView` to programmatically insert the prompt text into the respective service's input field and trigger the send action.

## Current Functional State

*   The application successfully loads You.com, ChatGPT, Claude.ai, aistudio.google.com, grok.com, perplexity.ai, gemini.google.com/app, and **chat.mistral.ai** into separate panes.
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
*   The `AIProvider` enum and `MainModel` manage the different providers and their URLs.
*   Basic error handling (returning codes like `JS_ERROR_PROVIDER`, `NO_EDITOR_PROVIDER`, provider-specific codes) is implemented.

## Significant Challenges Overcome

1.  **Rich Text Editor Interactions (ChatGPT/Claude/Gemini):** Required specific handling for `contenteditable` divs (ProseMirror, Quill), event dispatching (`input`, `InputEvent`), and delays (`setTimeout`). Gemini required checking `aria-disabled`.
2.  **Dynamic Selectors (AI Studio):** Handled changing `aria-label` using combined CSS selectors.
3.  **Complex Framework Interaction (Grok/React):** Required native setter + specific `InputEvent` to update internal state.
4.  **DOM Node Replacement (Perplexity/React):** Required `setTimeout(60)` before querying for the *new, enabled* button node after `input` event.
5.  **Shadow DOM (Mistral):** The textarea was hidden inside a shadow root, requiring a custom `getVisibleTextarea` function to traverse shadow boundaries. Used `waitFor` utility to robustly wait for elements.

## Learnings & Assumptions

*   **Framework Nuances:** Deep framework knowledge (React, Angular, Quill, ProseMirror) is crucial. Different frameworks require different combinations of native setters, event types, attribute checks, timing, and DOM traversal (including shadow DOM).
*   **Native Setters:** Essential for most React/framework-controlled inputs.
*   **Shadow DOM:** Standard `querySelector` doesn't pierce shadow boundaries. Requires recursive searching through `element.shadowRoot` or specific libraries/techniques.
*   **Element Visibility & Timing:** Elements might exist in the DOM but not be visible (`offsetParent` check) or enabled. Asynchronous waits (`waitFor`, `setTimeout`, `requestAnimationFrame`, `MutationObserver`) are often needed before interaction.
*   **Attribute Variations:** Use `disabled` for standard elements, `aria-disabled` for some frameworks.
*   **Iterative Refinement:** Testing and adjusting timing/methods based on specific site behavior is essential.
*   **Assumption:** Current selectors/logic are functional but highly vulnerable to website updates, especially regarding shadow DOM structure and framework internals.

## Potential Next Steps (Not Yet Implemented)

*   Refining error handling (more specific codes, UI feedback).
*   UI/UX improvements (e.g., loading indicators, result parsing).
*   Persistence (e.g., saving window size/position).
*   Adding more providers.
