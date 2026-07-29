nonisolated enum ProfileTargetKind: String, Codable, CaseIterable, Identifiable {
    case files
    case folders
    case filesAndFolders

    var id: Self {
        self
    }
}
