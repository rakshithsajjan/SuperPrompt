import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var model = MainModel()
    // Default width for panes
    private let paneWidth: CGFloat = 450
    // State for focus notification
    @State private var showFocusNotification = false
    @State private var focusNotificationText = ""
    // State to track pane count changes for add notification
    @State private var previousPaneCount = 0

    var body: some View {
        // ZStack to allow overlaying the notification
        ZStack(alignment: .bottom) { 
            VStack(spacing: 0) {
                /*───── Horizontally Scrolling Browser Panes (using custom NSScrollView) ─────*/
                HostingScrollView(content:
                    HStack(spacing: 0) {
                        // Iterate over the DYNAMIC panes array
                        ForEach(model.panes) { pane in
                            // --- Pane View with Close Button ---
                            ZStack(alignment: .topTrailing) {
                                WebViewWrapper(pane.webView)
                                    .frame(width: paneWidth) // Uses the constant paneWidth
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
                            // Only add Divider if it's not the last pane
                            if pane.id != model.panes.last?.id {
                                 Divider() // Vertical divider between panes
                            }
                        }
                    },
                    // Pass necessary state for auto-scrolling
                    focusedPaneIndex: $model.focusedPaneIndex,
                    paneCount: model.panes.count,
                    paneWidth: paneWidth
                )

                Divider() // Divider above the bottom controls

                /*───── Sleeker Bottom Control Bar ─────*/
                HStack(alignment: .center, spacing: 8) { // Align items to center vertically
                    // Add Pane Menu Button (Left Aligned)
                    Menu {
                        ForEach(AIProvider.allCases) { provider in
                            Button("Add \(provider.rawValue)") {
                                model.addPane(provider: provider)
                            }
                        }
                    } label: {
                        // Simpler icon label
                        Image(systemName: "plus")
                            .imageScale(.medium)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(height: 20) // Match textfield/button height
                    .fixedSize()
                    .disabled(model.isBroadcasting)

                    Spacer() // Pushes the central group

                    // Use TextEditor for multi-line input with ZStack for placeholder
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $model.promptText)
                            // Frame allows vertical expansion
                            .frame(minHeight: 30, maxHeight: 140) // Approx 1 to 7 lines
                            .fixedSize(horizontal: false, vertical: true) // Allows vertical growth
                            .font(.body.leading(.loose)) // Increased font size
                            // Styling to mimic TextField
                            .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
                            .background( TransparentRepresentable() ) // Use a transparent background helper for TextEditor
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                               RoundedRectangle(cornerRadius: 6)
                                   .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                            )
                            .disabled(model.isBroadcasting)

                        // Placeholder Text
                        if model.promptText.isEmpty {
                            Text("Enter prompt here...")
                                .font(.body.leading(.loose)) // Match increased font size
                                .foregroundColor(Color(NSColor.placeholderTextColor))
                                .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)) // Match TextEditor padding roughly
                                .allowsHitTesting(false) // Prevent placeholder from blocking interaction
                        }
                    }
                    .frame(maxWidth: 600) // Limit width of the input area
                    .disabled(model.isBroadcasting)

                    // Visible Send Button
                    Button {
                        // Send Action
                        model.broadcast()
                    } label: {
                        Image(systemName: model.isBroadcasting ? "hourglass" : "paperplane.fill")
                            .imageScale(.medium)
                            .frame(height: 20)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(model.isBroadcasting || model.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    // Hidden Button for Cmd+Enter Shortcut
                    Button("") { // No label
                        model.broadcast()
                    }
                    .keyboardShortcut(.return, modifiers: .command) // Cmd + Enter
                    .hidden() // Make it invisible
                    .disabled(model.isBroadcasting || model.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) // Same disabled state

                    Spacer() // Pushes the central group
                }
                .padding(10)
                .background(.regularMaterial) // Keep distinct background
            }
            // Add some default panes on launch for better initial state
            .onAppear {
                if model.panes.isEmpty {
                    model.addPane(provider: .chatGPT)
                    model.addPane(provider: .claude)
                    // Automatically focus the first pane on launch if needed
                    if model.focusedPaneIndex == nil {
                         model.setFocus(to: 0)
                    }
                }
            }
            
            // --- Focus Notification View ---
            if showFocusNotification {
                Text(focusNotificationText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThickMaterial, in: Capsule())
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.bottom, 50) // Position above the bottom bar
                    .allowsHitTesting(false)
            }
        }
        // Force the VStack content to extend under the top safe area (window controls)
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 500, minHeight: 400) // Adjusted min size
        // --- Focus Management ---
        .onChange(of: model.focusedPaneIndex) { newIndex in
            guard let index = newIndex, index >= 0 && index < model.panes.count else { return }
            let targetWebView = model.panes[index].webView
            let paneTitle = model.panes[index].title
            // Ensure the webView is part of the window hierarchy before making it first responder
            DispatchQueue.main.async {
                 if let window = targetWebView.window {
                     print("Attempting to focus pane index: \(index), view: \(targetWebView)")
                     let success = window.makeFirstResponder(targetWebView)
                     if success {
                         // Show notification on successful focus change
                         focusNotificationText = "Focused: \(paneTitle)"
                         withAnimation {
                             showFocusNotification = true
                         }
                         // Hide notification after delay
                         DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                             withAnimation {
                                 showFocusNotification = false
                             }
                         }
                     } else {
                         print("Focus failed for index \(index)")
                     }
                 } else {
                     print("Skipping focus: WebView for index \(index) has no window.")
                 }
            }
        }
        // --- Pane Added Notification Observer ---
        .onChange(of: model.panes.count) { newCount in
            if newCount > previousPaneCount {
                // Pane was added
                let addedPaneIndex = newCount - 1
                if addedPaneIndex >= 0 && addedPaneIndex < model.panes.count {
                    let paneTitle = model.panes[addedPaneIndex].title
                    let paneNumber = addedPaneIndex + 1
                    // Only show number if it's within Cmd+1 to Cmd+9 range
                    let shortcutText = paneNumber <= 9 ? " (Cmd+\(paneNumber))" : ""
                    
                    focusNotificationText = "Added: \(paneTitle)\(shortcutText)"
                    withAnimation {
                        showFocusNotification = true
                    }
                    // Hide notification after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showFocusNotification = false
                        }
                    }
                }
            }
            // Update previous count for next change detection
            previousPaneCount = newCount
        }
        // Add hidden buttons for keyboard shortcuts
        .background(
            // Use a Group for Command+Number shortcuts (1-9)
            Group {
                ForEach(1..<10) { number in // Create shortcuts for Cmd+1 to Cmd+9
                    Button("") { model.setFocus(to: number - 1) } // Action sets focus
                        .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
                        .disabled(number > model.panes.count) // Disable if pane doesn't exist
                }
                
                // Add buttons for cycling focus
                Button("") { model.cycleFocus(forward: false) } // Previous Pane
                    .keyboardShortcut("[", modifiers: [.command, .shift])
                    .disabled(model.panes.count <= 1) // Disable if only 0 or 1 pane
                
                Button("") { model.cycleFocus(forward: true) } // Next Pane
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                    .disabled(model.panes.count <= 1) // Disable if only 0 or 1 pane
            }
            .hidden()
         )
    }
}

/// Helper to make TextEditor background transparent on older macOS versions
private struct TransparentRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Defer setting wantsLayer until the view is part of a window hierarchy
        DispatchQueue.main.async { 
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.clear.cgColor
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
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
