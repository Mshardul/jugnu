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
        let handlers: [(Error) -> String?] = [
            manifestLoaderMessage, addonConfigMessage, namespaceMigratorMessage, viewTypeMessage,
            jobInvokeMessage, addonRunnerMessage, addonInstallerMessage, registryFetchMessage,
            appUpdateMessage, registryClientMessage, tccGateMessage
        ]
        for handler in handlers {
            if let message = handler(error) {
                return message
            }
        }
        return "Something went wrong. Try again."
    }

    private static func manifestLoaderMessage(for error: Error) -> String? {
        guard let loader = error as? ManifestLoaderError else { return nil }
        switch loader {
        case .emptyId:
            return "This addon is missing its name. Try reinstalling it."
        case .invalidId, .reservedId:
            return "This addon’s id isn’t valid."
        case .invalidMinShellVersion:
            return "This addon’s description couldn’t be read. Try reinstalling it."
        case .invalidDependencyVersion:
            return "This addon’s dependency list isn’t valid."
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
        case .unknownPermission:
            return "This addon’s description couldn’t be read. Try reinstalling it."
        case .invalidConfigSchema:
            return "This addon’s settings description couldn’t be read. Try reinstalling it."
        case .unknownPrimary:
            return "This addon’s description couldn’t be read. Try reinstalling it."
        }
    }

    private static func addonConfigMessage(for error: Error) -> String? {
        guard let config = error as? AddonConfigError else { return nil }
        switch config {
        case .invalidSchema:
            return "This addon’s settings description couldn’t be read. Try reinstalling it."
        case .syntaxError:
            return "This addon’s config file is invalid."
        case let .unknownKey(key):
            return "This addon’s config file has an unknown setting (\(key))."
        case let .invalidValue(key, _):
            return "This addon’s config file has an invalid value for \(key)."
        }
    }

    private static func namespaceMigratorMessage(for error: Error) -> String? {
        guard let ns = error as? NamespaceMigratorError else { return nil }
        switch ns {
        case let .collision(_, occupant):
            return "Another addon (\(occupant)) already uses that name. Uninstall it first."
        }
    }

    private static func viewTypeMessage(for error: Error) -> String? {
        guard let view = error as? ViewTypeError else { return nil }
        switch view {
        case .notAllowed:
            return "This addon asked for a view the shell doesn’t allow."
        case .unknown:
            return "The addon didn’t return a result we could use."
        }
    }

    private static func jobInvokeMessage(for error: Error) -> String? {
        guard let job = error as? JobInvokeError else { return nil }
        switch job {
        case .reuse:
            return ""
        case .stillStopping:
            return JobProgressCopy.stillStopping
        }
    }

    private static func addonRunnerMessage(for error: Error) -> String? {
        guard let runner = error as? AddonRunnerError else { return nil }
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

    private static func addonInstallerMessage(for error: Error) -> String? {
        guard let installer = error as? AddonInstallerError else { return nil }
        switch installer {
        case .sha256Mismatch:
            return "The download didn’t match what we expected. Nothing was installed."
        case .sha256Required:
            return "This package is missing a checksum. Nothing was installed."
        case .missingURL:
            return "No download location is listed for this addon."
        case .hostNotAllowed:
            return "That download location isn’t allowed. Nothing was installed."
        case .downloadFailed:
            return "Couldn’t download the package. Check your connection and try again."
        case .unsafeArchive, .archiveTooLarge:
            return "The package looks unsafe or is too large. Nothing was installed."
        case .helperUnreachable:
            return "Couldn’t download the helper. Check your connection and try again."
        case .helperNotInCatalog:
            return "This addon needs a helper that isn’t in the catalog."
        case let .shellTooOld(required, _):
            return "This addon needs Jugnu \(required) or newer."
        case .invalidMinShellVersion:
            return "This addon’s description couldn’t be read. Try reinstalling it."
        case .nonUniversalBinary:
            return "This addon doesn’t support this Mac’s architecture."
        case .dependency(.unknown):
            return "This addon needs another addon that isn’t in the catalog."
        case .dependency(.cycle):
            return "These addons depend on each other in a loop. Nothing was installed."
        case let .dependency(.versionMismatch(id, required, installed)):
            return "\(id) is installed at \(installed), but this addon needs exactly \(required)."
        case let .dependency(.collision(_, occupant)):
            return "Another addon (\(occupant)) already uses that name. Uninstall it first."
        case .dependency(.invalidVersion):
            return "This addon’s dependency list isn’t valid."
        case .dependencyDisclosureDeclined:
            return "Install canceled."
        case .idMismatch, .addonYAMLMissing, .helperYAMLMissing, .helperManifestMismatch:
            return "Something went wrong. Try again."
        }
    }

    private static func registryFetchMessage(for error: Error) -> String? {
        guard let failure = error as? RegistryFetchFailure else { return nil }
        switch failure {
        case .unreachable: return catalogUnreachable
        case .invalid: return catalogInvalid
        }
    }

    private static func appUpdateMessage(for error: Error) -> String? {
        guard let app = error as? AppUpdateError else { return nil }
        switch app {
        case .sha256Required:
            return "This package is missing a checksum. Nothing was installed."
        case .invalidId:
            return "The app update catalog couldn’t be read."
        case .invalidRegistryURL:
            return "The catalog URL isn't valid."
        case .versionMismatch:
            return "The downloaded app didn’t match the catalog. Nothing was installed."
        case .bundleIdentity:
            return "The downloaded app isn’t a Jugnu app. Nothing was installed."
        case .destNotWritable:
            return "Jugnu can’t replace itself here. Move it to Applications and try again."
        case .helperSpawnFailed:
            return "Couldn’t start the updater. Try again."
        case let .macOSTooOld(required):
            return "This version needs macOS \(required) or newer."
        }
    }

    private static func registryClientMessage(for error: Error) -> String? {
        guard let registry = error as? RegistryClientError else { return nil }
        switch registry {
        case .httpStatus:
            return catalogUnreachable
        case .invalidCatalog:
            return catalogInvalid
        }
    }

    private static func tccGateMessage(for error: Error) -> String? {
        guard let tcc = error as? TCCGateError else { return nil }
        switch tcc {
        case let .declined(permission):
            return "\(permission.displayTitle) is required. Try again when you’re ready."
        case let .openedSettings(permission):
            return "Turn on \(permission.displayTitle) in System Settings, then try again."
        }
    }
}
