import Foundation

public enum TCCPrivacyURL {
    public static func systemSettingsURL(for permission: AddonPermission) -> URL? {
        guard permission.isTCC else { return nil }
        let privacyKey: String
        switch permission {
        case .accessibility:
            privacyKey = "Privacy_Accessibility"
        case .inputMonitoring:
            privacyKey = "Privacy_ListenEvent"
        case .camera:
            privacyKey = "Privacy_Camera"
        case .microphone:
            privacyKey = "Privacy_Microphone"
        case .screenRecording:
            privacyKey = "Privacy_ScreenCapture"
        case .network, .clipboard, .background:
            return nil
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(privacyKey)")
    }
}
