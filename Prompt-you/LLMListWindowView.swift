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