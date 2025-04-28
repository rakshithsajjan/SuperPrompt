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