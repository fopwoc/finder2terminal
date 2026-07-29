import SwiftUI

struct ProfileDetailView: View {
    let profile: Profile
    let edit: () -> Void

    var body: some View {
        Form {
            LabeledContent("profile.field.menu_title", value: profile.title)
            LabeledContent("profile.field.executable", value: profile.executable)
            LabeledContent("profile.field.accepts", value: targetKindDescription)
            LabeledContent("profile.field.arguments") {
                Text(argumentsDescription)
            }
            LabeledContent(
                "profile.field.keep_session_open",
                value: sessionPersistenceDescription
            )
        }
        .formStyle(.grouped)
        //.navigationTitle(profile.title)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("common.edit", action: edit)
            }
        }
    }

    private var argumentsDescription: String {
        if profile.arguments.isEmpty {
            String(localized: "profile.value.none")
        } else {
            profile.arguments.joined(separator: " ")
        }
    }

    private var targetKindDescription: String {
        switch profile.targetKind {
        case .files:
            String(localized: "profile.target.files")
        case .folders:
            String(localized: "profile.target.folders")
        case .filesAndFolders:
            String(localized: "profile.target.files_and_folders")
        }
    }

    private var sessionPersistenceDescription: String {
        if profile.preserveSessionAfterCommand {
            String(localized: "profile.value.on")
        } else {
            String(localized: "profile.value.off")
        }
    }
}

#if DEBUG
#Preview("Profile Detail") {
    NavigationStack {
        ProfileDetailView(
            profile: ProfilePreviewData.vim,
            edit: {}
        )
    }
    .frame(width: 500, height: 400)
}
#endif
