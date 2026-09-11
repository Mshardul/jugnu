import Foundation

public struct AppUpdateSkip {
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

    public static func shouldSkipAddonLaunchCheck(
        firstRunCompleted: Bool,
        screenshotMode: Bool
    ) -> Bool {
        !firstRunCompleted || screenshotMode
    }
}
