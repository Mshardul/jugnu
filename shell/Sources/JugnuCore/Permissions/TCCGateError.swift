import Foundation

public enum TCCGateError: Error, Equatable {
    case declined(AddonPermission)
    case openedSettings(AddonPermission)
}
