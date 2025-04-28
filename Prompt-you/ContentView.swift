import SwiftUI
import WebKit
import AppKit

// Define the delegate helper class within ContentView or globally if preferred
fileprivate class PaneFocusCoordinator: PaneFocusDelegate {
    let model: MainModel
    let paneId: UUID // Use ID to reliably find the index later

    init(model: MainModel, paneId: UUID) {
        self.model = model
        self.paneId = paneId
    }

    func paneRequestedFocus(_ sender: PaneWebView) {
        // Ensure this runs on the main actor since we're updating the model
        Task { @MainActor in
            if let index = model.panes.firstIndex(where: { $0.id == self.paneId }) {
                // Check if focus is already correct to avoid redundant updates
                if model.focusedPaneIndex != index {
                    print("PaneFocusCoordinator: Requesting focus for pane index \(index) (ID: \(paneId))")
                    model.setFocus(to: index)
                }
            } else {
                print("PaneFocusCoordinator: Could not find index for pane ID \(paneId)")
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var model = MainModel()
    @State private var showingProfileSheet = false
    @State private var showingAddPanePopover = false
    // Default width for panes
    private let paneWidth: CGFloat = 450
    // State for focus notification
    @State private var showFocusNotification = false
    @State private var focusNotificationText = ""
    // State to track pane count changes for add notification
    @State private var previousPaneCount = 0
    // Focus state for the main chat bar
    @FocusState private var isChatBarFocused: Bool
    // Store coordinators to keep them alive
    @State private var focusCoordinators: [UUID: PaneFocusCoordinator] = [:]

    /// Opens a new NSWindow displaying all available AI providers.
    private func openLLMListWindow() {
        // Declare window variable so it can be referenced in the closure
        var window: NSWindow? = nil
        let rootView = LLMListWindowView(onSelect: { provider in
            // Add a new pane for the selected provider
            model.addPane(provider: provider)
            // Close the window
            window?.close()
        })
        let hostingView = NSHostingView(rootView: rootView)
        // Instantiate the window and center it
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window?.center()
        window?.title = "Available LLMs"
        window?.contentView = hostingView
        window?.makeKeyAndOrderFront(nil)
    }

    var body: some View {
        // ZStack to allow overlaying the notification
        ZStack(alignment: .bottom) { 
            VStack(spacing: 0) {
                /*───── Horizontally Scrolling Browser Panes (using custom NSScrollView) ─────*/
                HostingScrollView(content:
                    HStack(spacing: 0) {
                        // Use enumerated version
                        ForEach(Array(model.panes.enumerated()), id: \.element.id) { idx, pane in
                            // --- Restore ZStack structure directly --- 
                            ZStack(alignment: .topTrailing) {

                                // 1️⃣ Main content — show EITHER WebView OR a clear fill
                                if pane.isProviderPicker {
                                    Color.clear                // keeps the pane's width
                                } else {
                                    WebViewWrapper(pane.webView)
                                        .id(pane.id) // ID is needed here
                                        .onAppear {
                                            // Keep delegate setup logic here
                                            if focusCoordinators[pane.id] == nil {
                                                let coordinator = PaneFocusCoordinator(model: model, paneId: pane.id)
                                                focusCoordinators[pane.id] = coordinator
                                                pane.webView.focusDelegate = coordinator
                                                print("ContentView (onAppear): Set focus delegate for pane \(idx) (ID: \(pane.id))")
                                            } else {
                                                // Ensure delegate is still set
                                                pane.webView.focusDelegate = focusCoordinators[pane.id]
                                            }
                                        }
                                        // .onDisappear { ... } // Optional cleanup
                                }

                                // 2️⃣ Close button (Always present)
                                Button {
                                    model.removePane(id: pane.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .resizable()
                                        .frame(width: 18, height: 18)
                                        .foregroundColor(.gray.opacity(0.7))
                                        .background(Circle().fill(.white.opacity(0.6)))
                                }
                                .buttonStyle(.plain)
                                .padding(5)

                                // 3️⃣ Picker overlay – shown only in picker mode
                                if pane.isProviderPicker {
                                    ProviderPickerOverlay { provider in
                                        model.replacePicker(at: idx, with: provider)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
                                    .transition(.opacity.combined(with: .scale))
                                }
                            }
                            .frame(width: paneWidth)
                            .overlay(
                                Rectangle()
                                    .stroke(idx == model.focusedPaneIndex ? Color.accentColor : .clear,
                                            lineWidth: 2)
                                    .allowsHitTesting(false) // Border doesn't interfere
                            )
                            .animation(.easeInOut(duration: 0.15), value: model.focusedPaneIndex) // Animate border change
                            
                            // --- Divider logic remains outside ZStack ---
                            if idx != model.panes.count - 1 { // Use index check
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
                    // Profiles Menu
                    Menu {
                        ForEach(model.profileStore.profiles) { profile in
                            Button(profile.name) {
                                model.profileStore.setActiveProfile(id: profile.id)
                                // Load panes for the newly selected profile
                                model.loadActiveProfile()
                            }
                        }
                        Divider()
                        Button("Manage Profiles") {
                            showingProfileSheet = true
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .imageScale(.medium)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(height: 20)
                    .fixedSize()
                    .disabled(model.isBroadcasting)
                    
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
                    .menuIndicator(.hidden)
                    .frame(height: 20)
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
                            .clipShape(Rectangle()) // Use Rectangle for sharp corners
                            .overlay(
                               Rectangle() // Use Rectangle for sharp corners
                                   .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                            )
                            .disabled(model.isBroadcasting)
                            // Bind focus state
                            .focused($isChatBarFocused)

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
                    // Add subtle glow effect when focused
                    .shadow(
                        color: Color.accentColor.opacity(isChatBarFocused ? 0.8 : 0),
                        radius: isChatBarFocused ? 10 : 0, x: 0, y: 0
                    )
                    .animation(.easeInOut(duration: 0.2), value: isChatBarFocused) // Animate the glow change

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
            // Use .task for reliable one-time async setup on appear
            .task {
                // Attempt to load saved state first
                model.loadPanesState()

                // If loading resulted in no panes (e.g., first launch or cleared state),
                // add the default panes.
                if model.panes.isEmpty {
                    print("Startup: No saved panes found or loaded, adding defaults.")
                    model.addPane(provider: .chatGPT) // This will trigger save
                    model.addPane(provider: .claude)  // This will trigger save
                    // Focus is handled automatically by addPane/loadPanesState
                } else {
                    print("Startup: Loaded \(model.panes.count) panes from saved state.")
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
        // Popover for Add Pane triggered by Cmd+Plus
        .popover(isPresented: $showingAddPanePopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Pane").font(.headline)
                Divider()
                ForEach(AIProvider.allCases) { provider in
                    Button(provider.rawValue) {
                        model.addPane(provider: provider)
                        showingAddPanePopover = false
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .frame(minWidth: 200)
        }
        // Force the VStack content to extend under the top safe area (window controls)
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 500, minHeight: 400) // Adjusted min size
        // Clear pane focus when chat bar becomes focused
        .onChange(of: isChatBarFocused) { isFocused in
            if isFocused {
                print("Chat bar focused, clearing pane focus.")
                model.focusedPaneIndex = nil
                // Save state since focus changed
                model.savePanesState()
            }
        }
        // --- Focus Management ---
        .onChange(of: model.focusedPaneIndex) { newIndex in
            guard let index = newIndex, index >= 0 && index < model.panes.count else { 
                // Use String(describing:) for safe interpolation of the optional Int
                print("Focus onChange: Invalid index (\(String(describing: newIndex))) or panes empty.")
                return 
            }
            
            // NEW: If it's the picker, do nothing – ProviderPickerOverlay will claim focus.
            if model.panes[index].isProviderPicker { 
                 print("Focus onChange: Pane \(index) is picker, skipping webview focus.")
                 return 
            }

            // --- If not picker, proceed with focusing the WebView ---
            let pane = model.panes[index]
            let paneTitle = pane.title // Get title regardless of type
            
            // 2️⃣ Normal Pane: Focus the WKWebView
            print("Focus onChange: Pane \(index) is normal. Attempting to focus its WebView.")
            let targetWebView = pane.webView
            // Ensure the webView is part of the window hierarchy before making it first responder
            DispatchQueue.main.async { // Still good practice to async this
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
            // Instantiate the extracted view
            ShortcutHandlerView(
                model: model,
                showingAddPanePopover: $showingAddPanePopover,
                showingProfileSheet: $showingProfileSheet,
                focusChatBar: { // Provide the closure for focusing the chat bar
                    // Logic previously in the Cmd+F button action
                    if model.focusedPaneIndex != nil {
                        print("Cmd+F via ShortcutHandler: Clearing pane focus.")
                        model.focusedPaneIndex = nil
                        model.savePanesState()
                    }
                    print("Cmd+F via ShortcutHandler: Setting chat bar focus state.")
                    isChatBarFocused = true
                }
            )
            // Opacity modifier is now inside ShortcutHandlerView
         )
        // Profile Management Sheet
        .sheet(isPresented: $showingProfileSheet) {
            ProfileManagementView(profileStore: model.profileStore)
        }
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

// MARK: - NSView Extension Helper -

// extension NSView { ... }

// MARK: - Previews -

#if DEBUG
// ... existing preview code ...
#endif
