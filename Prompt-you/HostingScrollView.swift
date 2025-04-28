import SwiftUI
import AppKit

/// A custom NSViewRepresentable that wraps an NSScrollView to host SwiftUI content,
/// specifically designed for horizontal scrolling without nesting conflicts.
struct HostingScrollView<Content: View>: NSViewRepresentable {
    // The SwiftUI content to host within the scroll view
    var content: Content
    // Pass needed state for auto-scrolling
    @Binding var focusedPaneIndex: Int? // Use Binding to react to external changes
    var paneCount: Int
    var paneWidth: CGFloat

    // Coordinator to track previous state
    func makeCoordinator() -> Coordinator {
        Coordinator(focusedPaneIndex: focusedPaneIndex)
    }

    class Coordinator {
        var previousFocusedPaneIndex: Int?

        init(focusedPaneIndex: Int?) {
            self.previousFocusedPaneIndex = focusedPaneIndex
        }
    }

    // MARK: - NSViewRepresentable Lifecycle

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false // We only want horizontal scrolling
        scrollView.hasHorizontalScroller = false // Hide the horizontal scroller
        scrollView.horizontalScrollElasticity = .none // Remove rubber-band effect
        scrollView.automaticallyAdjustsContentInsets = false // Prevent system adjustments
        scrollView.contentInsets = NSEdgeInsets() // Explicitly set zero insets
        // scrollView.autohidesScrollers = true // Not needed if scroller is always hidden
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false // Use SwiftUI background if needed

        // Create the hosting view for the SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false // Use Auto Layout

        // Set the hosting view as the document view
        scrollView.documentView = hostingView

        // Ensure the document view (hosting view) dictates the scrollable size.
        // The hosting view should respect the intrinsic size of its SwiftUI content (our HStack).
        guard let documentView = scrollView.documentView else { return scrollView }
        let clipView = scrollView.contentView // Get the clip view (NSClipView)

        NSLayoutConstraint.activate([
            // Pin document view edges to the content view (the clip view)
            documentView.topAnchor.constraint(equalTo: clipView.topAnchor),
            documentView.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),
            documentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            documentView.heightAnchor.constraint(equalTo: clipView.heightAnchor)
        ])

        // NEW STRATEGY (Corrected for AppKit):
        // Constrain the document view width to the scroll view's contentView (clipView) width with LOW priority.
        // This ensures it fills the visible bounds when content is narrow, but allows intrinsic content size
        // to expand the width (breaking this constraint) when content is wide, enabling scrolling.
        let clipViewWidthConstraint = documentView.widthAnchor.constraint(equalTo: clipView.widthAnchor)
        clipViewWidthConstraint.priority = .defaultLow // Low priority (250)
        clipViewWidthConstraint.isActive = true

        // Now we have:
        // - leading/top/bottom/height anchors tying the documentView partially to the clipView.
        // - A low-priority width constraint tying documentView width to the clipView width.
        // - Intrinsic content size of the NSHostingView (from the HStack) takes precedence if wider.

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Update the SwiftUI content within the hosting view
        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
        } else {
            // Fallback/Error case: If documentView isn't the expected type, recreate (less efficient)
            print("HostingScrollView Warning: Document view type mismatch. Recreating hosting view.")
            let hostingView = NSHostingView(rootView: content)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            nsView.documentView = hostingView
            // Re-activate constraints (might need more robust handling)
            guard let documentView = nsView.documentView else { return }
             NSLayoutConstraint.activate([
                documentView.topAnchor.constraint(equalTo: nsView.contentView.topAnchor),
                documentView.bottomAnchor.constraint(equalTo: nsView.contentView.bottomAnchor),
                documentView.leadingAnchor.constraint(equalTo: nsView.contentView.leadingAnchor),
                documentView.heightAnchor.constraint(equalTo: nsView.contentView.heightAnchor)
            ])
        }
        // Make sure the hosting view recalculates its size if the content changed significantly
        nsView.documentView?.needsLayout = true

        // --- Auto-Scroll Logic ---
        // Check if focus changed and is valid
        if let currentFocusIndex = focusedPaneIndex,
           currentFocusIndex != context.coordinator.previousFocusedPaneIndex,
           currentFocusIndex >= 0,
           currentFocusIndex < paneCount,
           let documentView = nsView.documentView,
           let clipView = nsView.contentView as? NSClipView // Get the clip view
        {
            let dividerWidth: CGFloat = 1.0 // Assumed divider width
            let visibleRect = clipView.documentVisibleRect // Use the visible rect of the document
            let totalContentWidth = (paneWidth * CGFloat(paneCount)) + (dividerWidth * CGFloat(max(0, paneCount - 1)))
            let maxXScrollOffset = max(0, totalContentWidth - visibleRect.width)

            // Calculate the frame of the target pane within the documentView
            let targetPaneMinX = (paneWidth * CGFloat(currentFocusIndex)) + (dividerWidth * CGFloat(currentFocusIndex))
            let targetPaneRect = CGRect(x: targetPaneMinX, y: 0, width: paneWidth, height: documentView.bounds.height)

            // --- Calculate required scroll --- 
            var targetScrollPointX = visibleRect.origin.x // Default to current scroll position

            if visibleRect.contains(targetPaneRect) {
                // Pane is already fully visible, no scroll needed
                 print("HostingScrollView: Pane \(currentFocusIndex) already visible. No scroll.")
            } else {
                // Pane is not fully visible, calculate scroll adjustment
                if targetPaneRect.minX < visibleRect.minX {
                    // Scroll right to bring leading edge into view
                    targetScrollPointX = targetPaneRect.minX
                } else if targetPaneRect.maxX > visibleRect.maxX {
                    // Scroll left to bring trailing edge into view
                    targetScrollPointX = targetPaneRect.maxX - visibleRect.width
                }
                // If neither edge is out, but it wasn't contained, it might be taller than visibleRect?
                // In our horizontal-only case, this shouldn't happen unless paneWidth > visibleWidth.
                // If paneWidth > visibleWidth, we default to scrolling leading edge into view:
                else if paneWidth > visibleRect.width {
                     targetScrollPointX = targetPaneRect.minX
                }

                // Clamp the calculated scroll point
                targetScrollPointX = max(0, min(targetScrollPointX, maxXScrollOffset))

                 // Only animate if the target is different from current origin
                if abs(targetScrollPointX - visibleRect.origin.x) > 0.1 { // Tolerance
                    print("HostingScrollView: Scrolling to make pane \(currentFocusIndex) visible. TargetX=\(targetScrollPointX)")
                    NSAnimationContext.runAnimationGroup({
                        context in
                        context.duration = 0.3 // Adjust duration as needed
                        context.allowsImplicitAnimation = true
                        clipView.scroll(to: CGPoint(x: targetScrollPointX, y: 0))
                        nsView.reflectScrolledClipView(clipView) // Ensure scrollers update
                    }, completionHandler: nil)
                } else {
                     print("HostingScrollView: Pane \(currentFocusIndex) requires no scroll adjustment (TargetX=\(targetScrollPointX) ≈ CurrentOriginX=\(visibleRect.origin.x)).")
                }
            }
        }

        // Update coordinator with the latest index
        context.coordinator.previousFocusedPaneIndex = focusedPaneIndex
    }
}

// Optional Preview for HostingScrollView itself
#if DEBUG
struct HostingScrollView_Previews: PreviewProvider {
    @State static var previewFocusIndex: Int? = 0
    static let previewPaneWidth: CGFloat = 200
    static let previewPaneCount = 5

    static var previews: some View {
        // Explicitly initialize HostingScrollView with the HStack as content
        HostingScrollView(content:
            HStack {
                ForEach(0..<previewPaneCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: previewPaneWidth, height: 150)
                        .overlay(Text("Item \(i)"))
                        .id(i) // Add ID for stability
                }
            }
            .padding(),
            focusedPaneIndex: $previewFocusIndex, // Pass binding
            paneCount: previewPaneCount,
            paneWidth: previewPaneWidth
        )
        .frame(height: 200)
        .overlay( // Add buttons to test focus change in preview
            HStack {
                Button("Focus Prev") { if let idx = previewFocusIndex, idx > 0 { previewFocusIndex = idx - 1 } }
                Button("Focus Next") { if let idx = previewFocusIndex, idx < previewPaneCount - 1 { previewFocusIndex = idx + 1 } }
            }.padding(), alignment: .bottom
        )
    }
}
#endif 