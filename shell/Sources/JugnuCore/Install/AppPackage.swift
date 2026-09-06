import Foundation

public enum AppPackage {
    public static func findAppBundle(in extractRoot: URL) throws -> URL {
        let fm = FileManager.default
        let direct = extractRoot.appendingPathComponent("Jugnu.app")
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: direct.path, isDirectory: &isDir), isDir.boolValue {
            return direct
        }

        let children = try fm.contentsOfDirectory(
            at: extractRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var matches: [URL] = []
        for child in children {
            var childDir: ObjCBool = false
            guard fm.fileExists(atPath: child.path, isDirectory: &childDir), childDir.boolValue else { continue }
            let nested = child.appendingPathComponent("Jugnu.app")
            var nestedDir: ObjCBool = false
            if fm.fileExists(atPath: nested.path, isDirectory: &nestedDir), nestedDir.boolValue {
                matches.append(nested)
            }
        }
        guard matches.count == 1, let only = matches.first else {
            throw AppUpdateError.bundleIdentity
        }
        return only
    }

    public static func check(
        bundle: URL,
        expectedVersion: String,
        expectedBundleId: String = "app.jugnu.shell"
    ) throws {
        let infoURL = bundle.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            throw AppUpdateError.bundleIdentity
        }
        guard let identifier = plist["CFBundleIdentifier"] as? String, identifier == expectedBundleId else {
            throw AppUpdateError.bundleIdentity
        }
        if let packageType = plist["CFBundlePackageType"] as? String, packageType != "APPL" {
            throw AppUpdateError.bundleIdentity
        }
        let actual = (plist["CFBundleShortVersionString"] as? String) ?? ""
        guard actual == expectedVersion else {
            throw AppUpdateError.versionMismatch(expected: expectedVersion, actual: actual)
        }
        let executableName = (plist["CFBundleExecutable"] as? String) ?? "Jugnu"
        let execURL = bundle.appendingPathComponent("Contents/MacOS").appendingPathComponent(executableName)
        try PackageGates.checkEntrypoint(kind: "exec", fileURL: execURL)
    }
}
