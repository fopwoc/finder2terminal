import AppKit
import Foundation

struct WorkflowRegistrar {
    private let fileManager = FileManager.default

    private var servicesDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services", isDirectory: true)
    }

    func register(_ profile: Profile, replacing oldProfile: Profile? = nil) throws {
        try fileManager.createDirectory(
            at: servicesDirectory,
            withIntermediateDirectories: true
        )

        let workflowURL = servicesDirectory
            .appendingPathComponent(profile.workflowFilename, isDirectory: true)
        let contentsURL = workflowURL.appendingPathComponent("Contents", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        try fileManager.createDirectory(
            at: resourcesURL,
            withIntermediateDirectories: true
        )

        try propertyListData(workflowDocument(for: profile)).write(
            to: resourcesURL.appendingPathComponent("document.wflow"),
            options: .atomic
        )
        try propertyListData(bundleInformation(for: profile)).write(
            to: contentsURL.appendingPathComponent("Info.plist"),
            options: .atomic
        )

        let legacyDocumentURL = contentsURL.appendingPathComponent("document.wflow")
        if fileManager.fileExists(atPath: legacyDocumentURL.path) {
            try fileManager.removeItem(at: legacyDocumentURL)
        }
        if let oldProfile, oldProfile.workflowFilename != profile.workflowFilename {
            try remove(oldProfile, refreshServices: false)
        }
        NSUpdateDynamicServices()
    }

    func remove(_ profile: Profile) throws {
        try remove(profile, refreshServices: true)
    }

    func removeAll(_ profiles: [Profile]) throws {
        var workflowURLs = Set(
            profiles.map {
                servicesDirectory.appendingPathComponent(
                    $0.workflowFilename,
                    isDirectory: true
                )
            }
        )

        if fileManager.fileExists(atPath: servicesDirectory.path) {
            let serviceItems = try fileManager.contentsOfDirectory(
                at: servicesDirectory,
                includingPropertiesForKeys: nil
            )
            for url in serviceItems where url.pathExtension == "workflow" {
                let informationURL = url
                    .appendingPathComponent("Contents", isDirectory: true)
                    .appendingPathComponent("Info.plist")
                guard
                    let data = try? Data(contentsOf: informationURL),
                    let information = try? PropertyListSerialization.propertyList(
                        from: data,
                        format: nil
                    ) as? [String: Any],
                    let identifier = information["CFBundleIdentifier"] as? String,
                    identifier.hasPrefix("dev.fopwoc.finder2terminal.workflow.")
                else {
                    continue
                }
                workflowURLs.insert(url)
            }
        }

        for url in workflowURLs where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        NSUpdateDynamicServices()
    }

    func removeOrphans(keeping profiles: [Profile]) throws {
        guard fileManager.fileExists(atPath: servicesDirectory.path) else {
            return
        }

        let expectedURLs = Set(
            profiles.map {
                servicesDirectory.appendingPathComponent(
                    $0.workflowFilename,
                    isDirectory: true
                )
            }
        )
        var removedWorkflow = false
        let serviceItems = try fileManager.contentsOfDirectory(
            at: servicesDirectory,
            includingPropertiesForKeys: nil
        )
        for url in serviceItems where
            url.pathExtension == "workflow"
                && !expectedURLs.contains(url)
                && isF2TWorkflow(url)
        {
            try fileManager.removeItem(at: url)
            removedWorkflow = true
        }
        if removedWorkflow {
            NSUpdateDynamicServices()
        }
    }

    private func remove(_ profile: Profile, refreshServices: Bool) throws {
        let url = servicesDirectory.appendingPathComponent(
            profile.workflowFilename,
            isDirectory: true
        )
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        if refreshServices {
            NSUpdateDynamicServices()
        }
    }

    private func isF2TWorkflow(_ url: URL) -> Bool {
        let informationURL = url
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard
            let data = try? Data(contentsOf: informationURL),
            let information = try? PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any],
            let identifier = information["CFBundleIdentifier"] as? String
        else {
            return false
        }
        return identifier.hasPrefix("dev.fopwoc.finder2terminal.workflow.")
    }

    private func propertyListData(_ propertyList: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
    }

    private func bundleInformation(for profile: Profile) -> [String: Any] {
        [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleIdentifier": "dev.fopwoc.finder2terminal.workflow.\(profile.id)",
            "CFBundleName": profile.title,
            "CFBundleShortVersionString": "1.0",
            "NSServices": [
                [
                    "NSMenuItem": [
                        "default": profile.title,
                    ],
                    "NSMessage": "runWorkflowAsService",
                    "NSRequiredContext": [
                        "NSApplicationIdentifier": "com.apple.finder",
                    ],
                    "NSSendFileTypes": [
                        "public.item",
                        "public.folder",
                    ],
                ],
            ],
        ]
    }

    private func workflowDocument(for profile: Profile) -> [String: Any] {
        let executablePath = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
        let command = [
            "exec",
            executablePath.shellQuoted,
            "--run-profile",
            profile.id.shellQuoted,
            "--",
            "\"$@\"",
        ].joined(separator: " ")

        let action: [String: Any] = [
            "AMAccepts": [
                "Container": "List",
                "Optional": 0,
                "Types": ["com.apple.cocoa.path"],
            ],
            "AMActionVersion": "2.0.3",
            "AMApplication": ["Automator"],
            "AMParameterProperties": [
                "CheckedForUserDefaultShell": [:],
                "COMMAND_STRING": [:],
                "inputMethod": [:],
                "shell": [:],
                "source": [:],
            ],
            "AMProvides": [
                "Container": "List",
                "Types": ["com.apple.cocoa.string"],
            ],
            "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
            "ActionName": "Run Shell Script",
            "ActionParameters": [
                "COMMAND_STRING": command,
                "CheckedForUserDefaultShell": 1,
                "inputMethod": 1,
                "shell": "/bin/zsh",
                "source": "",
            ],
            "arguments": [
                "0": [
                    "default value": 0,
                    "name": "inputMethod",
                    "required": "0",
                    "type": "0",
                    "uuid": "0",
                ],
                "1": [
                    "default value": "",
                    "name": "source",
                    "required": "0",
                    "type": "0",
                    "uuid": "1",
                ],
                "2": [
                    "default value": false,
                    "name": "CheckedForUserDefaultShell",
                    "required": "0",
                    "type": "0",
                    "uuid": "2",
                ],
                "3": [
                    "default value": "",
                    "name": "COMMAND_STRING",
                    "required": "0",
                    "type": "0",
                    "uuid": "3",
                ],
                "4": [
                    "default value": "/bin/sh",
                    "name": "shell",
                    "required": "0",
                    "type": "0",
                    "uuid": "4",
                ],
            ],
            "BundleIdentifier": "com.apple.RunShellScript",
            "CFBundleVersion": "2.0.3",
            "CanShowSelectedItemsWhenRun": false,
            "CanShowWhenRun": false,
            "Category": ["AMCategoryUtilities"],
            "Class Name": "RunShellScriptAction",
            "InputUUID": UUID().uuidString,
            "OutputUUID": UUID().uuidString,
            "UUID": UUID().uuidString,
        ]

        return [
            "AMApplicationBuild": "523",
            "AMApplicationVersion": "2.10",
            "AMDocumentVersion": "2",
            "actions": [
                [
                    "action": action,
                    "isViewVisible": true,
                ],
            ],
            "connectors": [:],
            "workflowMetaData": [
                "serviceApplicationBundleID": "com.apple.finder",
                "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
                "serviceApplicationPaths": [
                    "/System/Library/CoreServices/Finder.app",
                ],
                "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
                "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
                "serviceProcessesInput": 0,
                "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
            ],
        ]
    }
}

extension String {
    var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
