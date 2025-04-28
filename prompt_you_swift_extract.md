# Swift Codebase Extraction

Repository path: /Users/raka/Desktop/WORK/PROJECTS/Prompt-you/Prompt-you/Prompt-you
Extraction date: 2025-04-28 19:07:25



================================================================================
FILE: HostingScrollView.swift
================================================================================

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

================================================================================
FILE: ShortcutHandlerView.swift
================================================================================

import SwiftUI

/// A view that contains hidden buttons to handle global keyboard shortcuts.
struct ShortcutHandlerView: View {
    // Dependencies needed for the shortcut actions
    @ObservedObject var model: MainModel
    @Binding var showingAddPanePopover: Bool
    @Binding var showingProfileSheet: Bool
    var focusChatBar: () -> Void // Closure to set focus state

    var body: some View {
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

            // Cmd+T for New Tab Picker (Already implemented)
            Button("") { model.openNewTabPicker() }
                 .keyboardShortcut("t", modifiers: .command)
                 // Consider disabling if broadcasting? Add .disabled(model.isBroadcasting)
            
            // Hidden Cmd+Plus to open Add Pane popover
            Button("") {
                showingAddPanePopover = true
            }
            .keyboardShortcut(KeyEquivalent("+"), modifiers: .command)
            .disabled(model.isBroadcasting)

            // Hidden Cmd+P to open Manage Profiles sheet
            Button("") {
                showingProfileSheet = true
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(model.isBroadcasting)

            // Hidden Cmd+F to focus the chat bar
            Button("") {
                focusChatBar() // Call the provided closure
            }
            .keyboardShortcut("f", modifiers: .command)
        }
        // Keep the opacity modifier here to ensure the whole group is hidden
        .opacity(0)
    }
} 

================================================================================
FILE: ProfileStore.swift
================================================================================

import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [Profile] = []
    @Published var activeProfileID: UUID?

    private let profilesKey = "savedProfiles_v1"
    private let activeProfileKey = "activeProfileID_v1"

    init() {
        loadProfiles()
        // Seed a default profile if none exist
        if profiles.isEmpty {
            let defaultProviders: [AIProvider] = [.chatGPT, .claude]
            let defaultProfile = Profile(name: "Default", providers: defaultProviders)
            profiles = [defaultProfile]
            activeProfileID = defaultProfile.id
            saveProfiles()
            print("ProfileStore: Created default profile with providers: \(defaultProviders.map { $0.rawValue })")
        }
    }

    /// Loads profiles and active profile ID from UserDefaults (JSON-encoded).
    func loadProfiles() {
        // Attempt to load profiles array
        if let data = UserDefaults.standard.data(forKey: profilesKey) {
            do {
                let decoded = try JSONDecoder().decode([Profile].self, from: data)
                self.profiles = decoded
            } catch {
                print("ProfileStore: Failed to decode profiles: \(error)")
                self.profiles = []
            }
        } else {
            // No saved data: initialize with empty array or a default profile
            self.profiles = []
        }

        // Load activeProfileID (stored as a UUID string)
        if let idString = UserDefaults.standard.string(forKey: activeProfileKey),
           let uuid = UUID(uuidString: idString) {
            self.activeProfileID = uuid
        } else {
            // Default to first profile if available
            self.activeProfileID = profiles.first?.id
        }
    }

    /// Saves profiles and active profile ID to UserDefaults.
    func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            UserDefaults.standard.set(data, forKey: profilesKey)
        } catch {
            print("ProfileStore: Failed to encode/save profiles: \(error)")
        }
        // Save active profile ID as string
        if let activeID = activeProfileID {
            UserDefaults.standard.set(activeID.uuidString, forKey: activeProfileKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeProfileKey)
        }
    }

    /// Returns the currently active Profile object, if any.
    var activeProfile: Profile? {
        guard let id = activeProfileID else { return nil }
        return profiles.first(where: { $0.id == id })
    }

    /// Adds a new profile with the given name and providers.
    func addProfile(name: String, providers: [AIProvider]) {
        let profile = Profile(name: name, providers: providers)
        profiles.append(profile)
        // If this is the first profile, make it active by default
        if activeProfileID == nil {
            activeProfileID = profile.id
        }
        saveProfiles()
    }

    /// Deletes the profile with the specified ID.
    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        // If the deleted profile was active, reset active to first available
        if activeProfileID == id {
            activeProfileID = profiles.first?.id
        }
        saveProfiles()
    }

    /// Renames the profile with the specified ID.
    func renameProfile(id: UUID, newName: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = newName
        saveProfiles()
    }

    /// In updates the set of providers for a given profile.
    func updateProviders(for id: UUID, providers: [AIProvider]) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].providers = providers
        saveProfiles()
    }

    /// Sets the active profile by ID.
    func setActiveProfile(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        saveProfiles()
    }
} 

================================================================================
FILE: PromptSenderApp.swift
================================================================================

import SwiftUI

@main
struct PromptSenderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar) // Hides the title bar, content goes to the top
        /* Enable the Web Inspector at runtime with ⌥⌘I */
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Toggle Web Inspector") {
                    UserDefaults.standard.set(true, forKey: "WebKitDeveloperExtras")
                    print("WebKitDeveloperExtras enabled. Relaunch might be needed. Use Option+Cmd+I on a WKWebView.")
                }
                .keyboardShortcut("i", modifiers: [.command, .option]) // Cmd+Option+I
            }
        }
    }
}


================================================================================
FILE: Profile.swift
================================================================================

import Foundation

/// A user-defined profile containing a name and a selection of AI providers.
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var providers: [AIProvider]

    init(id: UUID = UUID(), name: String, providers: [AIProvider]) {
        self.id = id
        self.name = name
        self.providers = providers
    }
} 

================================================================================
FILE: GlowingBorder.swift
================================================================================

import SwiftUI

struct GlowingBorder: ViewModifier {
    let active: Bool            // pass  model.focusedPaneIndex == index
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            // keep a 2-pt accent stroke
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(active ? Color.accentColor : .clear,
                            lineWidth: 2)
            )
            // duplicated shape, but blurred & varying opacity -> glow
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)            // solid colour
                    .opacity(active ? (pulse ? 0.8 : 0.3) : 0) // animate α
                    .blur(radius: 6)                     // the "light bleed"
                    .compositingGroup()                  // lets blur escape
            )
            .onAppear {         // start / stop the pulse
                if active { pulse = true }
            }
            .onChange(of: active) { // Use the newer onChange syntax
                if active {
                    pulse = true // Start pulsing when becoming active
                } else {
                    // If performance is critical, you might reset 'pulse' state here,
                    // but the opacity check handles the visual state.
                    // Resetting might avoid unnecessary @State updates if many panes exist.
                }
            }
            // drive the opacity toggle forever
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                       value: pulse)
            .allowsHitTesting(false)                      // overlay invisible
    }
} 

================================================================================
FILE: WebViewWrapper.swift
================================================================================

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

================================================================================
FILE: ProviderPickerOverlay.swift
================================================================================

import SwiftUI

/// Arrow-key navigable picker that lives *inside* the new-tab pane.
struct ProviderPickerOverlay: View {

    @State private var selection: AIProvider? = AIProvider.allCases.first
    @FocusState private var listFocused: Bool       
    var onSelect: (AIProvider) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Choose a provider")
                .font(.headline)
                .padding([.top, .leading, .trailing]) // Adjust padding
            
            List(selection: $selection) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Text(provider.rawValue)
                        .tag(provider as AIProvider?) // Tag must match optional selection type
                }
            }
            .listStyle(.inset)               
            .environment(\.defaultMinListRowHeight, 28) 
            .frame(width: 230, height: 280)  
            .focused($listFocused)           // Apply FocusState here

            // invisible button: Return / Enter triggers it automatically
            Button("") {
                if let sel = selection {
                    print("ProviderPickerOverlay: Default action triggered, selecting \(sel.rawValue)")
                    onSelect(sel)
                }
            }
            .keyboardShortcut(.defaultAction)   // ↩︎ and ⌘↩︎
            .opacity(0) // Keep it invisible
            .frame(width: 0, height: 0) // Ensure it takes no space
        }
        .background(.regularMaterial)           // same frosted panel
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Slightly larger radius
        .padding(20) // Keep overall padding
        // 🆕 Set focus state when the view appears
        .onAppear { listFocused = true }          
    }
}

#if DEBUG
struct ProviderPickerOverlay_Previews: PreviewProvider {
    static var previews: some View {
        // Wrap in a frame to simulate being inside a pane
        ProviderPickerOverlay(onSelect: { provider in
            print("Selected: \(provider.rawValue)")
        })
        .frame(width: 400, height: 500) // Simulate the pane size
    }
}
#endif 

================================================================================
FILE: PaneWebView.swift
================================================================================

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

================================================================================
FILE: ProfileManagementView.swift
================================================================================

import SwiftUI

struct ProfileManagementView: View {
    @ObservedObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var isPresentingNewProfile = false
    @State private var newProfileName = ""

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { isPresentingNewProfile = true }) {
                        Label("New Profile", systemImage: "plus")
                    }
                }
                ForEach(profileStore.profiles) { profile in
                    NavigationLink(destination: ProfileEditorView(profile: profile, profileStore: profileStore)) {
                        Text(profile.name)
                    }
                }
                .onDelete { indices in
                    for idx in indices {
                        let id = profileStore.profiles[idx].id
                        profileStore.deleteProfile(id: id)
                    }
                }
            }
            .navigationTitle("Profiles")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewProfile) {
                NavigationView {
                    VStack {
                        TextField("Profile Name", text: $newProfileName)
                            .textFieldStyle(.roundedBorder)
                            .padding()
                        Spacer()
                    }
                    .navigationTitle("New Profile")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                profileStore.addProfile(name: newProfileName, providers: [])
                                newProfileName = ""
                                isPresentingNewProfile = false
                            }
                            .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isPresentingNewProfile = false
                                newProfileName = ""
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 500)
    }
}

// Editor view for a single profile
struct ProfileEditorView: View {
    let profile: Profile
    @ObservedObject var profileStore: ProfileStore
    @State private var name: String
    @State private var selectedProviders: Set<AIProvider>
    @Environment(\.dismiss) private var dismiss

    init(profile: Profile, profileStore: ProfileStore) {
        self.profile = profile
        self.profileStore = profileStore
        self._name = State(initialValue: profile.name)
        self._selectedProviders = State(initialValue: Set(profile.providers))
    }

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                TextField("Profile Name", text: $name)
            }
            Section(header: Text("Providers")) {
                ForEach(AIProvider.allCases) { provider in
                    Toggle(isOn: Binding(
                        get: { selectedProviders.contains(provider) },
                        set: { isOn in
                            if isOn { selectedProviders.insert(provider) }
                            else { selectedProviders.remove(provider) }
                        }
                    )) {
                        Text(provider.rawValue)
                    }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    profileStore.renameProfile(id: profile.id, newName: name)
                    profileStore.updateProviders(for: profile.id, providers: Array(selectedProviders))
                    dismiss()
                }
            }
        }
    }
} 

================================================================================
FILE: ChatPane.swift
================================================================================

import SwiftUI
import WebKit

/// One browser tab + its UI state.
@MainActor
final class ChatPane: ObservableObject, Identifiable {
    let id       = UUID()
    let title    : String
    let provider : AIProvider

    @Published var isProviderPicker = false   // <── NEW

    @Published var isSelected: Bool = true {
        didSet { webView.isHidden = !isSelected }
    }

    // Use the custom subclass that prevents horizontal scroll hijacking
    let webView: PaneWebView = PaneWebView(
        frame: .zero,
        configuration: SharedWebKit.configuration()
    )

    init(provider: AIProvider,
         title: String,
         loadOnInit: Bool = true)           // default = current behaviour
    {
        self.provider = provider
        self.title = title // Use provided title

        // Only load URL if requested and valid
        guard loadOnInit,
              let url = provider.defaultUrl else {
            // Handle error case or simply don't load if loadOnInit is false
            if loadOnInit { // Only print error if loading was intended
                print("Error: Could not get default URL for provider \(provider.rawValue)")
            }
            // For now, just create the webview without loading if loadOnInit is false or URL is invalid
            return
        }

        let request = URLRequest(url: url)
        Task {
            // Ensure webView is initialized before loading
            await self.webView.load(request)
        }
    }

    // convenience ctor used **only** for the new-tab picker
    static func newTabPicker() -> ChatPane {
        // use any provider – we are *not* going to load it yet
        let pane = ChatPane(provider: .chatGPT, title: "New tab", loadOnInit: false)
        pane.isProviderPicker = true                       // flag it
        pane.isSelected       = false                    // Keep WKWebView hidden
        pane.webView.resignFirstResponder()              // 🆕 Force old view to let go
        return pane
    }

    /// Sets prompt and clicks submit based on the provider.
    func sendCurrentPrompt(promptText: String) async -> String {
        // 1. Sanitize promptText (common for all providers)
        let sanitizedPrompt = promptText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")

        // 2. Construct provider-specific JavaScript
        let javascriptString: String

        // +++ ADDED: Provider Switch +++
        switch provider {
        case .you:
            // --- Logic for You.com (Existing) ---
            javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`;
                const editorSelector = '#search-input-textarea'; // You.com uses textarea
                const sendButtonSelector = 'button[type="submit"]'; // You.com uses submit button

                console.log("PromptSenderApp (You.com): Starting native setter/submit sequence.");

                const editor = document.querySelector(editorSelector);
                if (!editor) {
                    console.error(`PromptSenderApp (You.com): Could not find editor: ${editorSelector}`);
                    return 'NO_EDITOR_YOU';
                }
                console.log("PromptSenderApp (You.com): Found editor.");

                try {
                    const nativeTextAreaValueSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, "value").set;
                    if (nativeTextAreaValueSetter) {
                        nativeTextAreaValueSetter.call(editor, promptText);
                        console.log("PromptSenderApp (You.com): Called native value setter.");
                    } else {
                         console.warn("PromptSenderApp (You.com): Could not get native value setter. Falling back...");
                         editor.value = promptText;
                    }
                } catch (e) {
                     console.error("PromptSenderApp (You.com): Error during native value setting:", e, ". Falling back...");
                     editor.value = promptText;
                }

                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (You.com): Dispatched input event.");

                setTimeout(() => {
                    const buttons = document.querySelectorAll(sendButtonSelector);
                    if (buttons.length === 0) {
                        console.error(`PromptSenderApp (You.com): Could not find button: ${sendButtonSelector}`);
                        return; // No button found - implicitly returns undefined -> JS_NON_STRING
                    }
                    const sendButton = buttons[0];
                    if (sendButton.disabled || sendButton.hasAttribute('disabled')) {
                        console.warn("PromptSenderApp (You.com): Send button disabled.");
                        return; // Button disabled - implicitly returns undefined -> JS_NON_STRING
                    }
                    sendButton.click();
                    console.log("PromptSenderApp (You.com): Clicked button.");
                }, 200);

                return 'OK_YOU';
            })();
            """

        case .chatGPT:
            // --- Logic for ChatGPT (Revised based on contenteditable div analysis) ---
             javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`; // Keep sanitization
                // Use the specific selector from the new analysis
                const editorSelector = 'div#prompt-textarea[contenteditable="true"]'; 

                console.log("PromptSenderApp (ChatGPT - ProseMirror): Starting interaction with contenteditable div.");

                const editorDiv = document.querySelector(editorSelector);
                if (!editorDiv) {
                    console.error(`PromptSenderApp (ChatGPT - PM): Could not find contenteditable div: ${editorSelector}`);
                    return 'NO_EDITOR_DIV_PM';
                }
                console.log("PromptSenderApp (ChatGPT - PM): Found contenteditable div.");

                // 1. Focus the editor
                editorDiv.focus();
                console.log("PromptSenderApp (ChatGPT - PM): Focused editor div.");

                // 2. Set the content (Try textContent first)
                //    If placeholder <p> causes issues, might need: editorDiv.innerHTML = ''; first
                editorDiv.textContent = promptText;
                // Alternative: editorDiv.innerHTML = `<p>${promptText}</p>`;
                console.log(`PromptSenderApp (ChatGPT - PM): Set textContent to: ${promptText}`);

                // 3. Dispatch an 'input' event
                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editorDiv.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (ChatGPT - PM): Dispatched input event on editor div.");

                // 4. Add a delay BEFORE attempting button interaction
                setTimeout(() => {
                    const sendButtonSelector = 'button[data-testid="send-button"]'; // Target the actual send button
                    const sendButton = document.querySelector(sendButtonSelector);
                    if (!sendButton) {
                        console.error(`PromptSenderApp (ChatGPT - PM): Could not find button: ${sendButtonSelector}. (Is text long enough to enable it?)`);
                        return; // Implicitly returns JS_NON_STRING
                    }
                    console.log("PromptSenderApp (ChatGPT - PM): Found button.");

                    // Check the standard disabled attribute
                    if (sendButton.disabled || sendButton.hasAttribute('disabled')) {
                        console.warn("PromptSenderApp (ChatGPT - PM): Button is disabled after setting text and dispatching input. Framework likely did not fully recognize input.");
                    } else {
                        console.log("PromptSenderApp (ChatGPT - PM): Button appears enabled. Simulating click.");
                        sendButton.click();
                        console.log("PromptSenderApp (ChatGPT - PM): Click simulated.");
                    }
                }, 250); // Use suggested delay

                return 'OK_ATTEMPTED_DIV_SET_PM'; // New status code
            })();
            """
        case .claude:
            javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`;
                const editorSelector = 'div.ProseMirror[contenteditable="true"]';
                const sendButtonSelector = 'button[aria-label="Send message"]';

                console.log("PromptSenderApp (Claude): Starting interaction.");

                const editor = document.querySelector(editorSelector);
                if (!editor) {
                    console.error(`PromptSenderApp (Claude): Could not find editor: ${editorSelector}`);
                    return 'NO_EDITOR_CLAUDE';
                }
                console.log("PromptSenderApp (Claude): Found editor.");

                // 1. Focus (Recommended)
                editor.focus();
                console.log("PromptSenderApp (Claude): Focused editor.");

                // 2. Set Content (Using textContent, might need innerHTML/<p> if complex)
                //    Clear existing content might be needed if placeholder interferes
                //    editor.innerHTML = ''; // Optional: Clear first
                editor.textContent = promptText;
                console.log(`PromptSenderApp (Claude): Set textContent to: ${promptText}`);

                // 3. Dispatch Input Event
                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (Claude): Dispatched input event.");

                // 4. Wait and Click Button
                setTimeout(() => {
                    const sendButton = document.querySelector(sendButtonSelector);
                    if (!sendButton) {
                        console.error(`PromptSenderApp (Claude): Could not find button: ${sendButtonSelector}`);
                        return; // Implicitly returns JS_NON_STRING_CLAUDE
                    }
                    console.log("PromptSenderApp (Claude): Found button.");

                    if (sendButton.disabled || sendButton.hasAttribute('disabled')) {
                        console.warn("PromptSenderApp (Claude): Send button is disabled after dispatching input. Framework interaction likely incomplete or needs more time.");
                        // Consider adding MutationObserver logic here in the future if needed
                        return; // Implicitly returns JS_NON_STRING_CLAUDE (or a specific code like BUTTON_DISABLED_CLAUDE)
                    }

                    console.log("PromptSenderApp (Claude): Button appears enabled. Clicking.");
                    sendButton.click();
                    console.log("PromptSenderApp (Claude): Clicked button.");
                }, 250); // Use a delay similar to ChatGPT

                return 'OK_CLAUDE'; // Indicate success
            })();
            """
        case .aistudio:
            javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`;
                // Use a selector that matches EITHER aria-label
                const editorSelector = 'textarea[aria-label="Type something"], textarea[aria-label="Type something or pick one from prompt gallery"]';
                const sendButtonSelector = 'button[aria-label="Run"]';

                console.log("PromptSenderApp (AI Studio): Starting interaction.");

                // Query for the editor using the combined selector
                const editor = document.querySelector(editorSelector);
                if (!editor) {
                    console.error(`PromptSenderApp (AI Studio): Could not find editor with selectors: ${editorSelector}`);
                    return 'NO_EDITOR_AISTUDIO';
                }
                console.log(`PromptSenderApp (AI Studio): Found editor with aria-label: ${editor.getAttribute('aria-label')}`);

                // 1. Set Value for <textarea>
                editor.value = promptText;
                console.log(`PromptSenderApp (AI Studio): Set editor value.`);

                // 2. Dispatch Input Event (Crucial for Angular/frameworks)
                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (AI Studio): Dispatched input event.");

                // 3. Wait and Click Button (Logic remains the same)
                setTimeout(() => {
                    const sendButton = document.querySelector(sendButtonSelector);
                    if (!sendButton) {
                        console.error(`PromptSenderApp (AI Studio): Could not find button: ${sendButtonSelector}`);
                        return; // Implicitly returns JS_NON_STRING_AISTUDIO
                    }
                    console.log("PromptSenderApp (AI Studio): Found button.");

                    if (sendButton.disabled || sendButton.hasAttribute('disabled')) {
                        console.warn("PromptSenderApp (AI Studio): Send button is disabled. Framework likely needs more time or input not fully registered.");
                        return; // Implicitly returns JS_NON_STRING_AISTUDIO or BUTTON_DISABLED_AISTUDIO
                    }

                    console.log("PromptSenderApp (AI Studio): Button appears enabled. Clicking.");
                    sendButton.click();
                    console.log("PromptSenderApp (AI Studio): Clicked button.");
                }, 250);

                return 'OK_AISTUDIO';
            })();
            """
        case .grok:
            javascriptString = """
            (function() {
                const promptText = `\(sanitizedPrompt)`;
                const editorSelector = 'textarea[aria-label="Ask Grok anything"]';
                const sendButtonSelector = 'button[aria-label="Submit"]';

                console.log("PromptSenderApp (Grok): Starting native setter + InputEvent simulation.");

                const box = document.querySelector(editorSelector);
                const sendBtn = document.querySelector(sendButtonSelector);

                if (!box) {
                    console.error(`PromptSenderApp (Grok): Could not find editor: ${editorSelector}`);
                    return 'NO_EDITOR_GROK';
                }
                if (!sendBtn) {
                    // Log this but continue, as the button might appear later
                    console.warn(`PromptSenderApp (Grok): Could not find send button initially: ${sendButtonSelector}`);
                }
                console.log("PromptSenderApp (Grok): Found editor.");

                /* 1. put focus on the box */
                box.focus();
                console.log("PromptSenderApp (Grok): Focused editor.");

                /* 2. set the value through the native prototype's setter */
                const nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
                if (!nativeSetter) {
                    console.error("PromptSenderApp (Grok): Could not get native value setter.");
                    return 'NO_NATIVE_SETTER_GROK';
                }
                nativeSetter.call(box, promptText);
                console.log("PromptSenderApp (Grok): Called native value setter.");

                /* 3. dispatch a real looking InputEvent */
                const ev = new InputEvent('input', {
                    bubbles: true,
                    cancelable: false, // As per analysis
                    inputType: 'insertFromPaste',
                    data: promptText
                });
                box.dispatchEvent(ev);
                console.log("PromptSenderApp (Grok): Dispatched targeted InputEvent.");

                /* 4. wait one macrotask */
                setTimeout(() => {
                    // Re-query button inside timeout as it might have changed state/appeared
                    const currentSendBtn = document.querySelector(sendButtonSelector);
                    if (!currentSendBtn) {
                         console.error(`PromptSenderApp (Grok): Could not find button inside timeout: ${sendButtonSelector}`);
                         return; // Implicitly returns JS_NON_STRING_GROK
                    }
                    console.log("PromptSenderApp (Grok): Found button inside timeout.");

                    if (currentSendBtn.disabled || currentSendBtn.hasAttribute('disabled')) {
                        console.warn("PromptSenderApp (Grok): Submit button STILL disabled after native set + InputEvent. State update likely failed.");
                        return; // Implicitly returns JS_NON_STRING_GROK or BUTTON_DISABLED_GROK
                    }

                    console.log("PromptSenderApp (Grok): Button appears enabled. Clicking.");
                    currentSendBtn.click();
                    console.log("PromptSenderApp (Grok): Clicked button.");

                }, 0); // Use timeout 0 for the next macrotask

                return 'OK_GROK_NATIVE_INPUT'; // New status code
            })();
            """
        case .perplexity:
            // --- Logic for Perplexity (Using setTimeout before query) ---
            javascriptString = """
            (function() { // Changed back to regular function
                const promptText = `\(sanitizedPrompt)`;
                const editorSelector = 'textarea#ask-input';
                // Keep both selectors for clarity
                const sendButtonSelector = 'button[aria-label="Send"][type="submit"]';
                const enabledSendButtonSelector = 'button[aria-label="Send"][type="submit"]:not([disabled])';

                console.log("PromptSenderApp (Perplexity): Starting native setter + InputEvent + setTimeout(60).");

                const editor = document.querySelector(editorSelector);
                if (!editor) { // Simpler check is sufficient now
                    console.error(`PromptSenderApp (Perplexity): Could not find editor: ${editorSelector}`);
                    return 'NO_EDITOR_PERPLEXITY';
                }
                console.log("PromptSenderApp (Perplexity): Found editor.");

                // 1. Set the value through the native prototype's setter
                const nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
                if (!nativeSetter) {
                    console.error("PromptSenderApp (Perplexity): Could not get native value setter.");
                    return 'NO_NATIVE_SETTER_PERPLEXITY';
                }
                nativeSetter.call(editor, promptText);
                console.log("PromptSenderApp (Perplexity): Called native value setter.");

                // 2. Dispatch a standard 'input' event
                const inputEvent = new Event('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (Perplexity): Dispatched standard input event.");

                // 3. Wait ~60ms for React to update DOM, then query and click/fallback
                setTimeout(() => {
                    // Query for the *enabled* button *inside* the timeout
                    const sendButton = document.querySelector(enabledSendButtonSelector);

                    if (sendButton) {
                        // Found the enabled button
                        console.log("PromptSenderApp (Perplexity): Found enabled button after timeout. Clicking.");
                        sendButton.click();
                        console.log("PromptSenderApp (Perplexity): Clicked button.");
                        // Decide on return code - maybe OK_PERPLEXITY_TIMEOUT_CLICK?
                        // Using a distinct one helps debugging if it works vs observer
                        return 'OK_PERPLEXITY_TIMEOUT_CLICK';
                    } else {
                        // Enabled button not found, try fallback
                        console.warn(`PromptSenderApp (Perplexity): Enabled button not found after 60ms (${enabledSendButtonSelector}). Falling back to Enter key.`);
                        try {
                            ['keydown','keyup'].forEach(type =>
                                editor.dispatchEvent(new KeyboardEvent(type, {
                                    key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true, cancelable: true
                                }))
                            );
                            console.log("PromptSenderApp (Perplexity): Simulated Enter key events.");
                             // Use distinct code for fallback success
                            return 'OK_PERPLEXITY_ENTER_FALLBACK_TIMEOUT';
                        } catch (keyError) {
                            console.error("PromptSenderApp (Perplexity): Error simulating Enter key:", keyError);
                             // Use distinct code for fallback failure
                            return 'FAIL_PERPLEXITY_BOTH_TIMEOUT';
                        }
                    }
                    // Note: return statements inside setTimeout don't return from the outer function.
                    // The main function implicitly returns undefined here (JS_NON_STRING...)
                    // which is acceptable as the action was attempted.
                }, 60); // 60ms delay

                // The main function returns *before* the timeout completes.
                // We need a status code indicating the attempt was initiated.
                 return 'OK_PERPLEXITY_ATTEMPT_INITIATED';
            })();
            """
        case .gemini:
             // --- Logic for Gemini (Quill/Angular) ---
             javascriptString = """
             (function() {
                const promptText = `\(sanitizedPrompt)`;
                const editorSelector = 'div[contenteditable="true"][aria-label="Enter a prompt here"]';
                const sendButtonSelector = 'button.send-button[aria-label="Send message"]'; // Using slightly more specific selector

                console.log("PromptSenderApp (Gemini): Starting interaction.");

                const editor = document.querySelector(editorSelector);
                if (!editor) {
                    console.error(`PromptSenderApp (Gemini): Could not find editor: ${editorSelector}`);
                    return 'NO_EDITOR_GEMINI';
                }
                console.log("PromptSenderApp (Gemini): Found editor.");

                // 1. Focus the editor
                editor.focus();
                console.log("PromptSenderApp (Gemini): Focused editor.");

                // 2. Set Content (using textContent for Quill)
                editor.textContent = promptText;
                console.log(`PromptSenderApp (Gemini): Set textContent to: ${promptText}`);

                // 3. Dispatch Input Event (Quill/Angular listens for this)
                // Using InputEvent as suggested
                const inputEvent = new InputEvent('input', { bubbles: true, cancelable: true });
                editor.dispatchEvent(inputEvent);
                console.log("PromptSenderApp (Gemini): Dispatched input event.");

                // 4. Wait for Angular change detection, then click button
                setTimeout(() => {
                    const sendButton = document.querySelector(sendButtonSelector);
                    if (!sendButton) {
                        console.error(`PromptSenderApp (Gemini): Could not find button inside timeout: ${sendButtonSelector}`);
                        return; // Implicitly returns JS_NON_STRING_GEMINI
                    }
                    console.log("PromptSenderApp (Gemini): Found button inside timeout.");

                    // Check aria-disabled state
                    const isDisabled = sendButton.getAttribute('aria-disabled') === 'true';
                    if (isDisabled) {
                        console.warn("PromptSenderApp (Gemini): Send button is aria-disabled='true' after dispatching input. Framework interaction likely incomplete or needs more time.");
                        return; // Implicitly returns JS_NON_STRING_GEMINI or BUTTON_DISABLED_GEMINI
                    }

                    console.log("PromptSenderApp (Gemini): Button appears enabled (aria-disabled!=true). Clicking.");
                    sendButton.click();
                    console.log("PromptSenderApp (Gemini): Clicked button.");
                }, 50); // Use suggested 50ms delay

                return 'OK_GEMINI_ATTEMPTED'; // Indicate success attempt
             })();
             """
        case .mistral:
            // --- Logic for Mistral (Le Chat - Shadow DOM Aware) ---
            javascriptString = """
            (async function() { // Use async IIFE
                const promptText = `\(sanitizedPrompt)`;

                // --- Helper Functions ---
                function waitFor(fn, timeout = 2000, interval = 50) {
                    return new Promise(res => {
                        const t0 = performance.now();
                        const id = setInterval(() => {
                            const r = typeof fn === 'function' ? fn() : fn;
                            if (r) {
                                clearInterval(id);
                                res(r);
                            } else if (performance.now() - t0 > timeout) {
                                clearInterval(id);
                                res(null); // Resolve with null on timeout
                            }
                        }, interval);
                    });
                }

                function getVisibleTextarea(doc = document) {
                    let areas = [...doc.querySelectorAll('textarea[name="message.text"]')];
                    doc.querySelectorAll('*').forEach(el => {
                        if (el.shadowRoot) {
                            try {
                                areas = areas.concat(
                                    [...el.shadowRoot.querySelectorAll('textarea[name="message.text"]')]
                                );
                            } catch (e) {
                                 console.warn("Error accessing shadowRoot for", el, e);
                            }
                        }
                    });
                    // Return the one that's actually on screen (rendered and visible)
                    return areas.find(t => t.offsetParent);
                }

                function setReactValue(el, value) {
                    // Use window.HTMLTextAreaElement for safety
                    const proto = window.HTMLTextAreaElement.prototype;
                    const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
                    if (setter) {
                         setter.call(el, value);
                    } else {
                        console.warn("Could not get native value setter for", el);
                        // Fallback? Or rely on error handling below?
                        el.value = value; // Less reliable fallback
                    }
                }

                async function fillMistral(prompt) {
                    console.log("PromptSenderApp (Mistral): Waiting for textarea...");
                    const ta = await waitFor(getVisibleTextarea, 3000);
                    if (!ta) {
                        console.error('PromptSenderApp (Mistral): Textarea not found after wait.');
                        throw new Error('Mistral textarea not found');
                    }
                    console.log("PromptSenderApp (Mistral): Textarea found. Filling...");
                    ta.focus();
                    setReactValue(ta, prompt);
                    ta.dispatchEvent(new Event('input',  { bubbles: true }));
                    ta.dispatchEvent(new Event('change', { bubbles: true }));
                    console.log("PromptSenderApp (Mistral): Textarea filled and events dispatched.");
                }

                async function sendMistral() {
                    const ta = getVisibleTextarea(); // Assume it exists if fill succeeded
                    if (!ta) throw new Error("Textarea vanished before send?"); // Should not happen
                    const root = ta.getRootNode(); // Find root (document or shadowRoot)

                    const btnSel = 'button[type="submit"][aria-label="Send question"]:not([disabled])';
                    console.log("PromptSenderApp (Mistral): Waiting for enabled send button...");
                    const btn = await waitFor(() => root.querySelector(btnSel), 1500); // Shorter timeout for button
                    if (!btn) {
                         console.error('PromptSenderApp (Mistral): Send button still disabled after wait.');
                         throw new Error('Send button still disabled');
                    }
                    console.log("PromptSenderApp (Mistral): Enabled button found. Clicking...");
                    btn.click();
                    console.log("PromptSenderApp (Mistral): Button clicked.");
                }

                // --- Main Execution Logic ---
                try {
                    console.log("PromptSenderApp (Mistral): Starting fill/send sequence...");
                    await fillMistral(promptText);
                    await sendMistral();
                    console.log("PromptSenderApp (Mistral): Fill/send sequence completed successfully.");
                    return 'OK_MISTRAL_SHADOW_ATTEMPTED'; // New success code
                } catch (e) {
                    console.error("PromptSenderApp (Mistral): Error during fill/send:", e);
                    // Return a specific error based on the message if possible
                    if (e.message.includes('textarea not found')) {
                        return 'FAIL_MISTRAL_NO_TEXTAREA';
                    } else if (e.message.includes('still disabled')) {
                         return 'FAIL_MISTRAL_BUTTON_DISABLED';
                    } else {
                         return 'FAIL_MISTRAL_UNKNOWN_ERROR';
                    }
                }
            })();
            """
        }
        // +++ END ADDED CODE ---

        // 3. Call evaluateJavaScript with the chosen string
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(javascriptString) { result, error in
                if let error = error {
                    // Add provider info to error message
                    print("Error evaluating JS for \(self.provider.rawValue): \(error)")
                    // Return a provider-specific error code if needed, or generic
                    continuation.resume(returning: "JS_ERROR_\(self.provider.rawValue)")
                    return
                }
                if let resultString = result as? String {
                    continuation.resume(returning: resultString)
                } else {
                    print("JS evaluation for \(self.provider.rawValue) returned non-string: \(type(of: result)), value: \(result ?? "nil")")
                    // Return a provider-specific code if needed
                    continuation.resume(returning: "JS_NON_STRING_\(self.provider.rawValue)")
                }
            }
        }
    }
}


================================================================================
FILE: MainModel.swift
================================================================================

import SwiftUI

/// Represents the AI service provider for a pane.
enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case you = "You.com"
    case chatGPT = "ChatGPT"
    // Add claude later
    case claude = "Claude"
    case aistudio = "AI Studio"
    case grok = "Grok"
    case perplexity = "Perplexity"
    case gemini = "Gemini"
    case mistral = "Mistral"

    var id: String { self.rawValue }

    var defaultUrl: URL? {
        switch self {
        case .you:
            return URL(string: "https://chat.you.com")!
        case .chatGPT:
            return URL(string: "https://chat.openai.com")!
        case .claude:
            return URL(string: "https://claude.ai")!
        case .aistudio:
            return URL(string: "https://aistudio.google.com/app/prompts/new_chat")!
        case .grok:
            return URL(string: "https://grok.com")!
        case .perplexity:
            return URL(string: "https://www.perplexity.ai/")!
        case .gemini:
            return URL(string: "https://gemini.google.com/app")!
        case .mistral:
            return URL(string: "https://chat.mistral.ai/")!
        }
    }

    // Add other provider-specific details here if needed later
}

@MainActor
final class MainModel: ObservableObject {

    // MARK: - Profiles
    @Published var profileStore = ProfileStore()

    // UserDefaults keys
    private let savedProvidersKey = "savedPaneProviders_v1"
    private let savedFocusIndexKey = "savedFocusedIndex_v1"

    @Published var panes: [ChatPane] = []

    @Published var promptText: String = ""
    @Published var isBroadcasting: Bool = false
    @Published var focusedPaneIndex: Int? = nil // Index of the pane that should have focus

    func addPane(provider: AIProvider) {
        let newPane = ChatPane(provider: provider, title: provider.rawValue)
        newPane.isSelected = true
        panes.append(newPane)
        print("Added pane for: \(provider.rawValue). Total panes: \(panes.count)")
        // If this is the first pane added, focus it
        if focusedPaneIndex == nil && panes.count == 1 {
            focusedPaneIndex = 0
            print("Setting initial focus index to 0")
        }
        savePanesState() // Save after adding
    }

    func removePane(id: UUID) {
        guard let removedIndex = panes.firstIndex(where: { $0.id == id }) else { return }

        panes.removeAll { $0.id == id }
        print("Removed pane with ID: \(id). Total panes: \(panes.count)")

        // Adjust focus if the focused pane was removed or a later pane was removed
        if let currentFocus = focusedPaneIndex {
            if panes.isEmpty {
                focusedPaneIndex = nil // No panes left
            } else if removedIndex == currentFocus {
                // Focus the previous one (wrapping around if needed)
                focusedPaneIndex = (currentFocus - 1 + panes.count) % panes.count
            } else if removedIndex < currentFocus {
                // A pane before the focused one was removed, decrement focus index
                focusedPaneIndex = currentFocus - 1
            }
            // If removedIndex > currentFocus, focus index remains the same
             print("Adjusted focus index to: \(focusedPaneIndex ?? -1)")
        }
        savePanesState() // Save after removing and adjusting focus
    }

    // Function to cycle focus between panes
    func cycleFocus(forward: Bool) {
        guard panes.count > 1, let currentIndex = focusedPaneIndex else { return } // Need at least 2 panes to cycle

        let offset = forward ? 1 : -1
        let nextIndex = (currentIndex + offset + panes.count) % panes.count
        // Use setFocus to ensure save is called
        setFocus(to: nextIndex)
        // focusedPaneIndex = nextIndex // Directly setting bypasses save
        // print("Cycling focus. New index: \(focusedPaneIndex ?? -1)")
        // savePanesState() // Save after cycling focus - Handled by setFocus
    }

    // Function to directly set focus to a specific pane index
    func setFocus(to index: Int) {
        guard index >= 0 && index < panes.count else {
            print("SetFocus Error: Index \(index) out of bounds (0..\(panes.count-1))")
            return
        }
        // Only save if the index actually changes
        if focusedPaneIndex != index {
            focusedPaneIndex = index
            print("Setting focus directly to index: \(index)")
            savePanesState() // Save after setting focus
        }
    }

    // MARK: - Persistence (UserDefaults)

    func savePanesState() {
        let providerRawValues = panes.map { $0.provider.rawValue }
        UserDefaults.standard.set(providerRawValues, forKey: savedProvidersKey)

        if let index = focusedPaneIndex {
            UserDefaults.standard.set(index, forKey: savedFocusIndexKey)
        } else {
            // If no focus, remove the key
            UserDefaults.standard.removeObject(forKey: savedFocusIndexKey)
        }
        print("Persistence: Saved \(providerRawValues.count) panes and focus index \(focusedPaneIndex ?? -1)")
    }

    func loadPanesState() {
        guard let providerRawValues = UserDefaults.standard.array(forKey: savedProvidersKey) as? [String] else {
            print("Persistence: No saved pane provider data found.")
            return // No saved state
        }

        // Only load if panes are currently empty to avoid duplication on hot reload/previews
        guard panes.isEmpty else {
            print("Persistence: Panes not empty, skipping load.")
            return
        }

        print("Persistence: Loading saved pane state...")
        var loadedFocusIndex: Int? = UserDefaults.standard.object(forKey: savedFocusIndexKey) as? Int

        for rawValue in providerRawValues {
            if let provider = AIProvider(rawValue: rawValue) {
                // Use a temporary non-publishing add method or simply call addPane
                // directly since we are controlling the loading sequence.
                // Calling addPane here will trigger focus logic, which is fine.
                addPane(provider: provider) // This adds the pane
            } else {
                print("Persistence Warning: Unknown provider rawValue loaded: \(rawValue)")
            }
        }

        // Validate and restore focus AFTER panes are added
        if let index = loadedFocusIndex, index >= 0 && index < panes.count {
            focusedPaneIndex = index
            print("Persistence: Restored focus index to \(index)")
        } else {
            // If saved index is invalid or missing, default to first pane if any
            if !panes.isEmpty && focusedPaneIndex == nil {
                focusedPaneIndex = 0
                print("Persistence: Saved focus invalid/missing, defaulting focus to 0.")
            }
        }
        print("Persistence: Finished loading state. Total panes: \(panes.count), Focus: \(focusedPaneIndex ?? -1)")
    }

    /// Sends the text from the app's input field to all selected panes CONCURRENTLY.
    func broadcast() {
        let textToSend = promptText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !isBroadcasting else {
            print("Broadcast (Parallel): Already in progress, ignoring trigger.")
            return
        }
        guard !textToSend.isEmpty else {
            print("Broadcast (Parallel): Prompt text is empty.")
            return
        }
        guard !panes.isEmpty else {
            print("Broadcast (Parallel): No panes open.")
            return
        }

        // Set flag immediately on the main actor
        isBroadcasting = true
        print("Broadcast (Parallel): >>> Setting isBroadcasting = true <<<")
        print("Broadcast (Parallel): Text to send = '\(textToSend)'")

        // Launch a detached task to perform the concurrent sends off the main thread initially
        Task.detached(priority: .userInitiated) {
            // Fetch the panes array from the MainActor *before* starting the TaskGroup
            let panesToBroadcast = await self.panes
            print("Broadcast (Parallel): Sending concurrently to \(panesToBroadcast.count) panes.")

            // Use a TaskGroup to manage concurrent sends
            await withTaskGroup(of: Void.self) { group in
                // Iterate over the local copy of the array
                for pane in panesToBroadcast {
                    // Add a task to the group for sending the prompt to this pane
                    group.addTask {
                        print("Broadcast (Parallel): Starting send to \(pane.title)")
                        // Call sendCurrentPrompt (which is MainActor isolated)
                        // The await here happens within the child task.
                        let result = await pane.sendCurrentPrompt(promptText: textToSend)
                        print("Broadcast (Parallel): Result for \(pane.title): \(result)")
                        // TODO: Consider collecting results or handling errors if needed
                    }
                }
                // The TaskGroup automatically waits for all added tasks to complete here.
                 print("Broadcast (Parallel): TaskGroup finished.")
            }

            // After all tasks in the group are complete, switch back to the main actor
            // to update the UI state (reset flag and clear text).
            await MainActor.run {
                print("Broadcast (Parallel): <<< Setting isBroadcasting = false >>>")
                self.isBroadcasting = false
                // Clear the text field after attempting all sends.
                // We are not currently checking for errors within the group.
                self.promptText = ""
                print("Broadcast (Parallel): Cleared prompt text field.")
            }
        }
    }

    /// Loads the currently active profile's providers into panes.
    func loadActiveProfile() {
        guard let profile = profileStore.activeProfile else {
            print("MainModel: No active profile to load.")
            return
        }
        print("MainModel: Loading profile '\(profile.name)' with \(profile.providers.count) providers.")
        // Rebuild panes based on profile
        panes = profile.providers.map { provider in
            let pane = ChatPane(provider: provider, title: provider.rawValue)
            pane.isSelected = true
            return pane
        }
        // Reset focus to first pane if available
        focusedPaneIndex = panes.isEmpty ? nil : 0
    }

    // MARK: - New-tab picker -------------------------------------------------
    func openNewTabPicker() {
        let picker = ChatPane.newTabPicker()
        panes.append(picker)
        focusedPaneIndex = panes.count - 1          // focus the new one
        savePanesState() // Save state after adding picker pane
    }

    func replacePicker(at index: Int, with provider: AIProvider) {
        guard index >= 0, index < panes.count else { 
            print("ReplacePicker Error: Index \(index) out of bounds (0..\(panes.count-1))")
            return 
        }
        // Ensure we are replacing a picker pane
        guard panes[index].isProviderPicker else {
             print("ReplacePicker Warning: Pane at index \(index) is not a picker pane.")
             return // Ensure this guard also exits
        }

        let realPane = ChatPane(provider: provider, title: provider.rawValue)
        // Preserve selection state if needed, or just assume new pane is selected
        // realPane.isSelected = panes[index].isSelected 
        panes[index] = realPane
        focusedPaneIndex = index                    // keep focus
        savePanesState() // Save state after replacing picker with real pane
        print("Replaced picker at index \(index) with \(provider.rawValue)")
    }
}


================================================================================
FILE: LLMListWindowView.swift
================================================================================

import SwiftUI

/// A window view listing all available LLM providers.
struct LLMListWindowView: View {
    let providers = AIProvider.allCases
    /// Called when the user selects a provider from the list
    var onSelect: (AIProvider) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Available LLMs")
                .font(.title2)
                .padding(.bottom, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(providers) { provider in
                        Button(action: {
                            onSelect(provider)
                        }) {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 6))
                                Text(provider.rawValue)
                                    .font(.body)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .padding(20)
        .frame(minWidth: 250, minHeight: 300)
    }
}

#if DEBUG
struct LLMListWindowView_Previews: PreviewProvider {
    static var previews: some View {
        LLMListWindowView(onSelect: { provider in })
    }
}
#endif 

================================================================================
FILE: SharedWebKit.swift
================================================================================

import WebKit

/// Single source of truth for cookies, local- & sessionStorage, and
/// JavaScript JIT permission across all WKWebViews in this process.
enum SharedWebKit {

    /// One global WKProcessPool => all panes share js/localStorage.
    static let pool: WKProcessPool = WKProcessPool()

    /// Convenience builder for a fully wired configuration.
    static func configuration() -> WKWebViewConfiguration {
        let cfg         = WKWebViewConfiguration()
        cfg.processPool = pool
        cfg.websiteDataStore = .default()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        return cfg
    }

    // --- JavaScript Snippets ---

    /// Gets the current value from the target text area.
    static let getJS: String =
    #"""
    (function() {
        const editor = document.querySelector('#search-input-textarea');
        return editor ? editor.value : null; // Return text or null if not found
    })();
    """#

    // NOTE: The following sendJS is NOT used by the current ChatPane implementation
    // (which generates JS dynamically), but kept here for reference of the
    // argument-passing approach.
    /// Sets the text area's value and simulates Cmd/Ctrl + Enter.
    static let sendJS_UNUSED: String =
    #"""
    (function(promptText) { // Expects promptText as the first argument
        const editor = document.querySelector('#search-input-textarea');
        if (!editor) {
            console.error("PromptSenderApp: Could not find editor #search-input-textarea");
            return 'NO_EDITOR';
        }
        if (typeof promptText !== 'string') {
             console.error("PromptSenderApp: Invalid or missing promptText argument.");
             return 'INVALID_ARG';
        }

        editor.value = promptText;
        const inputEvent = new Event('input', { bubbles: true, cancelable: true });
        editor.dispatchEvent(inputEvent);
        editor.focus();

        setTimeout(() => {
             ['metaKey','ctrlKey'].forEach(mod => {
                const keyDownEvent = new KeyboardEvent('keydown', {
                    key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
                    bubbles: true, cancelable: true, composed: true,
                    [mod]: true
                });
                console.log(`PromptSenderApp: Dispatching keydown with ${mod}=true after setting text`);
                editor.dispatchEvent(keyDownEvent);
            });
            // Optional keyup
            const keyUpEvent = new KeyboardEvent('keyup', {
                 key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true, composed: true
            });
            console.log("PromptSenderApp: Dispatching keyup");
            editor.dispatchEvent(keyUpEvent);

        }, 100);

        return 'OK';
    })();
    """#
}


================================================================================
FILE: ContentView.swift
================================================================================

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


================================================================================
SUMMARY: Extracted 15 Swift files from the codebase.
