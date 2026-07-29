import Foundation

enum CommandTemplate {
    static let executableToken = "{executable}"
    static let targetsToken = "{targets}"

    static func resolve(
        executable: String,
        arguments: [String],
        targets: [String]
    ) throws -> [String] {
        try validate(arguments)

        var components: [String] = []
        let hasExecutableToken = arguments.contains(executableToken)
        let hasTargetsToken = arguments.contains(targetsToken)

        if !hasExecutableToken {
            components.append(executable)
        }

        for argument in arguments {
            switch argument {
            case executableToken:
                components.append(executable)
            case targetsToken:
                components.append(contentsOf: targets)
            default:
                components.append(argument)
            }
        }

        if !hasTargetsToken {
            components.append(contentsOf: targets)
        }
        return components
    }

    static func validate(_ arguments: [String]) throws {
        guard arguments.count(of: executableToken) <= 1 else {
            throw CommandTemplateError.duplicateExecutableToken
        }
        guard arguments.count(of: targetsToken) <= 1 else {
            throw CommandTemplateError.duplicateTargetsToken
        }
    }
}

enum CommandTemplateError: LocalizedError {
    case duplicateExecutableToken
    case duplicateTargetsToken

    var errorDescription: String? {
        switch self {
        case .duplicateExecutableToken:
            String(localized: "errors.template.duplicate_executable")
        case .duplicateTargetsToken:
            String(localized: "errors.template.duplicate_targets")
        }
    }
}

private extension Collection where Element: Equatable {
    func count(of element: Element) -> Int {
        reduce(into: 0) { count, candidate in
            if candidate == element {
                count += 1
            }
        }
    }
}
