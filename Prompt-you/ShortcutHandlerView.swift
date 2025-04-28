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