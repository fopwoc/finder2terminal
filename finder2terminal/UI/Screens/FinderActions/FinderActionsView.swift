import SwiftUI
import UniformTypeIdentifiers

struct FinderActionsView: View {
    @ObservedObject var store: ProfileStore
    @State private var selection: String?
    @State private var editor: ProfileEditorMode?
    @State private var isImportPresented = false
    @State private var isExportPresented = false
    @State private var exportDocument: ProfileArchiveDocument?
    @State private var exportFilename = "f2t-profile"

    var body: some View {
        FinderActionsScreen(
            profiles: store.profiles,
            selection: $selection,
            addProfile: {
                editor = .new
            },
            removeSelectedProfile: removeSelectedProfile,
            editProfile: { profile in
                editor = .edit(profile)
            },
            importProfile: {
                isImportPresented = true
            },
            exportProfile: prepareExport
        )
        .sheet(item: $editor) { editor in
            ProfileEditorView(
                editor: editor,
                saveProfile: saveProfile
            ) { savedID in
                selection = savedID
                self.editor = nil
            }
        }
        .fileImporter(
            isPresented: $isImportPresented,
            allowedContentTypes: [.json]
        ) { result in
            importProfile(from: result)
        }
        .fileExporter(
            isPresented: $isExportPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case let .failure(error) = result {
                presentTransferError(
                    key: "errors.archive.export_format",
                    error: error
                )
            }
        }
        .alert(
            "app.name",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("common.ok") {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert(
            "finder_actions.delete_confirmation.title",
            isPresented: $store.isPurgeConfirmationPresented
        ) {
            Button("common.cancel", role: .cancel) {}
            Button("common.delete_all", role: .destructive) {
                purgeAll()
            }
        } message: {
            Text("finder_actions.delete_confirmation.message")
        }
        .onAppear {
            selection = selection ?? store.profiles.first?.id
        }
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

    private func saveProfile(
        _ editor: ProfileEditorMode,
        _ title: String,
        _ executable: String,
        _ arguments: [String],
        _ targetKind: ProfileTargetKind,
        _ preserveSessionAfterCommand: Bool
    ) throws -> String {
        switch editor {
        case .new:
            return try store.add(
                title: title,
                executable: executable,
                arguments: arguments,
                targetKind: targetKind,
                preserveSessionAfterCommand: preserveSessionAfterCommand
            ).id
        case let .edit(profile):
            try store.update(
                id: profile.id,
                title: title,
                executable: executable,
                arguments: arguments,
                targetKind: targetKind,
                preserveSessionAfterCommand: preserveSessionAfterCommand
            )
            return profile.id
        }
    }

    private func purgeAll() {
        do {
            try store.purgeAll()
            selection = nil
        } catch {
            let format = String(localized: "errors.data.delete_format")
            store.errorMessage = String.localizedStringWithFormat(
                format,
                error.localizedDescription
            )
        }
    }

    private func prepareExport() {
        guard
            let selection,
            let profile = store.profile(id: selection)
        else {
            return
        }
        exportDocument = ProfileArchiveDocument(profile: profile)
        exportFilename = profile.title
        isExportPresented = true
    }

    private func importProfile(from result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let archive = try JSONDecoder().decode(ProfileArchive.self, from: data)
            try archive.validateFormat()
            try store.importProfile(archive.profile)
            selection = archive.profile.id.lowercased()
        } catch {
            presentTransferError(
                key: "errors.archive.import_format",
                error: error
            )
        }
    }

    private func presentTransferError(
        key: LocalizedStringResource,
        error: any Error
    ) {
        let format = String(localized: key)
        store.errorMessage = String.localizedStringWithFormat(
            format,
            error.localizedDescription
        )
    }
}

struct FinderActionsScreen: View {
    let profiles: [Profile]
    @Binding var selection: String?
    let addProfile: () -> Void
    let removeSelectedProfile: () -> Void
    let editProfile: (Profile) -> Void
    let importProfile: () -> Void
    let exportProfile: () -> Void

    var body: some View {
        NavigationSplitView {
            List(profiles, selection: $selection) { profile in
                Label(profile.title, systemImage: "terminal")
                    .tag(profile.id)
            }
            .navigationTitle("finder_actions.title")
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    ControlGroup {
                        Button(action: addProfile) {
                            Label(
                                "finder_actions.add.help",
                                systemImage: "plus"
                            )
                            .labelStyle(.iconOnly)
                        }
                        .help("finder_actions.add.help")

                        Button(
                            role: .destructive,
                            action: removeSelectedProfile
                        ) {
                            Label(
                                "finder_actions.delete.help",
                                systemImage: "trash"
                            )
                            .labelStyle(.iconOnly)
                        }
                        .help("finder_actions.delete.help")
                        .disabled(selection == nil)
                    }

                    Spacer()

                    ControlGroup {
                        Button(action: importProfile) {
                            Label(
                                "finder_actions.import.help",
                                systemImage: "square.and.arrow.down"
                            )
                            .labelStyle(.iconOnly)
                        }
                        .help("finder_actions.import.help")

                        Button(action: exportProfile) {
                            Label(
                                "finder_actions.export.help",
                                systemImage: "square.and.arrow.up"
                            )
                            .labelStyle(.iconOnly)
                        }
                        .help("finder_actions.export.help")
                        .disabled(selection == nil)
                    }
                }
                .controlSize(.regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationSplitViewColumnWidth(
                min: 230,
                ideal: 260,
                max: 340
            )
        } detail: {
            if let selectedProfile {
                ProfileDetailView(profile: selectedProfile) {
                    editProfile(selectedProfile)
                }
            } else {
                ContentUnavailableView(
                    "finder_actions.empty.title",
                    systemImage: "terminal",
                    description: Text("finder_actions.empty.description")
                )
            }
        }
        .frame(
            minWidth: 680,
            idealWidth: 900,
            maxWidth: 1_100,
            minHeight: 400,
            idealHeight: 600,
            maxHeight: .infinity
        )
        .windowFullScreenBehavior(.disabled)
    }

    private var selectedProfile: Profile? {
        guard let selection else {
            return nil
        }
        return profiles.first { $0.id == selection }
    }
}

#if DEBUG
#Preview("Finder Actions") {
    FinderActionsScreen(
        profiles: ProfilePreviewData.profiles,
        selection: .constant(ProfilePreviewData.vim.id),
        addProfile: {},
        removeSelectedProfile: {},
        editProfile: { _ in },
        importProfile: {},
        exportProfile: {}
    )
}

#Preview("Finder Actions few args") {
    FinderActionsScreen(
        profiles: ProfilePreviewData.profiles,
        selection: .constant(ProfilePreviewData.code.id),
        addProfile: {},
        removeSelectedProfile: {},
        editProfile: { _ in },
        importProfile: {},
        exportProfile: {}
    )
}

#Preview("Finder Actions many args") {
    FinderActionsScreen(
        profiles: [ProfilePreviewData.environmentVim],
        selection: .constant(ProfilePreviewData.environmentVim.id),
        addProfile: {},
        removeSelectedProfile: {},
        editProfile: { _ in },
        importProfile: {},
        exportProfile: {}
    )
}

#Preview("Finder Actions — Empty") {
    FinderActionsScreen(
        profiles: [],
        selection: .constant(nil),
        addProfile: {},
        removeSelectedProfile: {},
        editProfile: { _ in },
        importProfile: {},
        exportProfile: {}
    )
}
#endif
