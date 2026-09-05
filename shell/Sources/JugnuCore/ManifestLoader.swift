import Foundation
import Yams

public enum ManifestLoader {
    public static func load(from addonRoot: URL) throws -> AddonManifest {
        let file = addonRoot.appendingPathComponent("addon.yaml")
        let data = try Data(contentsOf: file)
        guard let yaml = String(data: data, encoding: .utf8) else {
            throw ManifestLoaderError.invalidEncoding
        }
        let manifest: AddonManifest
        do {
            manifest = try YAMLDecoder().decode(AddonManifest.self, from: yaml)
        } catch {
            throw unwrapManifestError(error)
        }
        if manifest.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ManifestLoaderError.emptyId
        }
        try PackageGates.validateAddonId(manifest.id)
        if let min = manifest.minShellVersion, !PackageGates.isValidSemVer(min) {
            throw ManifestLoaderError.invalidMinShellVersion(min)
        }
        if manifest.api != 1 {
            throw ManifestLoaderError.unsupportedAPI(manifest.api)
        }
        for dep in manifest.dependencies {
            if !PackageGates.isValidSemVer(dep.version) {
                throw ManifestLoaderError.invalidDependencyVersion(dep.id, dep.version)
            }
        }
        try manifest.validateViewTypes()
        for command in manifest.commands
            where manifest.effectiveLifecycle(commandId: command.id) == .daemon
        {
            if !FirstPartyDaemons.ids.contains(manifest.id) {
                throw ManifestLoaderError.daemonNotFirstParty(manifest.id)
            }
            if command.daemon == nil {
                throw ManifestLoaderError.daemonBlockMissing(command: command.id)
            }
        }
        return manifest
    }

    public static func loadHelper(from helperRoot: URL) throws -> HelperManifest {
        let file = helperRoot.appendingPathComponent("helper.yaml")
        let data = try Data(contentsOf: file)
        guard let yaml = String(data: data, encoding: .utf8) else {
            throw ManifestLoaderError.invalidEncoding
        }
        return try YAMLDecoder().decode(HelperManifest.self, from: yaml)
    }
}

private func unwrapManifestError(_ error: Error) -> Error {
    if let loader = error as? ManifestLoaderError {
        return loader
    }
    guard let decoding = error as? DecodingError else { return error }
    switch decoding {
    case let .dataCorrupted(ctx), let .keyNotFound(_, ctx), let .typeMismatch(_, ctx), let .valueNotFound(_, ctx):
        if let loader = ctx.underlyingError as? ManifestLoaderError {
            return loader
        }
    @unknown default:
        break
    }
    return error
}

public enum ManifestLoaderError: Error, Equatable {
    case invalidEncoding
    case emptyId
    case invalidId(String)
    case reservedId(String)
    case invalidMinShellVersion(String)
    case invalidDependencyVersion(String, String)
    case unsupportedAPI(Int)
    case unknownViewType(String)
    case commandViewNotAllowed(command: String, view: String)
    case sessionNotSupported
    case unknownLifecycleClass(String)
    case daemonBlockMissing(command: String)
    case daemonNotFirstParty(String)
}
