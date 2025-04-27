# Project Context Summary: Prompt-You (UI Phase - Part 1)

## Vision

A macOS SwiftUI application designed to broadcast user prompts simultaneously to multiple AI chat service web interfaces (`ChatGPT`, `Claude`, `Gemini`, `You.com`, `Perplexity`, `AI Studio`, `Grok`, `Mistral`) hosted within individual `WKWebView` panes.

## Functional State at Start of UI Phase

*   All target providers successfully integrated, loading in separate `WKWebView` panes.
*   JavaScript injection implemented for each provider to handle diverse input methods (textarea, contenteditable divs, various frameworks like React, Angular, Quill, ProseMirror). Techniques included native setters, diverse event dispatches (`input`, `InputEvent`, `KeyboardEvent`), `setTimeout` delays, attribute checks (`disabled`, `aria-disabled`), and Shadow DOM traversal (Mistral).
*   Core broadcasting mechanism (`MainModel.broadcast`) functional, sending prompts to selected panes sequentially with delays.
*   Basic grid layout displaying selected panes.

## UI/UX Improvement Phase (Progress)

*   **Dynamic Panes:** Refactored `MainModel` to handle a dynamic `panes: [ChatPane]` array instead of a fixed list. Added `addPane` and `removePane` functions.
*   **Horizontal Scrolling (Initial Attempt):** Replaced the grid with a SwiftUI `ScrollView(.horizontal)` containing an `HStack` of panes, each with a fixed width (`paneWidth`).
*   **Scrolling Issue Diagnosis:** Identified that the inner `WKWebView`'s default scroll handling intercepted horizontal scroll gestures, preventing the outer SwiftUI `ScrollView` from working.
*   **Scrolling Fix Attempt 1 (Subclassing `WKWebView`):** Created `PaneWebView` subclass overriding `scrollWheel(with:)` to pass horizontal events up the responder chain (`nextResponder?.scrollWheel(with: event)`). This enabled scrolling but introduced visual jitter/stutter due to conflicting scroll actions. Attempts to disable internal scrolling via `scrollView` properties failed due to macOS SDK limitations.
*   **Scrolling Fix Attempt 2 (Custom `NSScrollView`):** Replaced SwiftUI `ScrollView` with a custom `NSViewRepresentable` (`HostingScrollView`) wrapping a native `NSScrollView`. The SwiftUI `HStack` of panes is hosted within this `NSScrollView`'s `documentView`. This successfully eliminated nested scroll view conflicts and achieved smooth horizontal scrolling.
*   **Window Style:** Hid the standard macOS window title bar (`windowStyle(.hiddenTitleBar)`) for a cleaner look.
*   **Bottom Bar Redesign:**
    *   Moved the "Add Pane" `Menu` from a top bar to the bottom control bar, styled as a simple "+" button (`.menuStyle(.borderlessButton)`).
    *   Used `Spacer`s to position the "+" button left and center the input area + send button.
    *   Replaced single-line `TextField` with a multi-line `TextEditor` wrapped in a `ZStack` to handle placeholder text.
    *   Constrained `TextEditor` height (`.frame(minHeight:, maxHeight:)`) to allow dynamic expansion up to ~7 lines.
    *   Styled the `TextEditor` container to resemble a standard input field.
*   **Keyboard Shortcuts:**
    *   Added Command+Enter shortcut for sending prompts (via a hidden button).
    *   Added Command+Number (1-9) shortcuts to directly focus specific panes.
    *   Added Command+Shift+[` and `]` shortcuts to cycle focus between panes.
*   **Focus Management:**
    *   Implemented `focusedPaneIndex` state in `MainModel`.
    *   Added `cycleFocus` and `setFocus` methods to `MainModel`.
    *   Used `.onChange(of: model.focusedPaneIndex)` in `ContentView` to trigger `window.makeFirstResponder()` on the corresponding `WKWebView`'s window.
    *   Implemented **Auto-Scrolling:** Modified `HostingScrollView` to observe `focusedPaneIndex` and use `NSScrollView.contentView.scroll(to:)` within an `NSAnimationContext` to automatically bring the focused pane into view.
*   **Notifications:** Added transient, animated overlay notifications at the bottom for:
    *   Focus changes ("Focused: \[Pane Title]").
    *   New panes added ("Added: \[Pane Title] (Cmd+N)").

## Current Functional State

*   Application launches with a hidden title bar.
*   Panes can be added dynamically via the "+" menu in the bottom bar.
*   Panes are displayed in a horizontally scrolling view powered by a custom `NSScrollView`. Scrolling is smooth.
*   Panes can be closed via an "x" button overlay.
*   The bottom bar features a "+" button (left), a centered multi-line `TextEditor` (expands up to 7 lines), and a Send button (right of text editor).
*   Prompts can be sent via the Send button or Command+Enter.
*   Focus can be shifted between panes using Command+Number (1-9) or Command+Shift+Brackets.
*   The view automatically scrolls horizontally to bring the newly focused pane into view.
*   Notifications briefly appear confirming focus changes and new pane additions (including their Command+Number shortcut).

## Current Challenges / Known Issues

*   **Trailing Scroll Space:** A small amount of extra scrollable space exists after the rightmost pane, preventing it from sitting perfectly flush with the window edge when scrolled fully right. (Attempts to fix by removing the last divider and setting `contentInsets` to zero were unsuccessful).

## Key Learnings

*   Deep dive into SwiftUI and AppKit interoperability (`NSViewRepresentable`, `NSHostingView`, `NSScrollView`).
*   Handling scroll event propagation and conflicts between nested scrollable views (`WKWebView` internals vs. SwiftUI `ScrollView` vs. `NSScrollView`).
*   Implementing custom focus management across SwiftUI and AppKit views (`makeFirstResponder`, `onChange`, state management).
*   Creating dynamic multi-line input fields using `TextEditor` and placeholder overlays.
*   Implementing various keyboard shortcuts (`.keyboardShortcut`).
*   Creating non-intrusive UI notifications using overlays, state, and animations.
*   Debugging layout issues involving `Spacer`s, `frame` modifiers, safe areas (`.ignoresSafeArea`), and `NSScrollView` behavior.

## Next Steps (UI)

*   Resolve the trailing space issue in the horizontal scroll view.
*   Implement pane profiles (saving/loading sets of panes).
*   Implement provider restrictions (allowing multiple instances only for specific providers like You.com, Perplexity, AI Studio).
*   Further UI polish (styling, button appearances, etc.).
