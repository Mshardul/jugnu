import Foundation

public enum FirstPartyDaemons {
    // Keep in sync with scripts/validate-addon.sh FIRST_PARTY_DAEMON_IDS.
    public static let ids: Set<String> = ["jugnu.keep-awake", "jugnu.clipboard-history"]

    public static func launchdLabel(addonID: String, commandID: String) -> String {
        // Namespaced ids already include the publisher (`jugnu.keep-awake` → com.jugnu.keep-awake.watch).
        "com.\(addonID).\(commandID)"
    }
}

public enum JobProgressCopy {
    public static let working = "Working…"
    public static let stillWorking = "Still working — longer than usual"
    public static let stillStopping = "Previous run is still stopping — try again in a moment"

    public static func label(elapsed: TimeInterval) -> String {
        elapsed >= 60 ? stillWorking : working
    }
}

public enum JobInvokeError: Error, Equatable {
    case reuse
    case stillStopping
}
