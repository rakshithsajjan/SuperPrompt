import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var model = MainModel()
    // Default width for panes
    private let paneWidth: CGFloat = 450

    var body: some View {
        VStack(spacing: 0) {
            // --- Top Bar for Adding Panes ---
            HStack {
                Spacer() // Push menu to the right
                Menu {
                    // Iterate over all known AIProvider types
                    ForEach(AIProvider.allCases) { provider in
                        Button("Add \(provider.rawValue)") {
                            model.addPane(provider: provider)
                        }
                    }
                } label: {
                    Label("Add Pane", systemImage: "plus.circle.fill")
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
            }
            .background(.bar) // Use a standard bar background

            Divider()

            /*───── Horizontally Scrolling Browser Panes ─────*/
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 0) {
                    // Iterate over the DYNAMIC panes array
                    ForEach(model.panes) { pane in
                        // --- Pane View with Close Button ---
                        ZStack(alignment: .topTrailing) {
                            WebViewWrapper(pane.webView)
                                .frame(width: paneWidth)
                                .id(pane.id) // Ensure view updates on pane removal

                            // Close Button Overlay
                            Button {
                                model.removePane(id: pane.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.gray.opacity(0.7))
                                    .background(Circle().fill(.white.opacity(0.6)))
                            }
                            .buttonStyle(.plain) // Removes default button chrome
                            .padding(5)
                        }
                        Divider() // Vertical divider between panes
                    }
                }
                // Ensure HStack takes its full required width
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider() // Divider above the bottom controls

            /*───── Sleeker Bottom Control Bar ─────*/
            HStack(spacing: 8) {
                TextField("Enter prompt here...", text: $model.promptText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.isBroadcasting)
                    .onSubmit { // Keep onSubmit for convenience
                        if !model.isBroadcasting && !model.promptText.isEmpty {
                            model.broadcast()
                        }
                    }

                Button {
                    model.broadcast()
                } label: {
                    // Use an SF Symbol for a sleeker look
                    Image(systemName: model.isBroadcasting ? "hourglass" : "paperplane.fill") // Show hourglass when busy
                        .imageScale(.medium)
                        .frame(height: 20)
                        .contentTransition(.symbolEffect(.replace)) // Animate icon change
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(model.isBroadcasting || model.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(.regularMaterial) // Keep distinct background
        }
        .frame(minWidth: 500, minHeight: 400) // Adjusted min size
        // Add some default panes on launch for better initial state
        .onAppear {
            if model.panes.isEmpty {
                model.addPane(provider: .chatGPT)
                model.addPane(provider: .claude)
            }
        }
    }
}

/* SwiftUI wrapper that embeds the existing WKWebView instance. */
private struct WebViewWrapper: NSViewRepresentable {
    // Accept the subclass type
    let wk: PaneWebView
    init(_ w: PaneWebView) { self.wk = w }

    func makeNSView(context: Context) -> PaneWebView {
        // Pass the existing instance
        return wk
    }

    func updateNSView(_ nsView: PaneWebView, context: Context) {
        // No need for the previous erroneous code here
        // The scroll handling is now done within the NoHorizontalScrollWebView subclass
    }
}
