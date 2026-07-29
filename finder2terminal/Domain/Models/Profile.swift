import Foundation

nonisolated struct Profile: Codable, Hashable, Identifiable {
    static var defaultVim: Profile {
        Profile(
            id: UUID().uuidString.lowercased(),
            title: String(localized: "profile.default.vim_title"),
            executable: "/usr/bin/vim",
            arguments: [],
            targetKind: .filesAndFolders,
            preserveSessionAfterCommand: true
        )
    }

    let id: String
    var title: String
    var executable: String
    var arguments: [String]
    var targetKind: ProfileTargetKind
    var preserveSessionAfterCommand: Bool

    init(
        id: String,
        title: String,
        executable: String,
        arguments: [String],
        targetKind: ProfileTargetKind = .filesAndFolders,
        preserveSessionAfterCommand: Bool
    ) {
        self.id = id
        self.title = title
        self.executable = executable
        self.arguments = arguments
        self.targetKind = targetKind
        self.preserveSessionAfterCommand = preserveSessionAfterCommand
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        executable = try container.decode(String.self, forKey: .executable)
        arguments = try container.decode([String].self, forKey: .arguments)
        targetKind = try container.decodeIfPresent(
            ProfileTargetKind.self,
            forKey: .targetKind
        ) ?? .filesAndFolders
        preserveSessionAfterCommand = try container.decodeIfPresent(
            Bool.self,
            forKey: .preserveSessionAfterCommand
        ) ?? false
    }

    var scriptFilename: String {
        "f2t-\(id.filenameComponent).command"
    }

    var legacyScriptFilename: String {
        "\(id.filenameComponent).command"
    }

    var workflowFilename: String {
        "\(title.filenameComponent).workflow"
    }
}

private extension String {
    var filenameComponent: String {
        let invalid = CharacterSet(charactersIn: "/:")
            .union(.controlCharacters)
        let sanitized = components(separatedBy: invalid)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "f2t-action" : sanitized
    }
}
