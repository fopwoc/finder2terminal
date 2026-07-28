import Foundation

struct TemporaryScriptManager {
    private let fileManager = FileManager.default

    func scriptURL(for profile: Profile) -> URL {
        fileManager.temporaryDirectory.appendingPathComponent(profile.scriptFilename)
    }

    func removeScripts(for profile: Profile) throws {
        try removeIfPresent(scriptURL(for: profile))
        try removeIfPresent(
            fileManager.temporaryDirectory.appendingPathComponent(
                profile.legacyScriptFilename
            )
        )
    }

    func removeLegacyDefaultScript() throws {
        try removeIfPresent(
            fileManager.temporaryDirectory.appendingPathComponent(
                "open-in-vim.command"
            )
        )
    }

    func removeAllScripts(for profiles: [Profile]) throws {
        for profile in profiles {
            try removeScripts(for: profile)
        }
        try removeLegacyDefaultScript()

        let temporaryItems = try fileManager.contentsOfDirectory(
            at: fileManager.temporaryDirectory,
            includingPropertiesForKeys: nil
        )
        for url in temporaryItems where
            url.lastPathComponent.hasPrefix("f2t-")
                && url.pathExtension == "command"
        {
            try removeIfPresent(url)
        }
    }

    func removeOrphanScripts(keeping profiles: [Profile]) throws {
        let expectedFilenames = Set(profiles.map(\.scriptFilename))
        let temporaryItems = try fileManager.contentsOfDirectory(
            at: fileManager.temporaryDirectory,
            includingPropertiesForKeys: nil
        )
        for url in temporaryItems where
            url.lastPathComponent.hasPrefix("f2t-")
                && url.pathExtension == "command"
                && !expectedFilenames.contains(url.lastPathComponent)
        {
            try removeIfPresent(url)
        }
    }

    private func removeIfPresent(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
