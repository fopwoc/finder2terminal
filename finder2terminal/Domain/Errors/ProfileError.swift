import Foundation

enum ProfileError: LocalizedError {
    case emptyTitle
    case emptyExecutable
    case duplicateTitle

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            String(localized: "errors.profile.empty_title")
        case .emptyExecutable:
            String(localized: "errors.profile.empty_executable")
        case .duplicateTitle:
            String(localized: "errors.profile.duplicate_title")
        }
    }
}
