import Foundation

public enum UserFacingError {
    public static let catalogUnreachable = "Couldn’t reach the catalog. Check your connection and try again."
    public static let catalogInvalid = "The catalog couldn’t be read. Try again later."
    public static let catalogCachedUnreachable = "Showing cached results — offline or registry unreachable"
    public static let catalogCachedInvalid = "Showing cached results — the catalog update couldn’t be read."

    public static func cachedCatalogMessage(for failure: RegistryFetchFailure) -> String {
        switch failure {
        case .unreachable: catalogCachedUnreachable
        case .invalid: catalogCachedInvalid
        }
    }

    public static func message(for error: Error) -> String {
        if let loader = error as? ManifestLoaderError {
            switch loader {
            case .emptyId:
                return "This addon is missing its name. Try reinstalling it."
            case .invalidEncoding:
                return "This addon’s description couldn’t be read. Try reinstalling it."
            case .unsupportedAPI:
                return "This addon needs a newer Jugnu."
            case .unknownViewType, .commandViewNotAllowed:
                return "This addon’s description couldn’t be read. Try reinstalling it."
            case .sessionNotSupported:
                return "This addon needs a newer version of Jugnu (session addons are not yet supported)."
            case .unknownLifecycleClass:
                return "This addon’s description couldn’t be read. Try reinstalling it."
            case .daemonBlockMissing:
                return "This addon’s description couldn’t be read. Try reinstalling it."
            case .daemonNotFirstParty:
                return "This addon’s description couldn’t be read. Try reinstalling it."
            }
        }
        if let view = error as? ViewTypeError {
            switch view {
            case .notAllowed:
                return "This addon asked for a view the shell doesn’t allow."
            case .unknown:
                return "The addon didn’t return a result we could use."
            }
        }
        if let job = error as? JobInvokeError {
            switch job {
            case .reuse:
                return ""
            case .stillStopping:
                return JobProgressCopy.stillStopping
            }
        }
        if let runner = error as? AddonRunnerError {
            switch runner {
            case .timeout:
                return "That took too long. Try again."
            case .invalidResponse:
                return "The addon didn’t return a result we could use."
            case .unsupportedEntrypointKind:
                return "This addon can’t run on this Mac."
            case .helperMissing:
                return "This addon is missing a helper. Try reinstalling it."
            case .jobHandshakeTimeout:
                return "The addon didn't start in time."
            case .jobUnresponsive:
                return "The addon stopped responding."
            }
        }
        if let installer = error as? AddonInstallerError {
            switch installer {
            case .sha256Mismatch:
                return "The download didn’t match what we expected. Nothing was installed."
            case .missingURL:
                return "No download location is listed for this addon."
            case .helperUnreachable:
                return "Couldn’t download the helper. Check your connection and try again."
            case .helperNotInCatalog:
                return "This addon needs a helper that isn’t in the catalog."
            case .idMismatch, .addonYAMLMissing, .unzipFailed, .helperYAMLMissing, .helperManifestMismatch:
                return "Something went wrong. Try again."
            }
        }
        if let failure = error as? RegistryFetchFailure {
            switch failure {
            case .unreachable: return catalogUnreachable
            case .invalid: return catalogInvalid
            }
        }
        if let registry = error as? RegistryClientError {
            switch registry {
            case .httpStatus:
                return catalogUnreachable
            case .invalidCatalog:
                return catalogInvalid
            }
        }
        return "Something went wrong. Try again."
    }
}
