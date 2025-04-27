import WebKit

/// A WKWebView that never scrolls horizontally itself – the outer SwiftUI
/// `ScrollView(.horizontal)` does all the horizontal work.
final class PaneWebView: WKWebView {

    // MARK: initialiser ------------------------------------------------------

    override init(frame: CGRect = .zero, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)

        // REMOVED AGAIN: Accessing internal scrollView properties directly is not allowed on macOS
        // scrollView.hasHorizontalScroller      = false
        // scrollView.horizontalScrollElasticity = .none
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented for PaneWebView") }

    // MARK: event filtering --------------------------------------------------

    override func scrollWheel(with event: NSEvent) {

        /* Track-pad packets are a mix of X and Y deltas.  Decide what the user
           really wanted:  absolut(X) > absolut(Y)  ⇒ it is a horizontal gesture. */
        let wantsHorizontal = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)

        if wantsHorizontal {
            // Hand the packet to the next responder (SwiftUI's NSScrollView)
            nextResponder?.scrollWheel(with: event)
            return          // ← do not let WKWebView process this event further
        }

        // Pure vertical/zoom packets stay inside the page
        super.scrollWheel(with: event)
    }
} 