#if DEBUG
enum ProfilePreviewData {
    static let vim = Profile(
        id: "preview-vim",
        title: "Open in Vim",
        executable: "/usr/bin/vim",
        arguments: [],
        preserveSessionAfterCommand: true
    )

    static let code = Profile(
        id: "preview-code",
        title: "Open in Visual Studio Code",
        executable: "/usr/local/bin/code",
        arguments: ["--reuse-window"],
        targetKind: .folders,
        preserveSessionAfterCommand: false
    )

    static let environmentVim = Profile(
        id: "preview-environment-vim",
        title: "Open in Vim with Environment",
        executable: "/usr/bin/vim",
        arguments: [
            "/usr/bin/env",
            "VIM_MODE=shared",
            "{executable}",
            "{targets}",
        ],
        targetKind: .files,
        preserveSessionAfterCommand: true
    )

    static let profiles = [vim, code]
}
#endif
