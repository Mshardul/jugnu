import Foundation

public enum LifecycleClass: String, Codable, Equatable, Sendable {
    case oneshot
    case job
    case daemon
}
