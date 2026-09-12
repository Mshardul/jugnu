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
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .screenRecording: "Screen Recording"
        case .network: "Network"
        case .clipboard: "Clipboard"
        case .background: "Background agent"
        }
    }

    public var reason: String {
        switch self {
        case .accessibility: "Control other apps’ windows"
        case .inputMonitoring: "Observe keyboard input for this job"
        case .camera: "Use the camera for this job"
        case .microphone: "Use the microphone for this job"
        case .screenRecording: "Capture the screen for this job"
        case .network: "Contact the network for this job"
        case .clipboard: "Read or write the clipboard"
        case .background: "Keep a background agent running after the panel closes"
        }
    }

    public var isTCC: Bool {
        switch self {
        case .accessibility, .inputMonitoring, .camera, .microphone, .screenRecording:
            true
        case .network, .clipboard, .background:
            false
        }
    }

    public static var displayOrder: [AddonPermission] {
        Array(allCases)
    }
}

public enum PermissionsParseError: Error, Equatable {
    case unknown(String)
}
