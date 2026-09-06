import Foundation

public struct AppUpdateSkip {
    /// App zip check (launch). True → do not fetch app registry.
    public static func shouldSkipAppCheck(
        firstRunCompleted: Bool,
        screenshotMode: Bool,
        bundlePath: String,
        env: [String: String],
        isDebug: Bool
    ) -> Bool {
        if !firstRunCompleted { return true }
        if screenshotMode { return true }
        if isDebug { return true }
        if bundlePath.contains(".build/") || bundlePath.contains("DerivedData") { return true }
        if let skip = env["JUGNU_SKIP_APP_UPDATE"], !skip.isEmpty { return true }
        return false
    }

    /// Addon bulk on launch. True → do not fetch addon catalog for bulk.
    public static func shouldSkipAddonLaunchCheck(
        firstRunCompleted: Bool,
        screenshotMode: Bool
    ) -> Bool {
        !firstRunCompleted || screenshotMode
    }
}
