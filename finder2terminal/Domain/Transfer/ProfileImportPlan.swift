import Foundation

struct ProfileImportPlan {
    let profiles: [Profile]
    let change: ProfileImportChange

    init(existingProfiles: [Profile], importedProfile: Profile) throws {
        var mergedProfiles = existingProfiles

        guard UUID(uuidString: importedProfile.id) != nil else {
            throw ProfileArchiveError.invalidProfileID
        }

        let normalizedID = importedProfile.id.lowercased()
        let normalizedProfile = Profile(
            id: normalizedID,
            title: importedProfile.title.trimmingCharacters(in: .whitespacesAndNewlines),
            executable: importedProfile.executable.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            arguments: importedProfile.arguments,
            targetKind: importedProfile.targetKind,
            preserveSessionAfterCommand: importedProfile.preserveSessionAfterCommand
        )

        let oldProfile: Profile?
        if let index = mergedProfiles.firstIndex(where: {
            $0.id.caseInsensitiveCompare(normalizedID) == .orderedSame
        }) {
            oldProfile = mergedProfiles[index]
            mergedProfiles[index] = normalizedProfile
        } else {
            oldProfile = nil
            mergedProfiles.append(normalizedProfile)
        }

        profiles = mergedProfiles
        change = ProfileImportChange(
            oldProfile: oldProfile,
            newProfile: normalizedProfile
        )
    }
}

struct ProfileImportChange {
    let oldProfile: Profile?
    let newProfile: Profile
}
