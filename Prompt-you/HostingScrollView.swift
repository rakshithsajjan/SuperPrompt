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
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false // Use SwiftUI background if needed
        scrollView.contentView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // Create the hosting view for the SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false // Use Auto Layout

        // Set the hosting view as the document view
        scrollView.documentView = hostingView

        // Ensure the document view (hosting view) dictates the scrollable size.
        // The hosting view should respect the intrinsic size of its SwiftUI content (our HStack).
        guard let documentView = scrollView.documentView else { return scrollView }
        NSLayoutConstraint.activate([
            // Pin document view edges to the content view (the clip view)
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            // DO NOT constrain the trailing edge - let it be determined by content width

            // Make the document view height match the clip view height
            documentView.heightAnchor.constraint(equalTo: scrollView.contentView.heightAnchor)
            // Width will be determined by the SwiftUI content's ideal width
        ])

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
           let documentView = nsView.documentView
        {
            // Calculate the horizontal position of the focused pane
            // Assuming no spacing/dividers for now, adjust if needed
            let targetX = paneWidth * CGFloat(currentFocusIndex)
            let targetRect = CGRect(x: targetX, y: 0, width: paneWidth, height: documentView.bounds.height)

            // Animate the scroll
            // Using NSAnimationContext for smoother scrolling
            NSAnimationContext.runAnimationGroup({
                context in
                context.duration = 0.3 // Adjust duration as needed
                context.allowsImplicitAnimation = true
                nsView.contentView.scroll(to: CGPoint(x: targetX, y: 0))
                nsView.reflectScrolledClipView(nsView.contentView) // Ensure scrollers update
            }, completionHandler: nil)

            print("HostingScrollView: Scrolled to index \(currentFocusIndex), rect: \(targetRect)")
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