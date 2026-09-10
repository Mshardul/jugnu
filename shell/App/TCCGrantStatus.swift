import ApplicationServices
import JugnuCore

enum TCCGrantStatus {
    // Best-effort: true skips the explainer and runs.
    static func isGranted(_ permission: AddonPermission) -> Bool {
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted()
        case .inputMonitoring:
            // Prefer not-granted until an addon needs CGPreflight (none declare it yet).
            return false
        case .camera, .microphone, .screenRecording:
            return false
        case .network, .clipboard, .background:
            return true
        }
    }
}
