import SwiftUI
import UniformTypeIdentifiers

struct ProfileArchiveDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var archive: ProfileArchive

    init(profile: Profile) {
        archive = ProfileArchive(profile: profile)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        archive = try JSONDecoder().decode(ProfileArchive.self, from: data)
        try archive.validateFormat()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return FileWrapper(regularFileWithContents: try encoder.encode(archive))
    }
}
