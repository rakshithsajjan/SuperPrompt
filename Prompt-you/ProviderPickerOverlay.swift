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