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