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