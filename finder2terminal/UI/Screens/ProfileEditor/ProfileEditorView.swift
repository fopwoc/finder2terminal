import SwiftUI

struct ProfileEditorView: View {
    typealias SaveProfile = (
        _ editor: ProfileEditorMode,
        _ title: String,
        _ executable: String,
        _ arguments: [String],
        _ targetKind: ProfileTargetKind,
        _ preserveSessionAfterCommand: Bool
    ) throws -> String

    let editor: ProfileEditorMode
    let saveProfile: SaveProfile
    let didSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var executable: String
    @State private var arguments: String
    @State private var targetKind: ProfileTargetKind
    @State private var preserveSessionAfterCommand: Bool
    @State private var validationMessage: String?

    init(
        editor: ProfileEditorMode,
        saveProfile: @escaping SaveProfile,
        didSave: @escaping (String) -> Void
    ) {
        self.editor = editor
        self.saveProfile = saveProfile
        self.didSave = didSave

        let profile: Profile? = if case let .edit(profile) = editor {
            profile
        } else {
            nil
        }
        _title = State(initialValue: profile?.title ?? "")
        _executable = State(initialValue: profile?.executable ?? "")
        _arguments = State(initialValue: profile?.arguments.joined(separator: "\n") ?? "")
        _targetKind = State(initialValue: profile?.targetKind ?? .filesAndFolders)
        _preserveSessionAfterCommand = State(
            initialValue: profile?.preserveSessionAfterCommand ?? true
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("profile.field.menu_title", text: $title)
                    TextField("profile.field.executable", text: $executable)
                } header: {
                    Label(
                        "profile_editor.section.general",
                        systemImage: "slider.horizontal.3"
                    )
                }

                Section {
                    HStack(spacing: 28) {
                        Toggle(
                            "profile.target.files",
                            isOn: acceptsFiles
                        )
                        Toggle(
                            "profile.target.folders",
                            isOn: acceptsFolders
                        )
                    }
                    .toggleStyle(.checkbox)
                } header: {
                    Label(
                        "profile_editor.section.availability",
                        systemImage: "cursorarrow.click.2"
                    )
                } footer: {
                    Text("profile_editor.availability.help")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("profile.field.arguments")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $arguments)
                                .font(.body.monospaced())
                                .scrollContentBackground(.hidden)
                                .padding(8)

                            if arguments.isEmpty {
                                Text("profile.field.arguments_placeholder")
                                    .font(.body.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(
                            minHeight: 72,
                            idealHeight: 88,
                            maxHeight: 160
                        )
                        .background(
                            .background,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.separator, lineWidth: 1)
                        }
                    }
                } header: {
                    Label(
                        "profile_editor.section.command",
                        systemImage: "terminal"
                    )
                } footer: {
                    Text("profile_editor.arguments.help")
                }

                Section {
                    Toggle(
                        "profile.field.keep_session_open_after_exit",
                        isOn: $preserveSessionAfterCommand
                    )
                } header: {
                    Label(
                        "profile_editor.section.terminal",
                        systemImage: "macwindow.and.cursorarrow"
                    )
                }

                if let validationMessage {
                    Section {
                        Label {
                            Text(validationMessage)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(editorTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        save()
                    }
                }
            }
        }
        .frame(
            minWidth: 520,
            idealWidth: 560,
            maxWidth: 680,
            minHeight: 480,
            idealHeight: 540,
            maxHeight: 720
        )
        .presentationSizing(.fitted)
    }

    private var isNew: Bool {
        if case .new = editor {
            return true
        }
        return false
    }

    private var editorTitle: Text {
        if isNew {
            Text("profile_editor.new.title")
        } else {
            Text("profile_editor.edit.title")
        }
    }

    private var acceptsFiles: Binding<Bool> {
        Binding(
            get: {
                targetKind != .folders
            },
            set: { isAccepted in
                if isAccepted {
                    if targetKind == .folders {
                        targetKind = .filesAndFolders
                    }
                } else {
                    targetKind = .folders
                }
            }
        )
    }

    private var acceptsFolders: Binding<Bool> {
        Binding(
            get: {
                targetKind != .files
            },
            set: { isAccepted in
                if isAccepted {
                    if targetKind == .files {
                        targetKind = .filesAndFolders
                    }
                } else {
                    targetKind = .files
                }
            }
        )
    }

    private var parsedArguments: [String] {
        arguments
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        do {
            let savedID = try saveProfile(
                editor,
                title,
                executable,
                parsedArguments,
                targetKind,
                preserveSessionAfterCommand
            )
            didSave(savedID)
        } catch {
            validationMessage = error.localizedDescription
        }
    }

}

#if DEBUG
#Preview("New Finder Action") {
    ProfileEditorView(
        editor: .new,
        saveProfile: { _, _, _, _, _, _ in "preview-profile" },
        didSave: { _ in }
    )
}

#Preview("Edit Finder Action") {
    ProfileEditorView(
        editor: .edit(ProfilePreviewData.vim),
        saveProfile: { editor, _, _, _, _, _ in editor.id },
        didSave: { _ in }
    )
}

#Preview("Command Template") {
    ProfileEditorView(
        editor: .edit(ProfilePreviewData.environmentVim),
        saveProfile: { editor, _, _, _, _, _ in editor.id },
        didSave: { _ in }
    )
}
#endif
