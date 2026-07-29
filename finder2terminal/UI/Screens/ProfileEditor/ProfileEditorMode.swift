import Foundation

enum ProfileEditorMode: Identifiable {
    case new
    case edit(Profile)

    var id: String {
        switch self {
        case .new:
            "new"
        case let .edit(profile):
            profile.id
        }
    }
}
