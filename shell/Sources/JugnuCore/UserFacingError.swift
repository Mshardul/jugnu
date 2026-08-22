import Foundation

public enum UserFacingError {
    public static func message(for error: Error) -> String {
        if let loader = error as? ManifestLoaderError {
            switch loader {
            case .emptyId:
                return "This addon is missing its name. Try reinstalling it."
            case .invalidEncoding:
                return "This addon’s description couldn’t be read. Try reinstalling it."
            case .unsupportedAPI:
                return "This addon needs a newer Jugnu."
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
            }
        }
        if let installer = error as? AddonInstallerError {
            switch installer {
            case .sha256Mismatch:
                return "The download didn’t match what we expected. Nothing was installed."
            case .missingURL:
                return "No download location is listed for this addon."
            case .idMismatch, .addonYAMLMissing, .unzipFailed:
                return "Something went wrong. Try again."
            }
        }
        return "Something went wrong. Try again."
    }
}
