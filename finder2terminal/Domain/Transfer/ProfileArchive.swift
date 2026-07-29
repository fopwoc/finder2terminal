import Foundation

nonisolated struct ProfileArchive: Codable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let profile: Profile

    init(profile: Profile) {
        formatVersion = Self.currentFormatVersion
        self.profile = profile
    }

    func validateFormat() throws {
        guard formatVersion == Self.currentFormatVersion else {
            throw ProfileArchiveError.unsupportedFormat
        }
    }
}

enum ProfileArchiveError: LocalizedError {
    case unsupportedFormat
    case invalidProfileID

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            String(localized: "errors.archive.unsupported_format")
        case .invalidProfileID:
            String(localized: "errors.archive.invalid_profile_id")
        }
    }
}
