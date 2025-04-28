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