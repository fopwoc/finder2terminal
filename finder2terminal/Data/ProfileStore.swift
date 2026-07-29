import Combine
import Foundation

final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [Profile] = []
    @Published var errorMessage: String?
    @Published var isPurgeConfirmationPresented = false

    private let defaults: UserDefaults
    private let registrar: WorkflowRegistrar
    private let scriptManager: TemporaryScriptManager
    private let configurationURL: URL
    private var hasStoredConfiguration = false
    private var migratedLegacyDefault = false

    init(
        defaults: UserDefaults = .standard,
        registrar: WorkflowRegistrar = WorkflowRegistrar(),
        scriptManager: TemporaryScriptManager = TemporaryScriptManager(),
        configurationURL: URL? = nil
    ) {
        self.defaults = defaults
        self.registrar = registrar
        self.scriptManager = scriptManager
        self.configurationURL = configurationURL ?? Self.defaultConfigurationURL
        load()
    }

    func bootstrap() {
        do {
            if !hasStoredConfiguration {
                let initialProfiles = profiles.isEmpty ? [.defaultVim] : profiles
                try persist(initialProfiles)
                profiles = initialProfiles
                try scriptManager.removeLegacyDefaultScript()
            } else if migratedLegacyDefault {
                try persist(profiles)
                try scriptManager.removeLegacyDefaultScript()
                migratedLegacyDefault = false
            }

            for profile in profiles {
                try registrar.register(profile)
            }
            try registrar.removeOrphans(keeping: profiles)
            try scriptManager.removeOrphanScripts(keeping: profiles)
            errorMessage = nil
        } catch {
            let format = String(localized: "errors.data.initialize_format")
            errorMessage = String.localizedStringWithFormat(
                format,
                error.localizedDescription
            )
        }
    }

    func profile(id: String) -> Profile? {
        profiles.first { $0.id == id }
    }

    func add(
        title: String,
        executable: String,
        arguments: [String],
        targetKind: ProfileTargetKind,
        preserveSessionAfterCommand: Bool
    ) throws -> Profile {
        try validate(
            title: title,
            executable: executable,
            arguments: arguments
        )
        let profile = Profile(
            id: UUID().uuidString.lowercased(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            executable: executable.trimmingCharacters(in: .whitespacesAndNewlines),
            arguments: arguments,
            targetKind: targetKind,
            preserveSessionAfterCommand: preserveSessionAfterCommand
        )
        try registrar.register(profile)

        let updatedProfiles = profiles + [profile]
        do {
            try persist(updatedProfiles)
        } catch {
            try? registrar.remove(profile)
            throw error
        }
        profiles = updatedProfiles
        errorMessage = nil
        return profile
    }

    func update(
        id: String,
        title: String,
        executable: String,
        arguments: [String],
        targetKind: ProfileTargetKind,
        preserveSessionAfterCommand: Bool
    ) throws {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            return
        }
        try validate(
            title: title,
            executable: executable,
            arguments: arguments,
            excluding: id
        )

        let oldProfile = profiles[index]
        let profile = Profile(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            executable: executable.trimmingCharacters(in: .whitespacesAndNewlines),
            arguments: arguments,
            targetKind: targetKind,
            preserveSessionAfterCommand: preserveSessionAfterCommand
        )
        try registrar.register(profile, replacing: oldProfile)

        var updatedProfiles = profiles
        updatedProfiles[index] = profile
        do {
            try persist(updatedProfiles)
        } catch {
            try? registrar.register(oldProfile, replacing: profile)
            throw error
        }
        profiles = updatedProfiles
        errorMessage = nil
    }

    func importProfile(_ importedProfile: Profile) throws {
        let importPlan = try ProfileImportPlan(
            existingProfiles: profiles,
            importedProfile: importedProfile
        )
        try validate(importPlan.profiles)

        do {
            try registrar.register(
                importPlan.change.newProfile,
                replacing: importPlan.change.oldProfile
            )
            try persist(importPlan.profiles)
        } catch {
            rollback(importPlan.change)
            throw error
        }

        profiles = importPlan.profiles
        errorMessage = nil
    }

    func remove(id: String) throws {
        guard let profile = profile(id: id) else {
            return
        }
        let updatedProfiles = profiles.filter { $0.id != id }
        do {
            try registrar.remove(profile)
            try scriptManager.removeScripts(for: profile)
            try persist(updatedProfiles)
        } catch {
            try? registrar.register(profile)
            throw error
        }
        profiles = updatedProfiles
        errorMessage = nil
    }

    func purgeAll() throws {
        try registrar.removeAll(profiles)
        try scriptManager.removeAllScripts(for: profiles)

        let configurationDirectory = configurationURL.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: configurationDirectory.path) {
            try FileManager.default.removeItem(at: configurationDirectory)
        }
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
        }
        defaults.synchronize()

        profiles = []
        hasStoredConfiguration = false
        migratedLegacyDefault = false
        errorMessage = nil
    }

    private func validate(
        title: String,
        executable: String,
        arguments: [String],
        excluding id: String? = nil
    ) throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw ProfileError.emptyTitle
        }
        guard !executable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProfileError.emptyExecutable
        }
        try CommandTemplate.validate(arguments)
        if profiles.contains(where: {
            $0.id != id && $0.title.caseInsensitiveCompare(normalizedTitle) == .orderedSame
        }) {
            throw ProfileError.duplicateTitle
        }
    }

    private func validate(_ profiles: [Profile]) throws {
        var normalizedTitles = Set<String>()
        for profile in profiles {
            let title = profile.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                throw ProfileError.emptyTitle
            }
            guard !profile.executable.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty else {
                throw ProfileError.emptyExecutable
            }
            guard normalizedTitles.insert(title.lowercased()).inserted else {
                throw ProfileError.duplicateTitle
            }
            try CommandTemplate.validate(profile.arguments)
        }
    }

    private func rollback(_ change: ProfileImportChange) {
        if let oldProfile = change.oldProfile {
            try? registrar.register(
                oldProfile,
                replacing: change.newProfile
            )
        } else {
            try? registrar.remove(change.newProfile)
        }
    }

    private func load() {
        if FileManager.default.fileExists(atPath: configurationURL.path) {
            hasStoredConfiguration = true
            guard
                let data = try? Data(contentsOf: configurationURL),
                let decoded = try? JSONDecoder().decode([Profile].self, from: data)
            else {
                errorMessage = String(
                    localized: "errors.data.configuration_unreadable"
                )
                return
            }
            profiles = migrateLegacyDefault(in: decoded)
            return
        }

        guard
            let legacyData = defaults.data(forKey: "profiles"),
            let decoded = try? JSONDecoder().decode([Profile].self, from: legacyData)
        else {
            return
        }
        profiles = migrateLegacyDefault(in: decoded)
    }

    private func migrateLegacyDefault(in profiles: [Profile]) -> [Profile] {
        profiles.map { profile in
            guard profile.id == "open-in-vim" else {
                return profile
            }
            migratedLegacyDefault = true
            return Profile(
                id: UUID().uuidString.lowercased(),
                title: profile.title,
                executable: profile.executable,
                arguments: profile.arguments,
                targetKind: profile.targetKind,
                preserveSessionAfterCommand: true
            )
        }
    }

    private func persist(_ profiles: [Profile]) throws {
        let directoryURL = configurationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(profiles)
        try data.write(to: configurationURL, options: .atomic)
        hasStoredConfiguration = true

        defaults.removeObject(forKey: "profiles")
        defaults.removeObject(forKey: "profilesInitialized")
        defaults.synchronize()
    }

    private static var defaultConfigurationURL: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("f2t", isDirectory: true)
        .appendingPathComponent("profiles.json")
    }
}
