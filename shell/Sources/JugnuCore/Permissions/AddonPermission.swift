import Foundation

public enum AddonPermission: String, Codable, CaseIterable, Sendable, Equatable {
    case accessibility
    case inputMonitoring = "input-monitoring"
    case camera
    case microphone
    case screenRecording = "screen-recording"
    case network
    case clipboard
    case background

    public var displayTitle: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .screenRecording: return "Screen Recording"
        case .network: return "Network"
        case .clipboard: return "Clipboard"
        case .background: return "Background agent"
        }
    }

    public var reason: String {
        switch self {
        case .accessibility: return "Control other apps’ windows"
        case .inputMonitoring: return "Observe keyboard input for this job"
        case .camera: return "Use the camera for this job"
        case .microphone: return "Use the microphone for this job"
        case .screenRecording: return "Capture the screen for this job"
        case .network: return "Contact the network for this job"
        case .clipboard: return "Read or write the clipboard"
        case .background: return "Keep a background agent running after the panel closes"
        }
    }

    public var isTCC: Bool {
        switch self {
        case .accessibility, .inputMonitoring, .camera, .microphone, .screenRecording:
            return true
        case .network, .clipboard, .background:
            return false
        }
    }

    public static var displayOrder: [AddonPermission] { Array(allCases) }
}

public enum PermissionsParseError: Error, Equatable {
    case unknown(String)
}
