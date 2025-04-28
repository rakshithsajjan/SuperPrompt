import SwiftUI
import AppKit // Needed for NSViewRepresentable and potentially PaneWebView

/// SwiftUI wrapper that embeds an existing PaneWebView *and* reports clicks.
struct WebViewWrapper: NSViewRepresentable {
    let wk: PaneWebView // Holds the instance created elsewhere
    init(_ w: PaneWebView) { self.wk = w }

    func makeNSView(context: Context) -> PaneWebView {
        // Just return the existing instance passed during init
        return wk
    }

    func updateNSView(_ nsView: PaneWebView, context: Context) { 
        // No updates needed based on SwiftUI state changes in this simple wrapper
    }
} 