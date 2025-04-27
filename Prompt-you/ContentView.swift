import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var model = MainModel()

    var body: some View {
        // Overall container
        VStack(spacing: 0) {

            /*───── Browser grid (now occupies most space) ─────*/
            GeometryReader { geo in
                let visiblePanes = model.panes.filter { $0.isSelected }
                let count = CGFloat(visiblePanes.count)
                let width = count > 0 ? geo.size.width / count : geo.size.width

                HStack(spacing: 0) {
                    ForEach(model.panes) { pane in
                        if pane.isSelected {
                             WebViewWrapper(pane.webView)
                                .frame(width: width)
                        }
                    }
                }
            }
            // Allow GeometryReader to expand
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider() // Divider above the bottom controls

            /*───── Bottom Control Bar ─────*/
            VStack(spacing: 8) {
                // Checkboxes (Top row within the bottom bar)
                HStack {
                    ForEach($model.panes) { $pane in
                        Toggle(pane.title, isOn: $pane.isSelected)
                            .toggleStyle(.checkbox)
                            .disabled(model.isBroadcasting)
                    }
                    Spacer() // Pushes checkboxes left
                }

                // Input + Send Button (Bottom row within the bottom bar)
                HStack(spacing: 8) {
                    TextField("Enter prompt here...", text: $model.promptText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(model.isBroadcasting)
                        .onSubmit {
                            if !model.isBroadcasting {
                                model.broadcast()
                            }
                        }

                    Button { model.broadcast() } label: {
                         // Use an SF Symbol for a sleeker look
                         Image(systemName: "paperplane.fill")
                             .imageScale(.medium)
                             .frame(height: 20) // Ensure consistent height
                    }
                    .buttonStyle(.borderedProminent) // Style the button
                    .tint(.accentColor) // Use accent color
                    .disabled(model.isBroadcasting || model.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(10) // Add padding around the bottom control area
            .background(.regularMaterial) // Give it a distinct background
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

/* SwiftUI wrapper that embeds the existing WKWebView instance. */
private struct WebViewWrapper: NSViewRepresentable {
    let wk: WKWebView
    init(_ w: WKWebView) { self.wk = w }

    func makeNSView(context: Context) -> WKWebView { wk }
    func updateNSView(_ nsView: WKWebView, context: Context) { }
}
