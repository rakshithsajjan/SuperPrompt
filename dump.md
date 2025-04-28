# Project Context Summary: Prompt-You (UI Phase - Part 1 - Enhanced)

## Vision

A macOS SwiftUI application designed to broadcast user prompts simultaneously to multiple AI chat service web interfaces (`ChatGPT`, `Claude`, `Gemini`, `You.com`, `Perplexity`, `AI Studio`, `Grok`, `Mistral`) hosted within individual `WKWebView` panes. The goal is a streamlined workflow for comparing responses across different models.

## Functional State at Start of UI Phase

*   **Provider Integration:** All target providers successfully integrated via `WKWebView`. Each provider identified in the `AIProvider` enum with its default URL.
*   **JS Injection Core:** Robust JavaScript injection logic (`ChatPane.sendCurrentPrompt`) tailored for each provider to handle diverse input methods:
    *   Standard `<textarea>` (e.g., You.com, AI Studio) using `.value` or native setters + `input` event.
    *   `contenteditable` divs (e.g., ChatGPT, Claude, Gemini/Quill) using `.textContent` + `input`/`InputEvent`.
    *   Framework-heavy `<textarea>` (e.g., Grok, Perplexity/React) using native setters + specific `InputEvent` types (`insertFromPaste`) or standard `input` + carefully timed `setTimeout` delays to account for DOM changes (like button replacement) triggered by framework state updates.
    *   Attribute checks (`disabled`, `aria-disabled`) crucial for determining button readiness post-input.
    *   **Shadow DOM Handling (Mistral):** Required custom JS helpers (`waitFor`, `getVisibleTextarea`, `setReactValue`) for recursively searching shadow roots and reliably interacting with elements within them.
*   **Broadcasting:** `MainModel.broadcast` functional, iterating selected panes (initially) with hardcoded delays.
*   **Initial UI:** Basic SwiftUI grid layout (`GeometryReader`, `HStack`) showing selected panes. Rudimentary bottom bar with checkboxes for selection, a `TextField`, and a Send button.

## UI/UX Improvement Phase (Progress & Rationale)

*   **Dynamic Panes:**
    *   Refactored `MainModel.panes` to `[ChatPane]`, initialized empty.
    *   Added `addPane(provider:)` and `removePane(id:)` methods.
    *   *Rationale:* Support user adding/removing panes dynamically, removing fixed provider list.
*   **Horizontal Scrolling & Initial Issues:**
    *   Replaced grid with `ScrollView(.horizontal)` containing an `HStack` of panes (`ZStack` containing `WebViewWrapper`). Applied fixed `paneWidth`.
    *   **Problem:** Horizontal trackpad/wheel scrolling failed. Diagnosis: Inner `WKWebView`'s `NSScrollView` intercepted scroll events.
*   **Scrolling Fix Iteration:**
    *   **Attempt 1 (Subclassing `WKWebView` - `PaneWebView`):** Overrode `scrollWheel(with:)` to check `event.scrollingDeltaX` vs `scrollingDeltaY` and pass horizontal events via `nextResponder?.scrollWheel(with: event)`.
        *   *Result:* Enabled scrolling but caused visual jitter (inner and outer views fighting over scroll events).
        *   *Dead End:* Attempts to *disable* internal horizontal scrolling (`scrollView.hasHorizontalScroller`, etc.) within the subclass failed due to `WKWebView.scrollView` not being publicly accessible on macOS SDK, causing build errors.
    *   **Attempt 2 (Custom `NSScrollView` Wrapper - `HostingScrollView`):** Created `HostingScrollView<Content: View>: NSViewRepresentable`.
        *   Creates/configures an `NSScrollView` (horizontal only).
        *   Wraps the SwiftUI `HStack` of panes in an `NSHostingView` and sets it as the `NSScrollView`'s `documentView`.
        *   Uses Auto Layout constraints to manage sizing.
        *   *Result:* Successfully decoupled inner web view scrolling from outer pane scrolling, eliminating jitter and achieving smooth horizontal scrolling.
        *   *Rationale:* Avoids nested scroll views, the root cause of the event conflict.
*   **Window Style:** Applied `.windowStyle(.hiddenTitleBar)` to `WindowGroup` for a borderless look. Used `.ignoresSafeArea(.container, edges: .top)` on the main `VStack` to allow content to draw under the window controls (traffic lights).
*   **Bottom Bar Redesign:**
    *   Removed top bar; moved "Add Pane" `Menu` to bottom `HStack`.
    *   Styled "Add Pane" `Menu` as borderless button (`Image(systemName: "plus")`), added `.fixedSize()` to ensure minimal layout impact.
    *   Used `Spacer()`s to left-align "+" button and center the input+send group.
    *   Replaced single-line `TextField` with multi-line `TextEditor` inside a `ZStack` (for placeholder text overlay).
    *   Constrained `TextEditor` height (`.frame(minHeight: 30, maxHeight: 140)`) and used `.fixedSize(horizontal: false, vertical: true)` for dynamic vertical expansion. Added slightly larger font (`.body.leading(.loose)`).
    *   Applied styling (`.clipShape`, `.overlay`) to `TextEditor` container. Added `TransparentRepresentable` helper for reliable background control.
    *   Set bottom `HStack` alignment to `.center` for better vertical alignment of buttons with resizing `TextEditor`.
*   **Keyboard Shortcuts:**
    *   Added Command+Enter for sending prompts (via hidden button).
    *   Added Command+Number (1-9) for direct pane focus (via `ForEach` loop generating hidden buttons).
    *   Added Command+Shift+[` / `]` for cycling pane focus (via hidden buttons).
*   **Focus Management:**
    *   Added `@Published var focusedPaneIndex: Int?` to `MainModel`.
    *   Added `cycleFocus(forward:)` and `setFocus(to:)` methods to `MainModel`. `addPane` and `removePane` updated to manage `focusedPaneIndex`.
    *   Used `.onChange(of: model.focusedPaneIndex)` in `ContentView` to call `window.makeFirstResponder()` on the target `WKWebView` (wrapped in `DispatchQueue.main.async` with window check for safety).
    *   **Auto-Scrolling:** Enhanced `HostingScrollView` to accept `@Binding focusedPaneIndex`, `paneCount`, `paneWidth`. Added `Coordinator` to track previous index. In `updateNSView`, if index changed, calculate target rect and call `contentView.scroll(to:)` within `NSAnimationContext` for smooth animated scroll.
*   **Notifications:**
    *   Added `@State` variables (`showFocusNotification`, `focusNotificationText`) in `ContentView`.
    *   Used `.onChange` on `focusedPaneIndex` and `model.panes.count` to trigger updates to notification text.
    *   Displayed notification text in a `Text` view overlaid via `ZStack`, using `.transition` for appear/disappear animation and `DispatchQueue.main.asyncAfter` to hide automatically. Includes pane title and Cmd+Number shortcut on add/focus.

## Current Functional State

*   Application launches borderless, content extends under traffic lights.
*   Panes added via "+" button in bottom bar. Dynamic horizontal scrolling via custom `HostingScrollView` is smooth. Panes closable via "x" button.
*   Bottom bar: Left "+", centered (multi-line, expanding `TextEditor` with placeholder + Send button). Controls remain vertically centered.
*   Prompt sending via Send button or Cmd+Enter.
*   Pane focus via Cmd+Number (1-9) or Cmd+Shift+Brackets.
*   **Auto-scroll works:** Focusing an off-screen pane scrolls it smoothly into view.
*   **Notifications work:** Transient overlays confirm focus changes and new pane additions (showing title and Cmd+N shortcut).

## Current Challenges / Known Issues

*   **Trailing Scroll Space:** When scrolled fully to the right, a small gap persists between the right edge of the last pane and the right edge of the visible scroll area. Removing the final `Divider` and setting `NSScrollView.contentView.contentInsets` to zero did *not* resolve this, suggesting a potential issue with `NSHostingView` sizing or constraint interaction within the `NSScrollView`.

## Key Learnings (Enhanced)

*   **AppKit/SwiftUI Interop:** Necessity of `NSViewRepresentable` (`HostingScrollView`, `WebViewWrapper`) for integrating `NSScrollView` and `WKWebView`. Understanding `NSHostingView` for embedding SwiftUI in AppKit.
*   **Scroll Event Handling:** Deep understanding of the macOS responder chain and event conflicts (demonstrated by `WKWebView` vs. `ScrollView` jitter). Power of subclassing (`PaneWebView`) to intercept/modify event flow. Limitations of macOS SDK (inability to access `WKWebView.scrollView` publicly).
*   **Focus Management:** Bridging focus concepts between AppKit (`makeFirstResponder`) and SwiftUI state (`@Published`, `@Binding`, `.onChange`). Importance of timing/safety checks (`DispatchQueue.main.async`, `window` check).
*   **SwiftUI Layout:** Nuances of `Spacer`, `.frame(maxWidth/maxHeight)`, `.fixedSize()`, alignment (`.center` vs `.bottom`), safe areas (`.ignoresSafeArea`), and dynamic sizing (`TextEditor` height constraints).
*   **WKWebView & JS:** Reconfirmed the need for site-specific JS injection strategies and robust handling of timing/framework updates.
*   **Debugging:** Iterative process involving visual aids (background colors), build error analysis (SDK limitations), and logical deduction (responder chain conflicts).

## Next Steps (UI)

*   **Resolve Trailing Space:** Investigate `NSHostingView` sizing behavior or alternative constraint setups within `HostingScrollView`. Could also involve adding a tiny negative padding/offset somewhere as a workaround if the root cause is elusive.
*   Implement pane profiles.
*   Implement provider restrictions for multiple instances.
*   Further UI polish.

## New Tab Functionality (Cmd+T)

*   **Goal:** Implement a standard macOS "New Tab" behavior using Cmd+T. This should append a new, focused pane that initially shows an inline list of available AI providers. Selecting a provider replaces the list with a fully functional `ChatPane` loading that provider's URL, making the transition seamless.
*   **Implementation Strategy:** Followed a detailed, additive plan designed to minimize changes to existing code:
    1.  **`ChatPane.swift`:**
        *   Added a boolean `@Published var isProviderPicker` flag to track the pane's temporary state.
        *   Added a `loadOnInit: Bool = true` parameter to the `init` method (defaulting to `true` to maintain existing behavior) to prevent URL loading for picker panes.
        *   Created a static factory method `newTabPicker()` that initializes a `ChatPane` with dummy data, `loadOnInit: false`, and sets `isProviderPicker = true`.
    2.  **`MainModel.swift`:**
        *   Added `openNewTabPicker()`: Called by the Cmd+T shortcut, this creates a picker pane using the factory, appends it to the `panes` array, sets `focusedPaneIndex` to the new pane, and saves state.
        *   Added `replacePicker(at:with:)`: Called by the picker overlay's selection action, this replaces the placeholder pane at the given index with a standard `ChatPane` initialized with the chosen provider, keeps focus on that index, and saves state.
    3.  **`ProviderPickerOverlay.swift` (New File):**
        *   Created a simple, self-contained SwiftUI view that displays a list of `AIProvider` cases as buttons within a `.regularMaterial` background. It takes an `onSelect: (AIProvider) -> Void` closure which is executed when a provider button is clicked.
    4.  **`ContentView.swift`:**
        *   Added a hidden `Button` linked to the `model.openNewTabPicker()` action with the `.keyboardShortcut("t", modifiers: .command)`.
        *   Modified the main `ForEach` loop iterating over `model.panes` to use `Array(model.panes.enumerated())` to gain access to the `index` (`idx`).
        *   Inside the pane's `ZStack`, added a conditional block: `if pane.isProviderPicker { ProviderPickerOverlay { provider in model.replacePicker(at: idx, with: provider) } ... }`. This displays the overlay only when the flag is true and calls the `replacePicker` method with the correct index and selected provider.
*   **Linter Issue & Resolution:**
    *   Encountered a persistent linter error: `'guard' body must not fall through, consider using a 'return' or 'throw' to exit the scope`, initially pointing to the first `guard` statement in `MainModel.replacePicker` (line 269).
    *   Initial attempts to add the missing `return` using the edit tool failed multiple times, even though file reads suggested the code *was* correct.
    *   Realized the *second* `guard` statement (checking `isProviderPicker`) also lacked an exit in its `else` block. Adding a `return` there was also initially unsuccessful via the standard edit/reapply tools.
    *   Resolved the issue by replacing the entire function block (`openNewTabPicker` and `replacePicker`) using the edit tool, which successfully included the `return` statements in *both* `guard` blocks' `else` clauses.

## Current Functional State (Post Cmd+T)

*   All previous functionality remains intact.
*   Cmd+T successfully adds a new, focused pane displaying the provider picker overlay.
*   Selecting a provider from the overlay correctly replaces the picker pane with a functional `ChatPane` for the chosen provider, which then loads the URL.

---
*Generated automatically to transfer context to a new LLM instance.*
