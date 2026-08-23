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
        if manifest.api != 1 {
            throw ManifestLoaderError.unsupportedAPI(manifest.api)
        }
        try manifest.validateViewTypes()
        return manifest
    }
}

private func unwrapManifestError(_ error: Error) -> Error {
    if let loader = error as? ManifestLoaderError { return loader }
    guard let decoding = error as? DecodingError else { return error }
    switch decoding {
    case .dataCorrupted(let ctx), .keyNotFound(_, let ctx), .typeMismatch(_, let ctx), .valueNotFound(_, let ctx):
        if let loader = ctx.underlyingError as? ManifestLoaderError { return loader }
    @unknown default:
        break
    }
    return error
}

public enum ManifestLoaderError: Error, Equatable {
    case invalidEncoding
    case emptyId
    case unsupportedAPI(Int)
    case unknownViewType(String)
    case commandViewNotAllowed(command: String, view: String)
}
