import WebKit

// MARK: - Focus delegate ------------------------------------------------------

protocol PaneFocusDelegate: AnyObject {
    func paneRequestedFocus(_ sender: PaneWebView)
}

/// A WKWebView that never scrolls horizontally itself – the outer SwiftUI
/// `ScrollView(.horizontal)` does all the horizontal work.
final class PaneWebView: WKWebView {

    weak var focusDelegate: PaneFocusDelegate?   // <─ NEW

    // MARK: initialiser ------------------------------------------------------

    override init(frame: CGRect = .zero, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)

        // REMOVED AGAIN: Accessing internal scrollView properties directly is not allowed on macOS
        // scrollView.hasHorizontalScroller      = false
        // scrollView.horizontalScrollElasticity = .none
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented for PaneWebView") }

    // MARK: focus signalling -------------------------------------------------

    override func becomeFirstResponder() -> Bool {
        // Let the superclass attempt to become first responder first.
        let ok = super.becomeFirstResponder()
        // If successful, notify the delegate.
        if ok {
            print("PaneWebView: becomeFirstResponder succeeded, notifying delegate.")
            focusDelegate?.paneRequestedFocus(self)
        } else {
            print("PaneWebView: becomeFirstResponder failed.")
        }
        return ok
    }

    // User clicks again while we are already first responder:
    override func mouseDown(with event: NSEvent) {
        // Let WebKit handle the mouse down event first (for text selection, etc.)
        super.mouseDown(with: event)
        // Then, notify the delegate that interaction occurred, potentially requesting focus update.
        print("PaneWebView: mouseDown occurred, notifying delegate.")
        focusDelegate?.paneRequestedFocus(self)
    }

    // MARK: event filtering --------------------------------------------------

    override func scrollWheel(with event: NSEvent) {
        // Revised logic: Prioritize forwarding unless clearly vertical AND no momentum.
        let isClearlyVertical = abs(event.scrollingDeltaX) < abs(event.scrollingDeltaY) * 0.5 // Stricter vertical check
        let hasMomentum = event.momentumPhase != []

        // If it's NOT clearly vertical OR it has momentum, forward it for horizontal handling.
        if !isClearlyVertical || hasMomentum {
            // Print statement for debugging (can be removed later)
            print("PaneWebView Forwarding Horizontal/Momentum: Phase=\(event.phase), Momentum=\(event.momentumPhase), dX=\(event.scrollingDeltaX), dY=\(event.scrollingDeltaY)")
            nextResponder?.scrollWheel(with: event)
            // Do NOT call super in this case, let the outer scroll view handle it fully.
        } else {
            // Only call super if it's clearly vertical AND has no momentum.
            // Print statement for debugging (can be removed later)
            print("PaneWebView Handling Vertical: Phase=\(event.phase), Momentum=\(event.momentumPhase), dX=\(event.scrollingDeltaX), dY=\(event.scrollingDeltaY)")
            super.scrollWheel(with: event)
        }
    }
} 