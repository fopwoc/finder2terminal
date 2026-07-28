import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ProfileStore
    @State private var selection: String?
    @State private var editor: ProfileEditor?

    var body: some View {
        NavigationSplitView {
            List(store.profiles, selection: $selection) { profile in
                Label(profile.title, systemImage: "terminal")
                    .tag(profile.id)
            }
            .navigationTitle("Finder Actions")
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button {
                        editor = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add Finder Action")

                    Button {
                        removeSelectedProfile()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Delete Finder Action")
                    .disabled(selection == nil)

                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
            }
        } detail: {
            if let profile = selectedProfile {
                ProfileDetail(profile: profile) {
                    editor = .edit(profile)
                }
            } else {
                ContentUnavailableView(
                    "Select a Finder Action",
                    systemImage: "terminal",
                    description: Text("Create or select an action to configure it.")
                )
            }
        }
        .frame(minWidth: 680, minHeight: 400)
        .sheet(item: $editor) { editor in
            ProfileEditorView(editor: editor, store: store) { savedID in
                selection = savedID
                self.editor = nil
            }
        }
        .alert(
            "f2t",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK") {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert(
            "Delete all f2t data?",
            isPresented: $store.isPurgeConfirmationPresented
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                purgeAll()
            }
        } message: {
            Text(
                "This removes every f2t Finder workflow, temporary command script, "
                    + "profile, and saved app setting. This cannot be undone."
            )
        }
        .onAppear {
            selection = selection ?? store.profiles.first?.id
        }
    }

    private var selectedProfile: Profile? {
        guard let selection else {
            return nil
        }
        return store.profile(id: selection)
    }

    private func removeSelectedProfile() {
        guard let selection else {
            return
        }
        do {
            try store.remove(id: selection)
            self.selection = store.profiles.first?.id
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func purgeAll() {
        do {
            try store.purgeAll()
            selection = nil
        } catch {
            store.errorMessage = "Could not delete all f2t data: \(error.localizedDescription)"
        }
    }
}

private struct ProfileDetail: View {
    let profile: Profile
    let edit: () -> Void

    var body: some View {
        Form {
            LabeledContent("Finder menu title", value: profile.title)
            LabeledContent("Executable", value: profile.executable)
            LabeledContent("Arguments") {
                Text(profile.arguments.isEmpty ? "None" : profile.arguments.joined(separator: " "))
            }
            LabeledContent(
                "Keep terminal session open",
                value: profile.preserveSessionAfterCommand ? "On" : "Off"
            )
        }
        .formStyle(.grouped)
        .navigationTitle(profile.title)
        .toolbar {
            Button("Edit", action: edit)
        }
    }
}

private enum ProfileEditor: Identifiable {
    case new
    case edit(Profile)

    var id: String {
        switch self {
        case .new:
            "new"
        case let .edit(profile):
            profile.id
        }
    }
}

private struct ProfileEditorView: View {
    let editor: ProfileEditor
    let store: ProfileStore
    let didSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var executable: String
    @State private var arguments: String
    @State private var preserveSessionAfterCommand: Bool
    @State private var validationMessage: String?

    init(
        editor: ProfileEditor,
        store: ProfileStore,
        didSave: @escaping (String) -> Void
    ) {
        self.editor = editor
        self.store = store
        self.didSave = didSave

        let profile: Profile? = if case let .edit(profile) = editor {
            profile
        } else {
            nil
        }
        _title = State(initialValue: profile?.title ?? "")
        _executable = State(initialValue: profile?.executable ?? "")
        _arguments = State(initialValue: profile?.arguments.joined(separator: "\n") ?? "")
        _preserveSessionAfterCommand = State(
            initialValue: profile?.preserveSessionAfterCommand ?? true
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "New Finder Action" : "Edit Finder Action")
                .font(.title2)

            Form {
                TextField("Finder menu title", text: $title)
                TextField("Executable", text: $executable)
                TextField("Arguments (one per line)", text: $arguments, axis: .vertical)
                    .lineLimit(3...8)
                Toggle(
                    "Keep terminal session open after command exits",
                    isOn: $preserveSessionAfterCommand
                )
            }

            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var isNew: Bool {
        if case .new = editor {
            return true
        }
        return false
    }

    private var parsedArguments: [String] {
        arguments
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        do {
            switch editor {
            case .new:
                let profile = try store.add(
                    title: title,
                    executable: executable,
                    arguments: parsedArguments,
                    preserveSessionAfterCommand: preserveSessionAfterCommand
                )
                didSave(profile.id)
            case let .edit(profile):
                try store.update(
                    id: profile.id,
                    title: title,
                    executable: executable,
                    arguments: parsedArguments,
                    preserveSessionAfterCommand: preserveSessionAfterCommand
                )
                didSave(profile.id)
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
