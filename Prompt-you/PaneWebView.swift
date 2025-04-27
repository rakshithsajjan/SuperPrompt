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
        // SIMPLIFIED LOGIC: Unconditionally forward all scroll events up the chain.
        // The NSScrollView in HostingScrollView is configured horizontal-only
        // and should handle filtering appropriately.
        print("PaneWebView Forwarding: Type=\(event.type), Phase=\(event.phase), Momentum=\(event.momentumPhase), dX=\(event.scrollingDeltaX), dY=\(event.scrollingDeltaY)")
        nextResponder?.scrollWheel(with: event)

        // We **never** call super.scrollWheel(with: event) here, because we want the
        // HostingScrollView's NSScrollView to handle *all* scrolling related to the panes.
        // Letting WKWebView handle vertical scrolls was likely interfering.
    }
} 