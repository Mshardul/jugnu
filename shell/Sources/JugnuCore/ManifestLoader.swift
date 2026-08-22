import Foundation
import Yams

public enum ManifestLoader {
    public static func load(from addonRoot: URL) throws -> AddonManifest {
        let file = addonRoot.appendingPathComponent("addon.yaml")
        let data = try Data(contentsOf: file)
        guard let yaml = String(data: data, encoding: .utf8) else {
            throw ManifestLoaderError.invalidEncoding
        }
        let manifest = try YAMLDecoder().decode(AddonManifest.self, from: yaml)
        if manifest.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ManifestLoaderError.emptyId
        }
        if manifest.api != 1 {
            throw ManifestLoaderError.unsupportedAPI(manifest.api)
        }
        return manifest
    }
}

public enum ManifestLoaderError: Error, Equatable {
    case invalidEncoding
    case emptyId
    case unsupportedAPI(Int)
}
