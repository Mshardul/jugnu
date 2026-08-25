import CoreGraphics
import Foundation

public enum ViewType: String, Codable, CaseIterable, Sendable, Equatable {
    case seek
    case palette
    case ask
    case fields
    case rows
    case grid
    case board
    case spread
    case canvas
    case rail

    public static let shellDefaults: [ViewType] = [.rows, .fields, .ask]

    public var dismissesOnOutsideClick: Bool {
        switch self {
        case .board, .spread, .canvas: return false
        case .seek, .palette, .ask, .fields, .rows, .grid, .rail: return true
        }
    }

    public func size(in visible: CGRect) -> CGSize {
        var width: Double
        var height: Double
        switch self {
        case .seek:
            width = clamped(visible.width * 0.40, min: 480, max: 560)
            height = 120
        case .palette:
            width = clamped(visible.width * 0.40, min: 480, max: 560)
            height = clamped(visible.height * 0.40, min: 280, max: 360)
        case .ask:
            width = clamped(visible.width * 0.28, min: 340, max: 420)
            height = clamped(visible.height * 0.20, min: 160, max: 220)
        case .fields:
            width = clamped(visible.width * 0.35, min: 400, max: 560)
            height = clamped(visible.height * 0.32, min: 240, max: 480)
        case .rows:
            width = clamped(visible.width * 0.32, min: 400, max: 560)
            height = clamped(visible.height * 0.45, min: 320, max: 700)
        case .grid, .board:
            width = clamped(visible.width * 0.40, min: 640, max: 1100)
            height = clamped(visible.height * 0.40, min: 400, max: 800)
        case .spread:
            width = clamped(visible.width * 0.45, min: 700, max: 1100)
            height = clamped(visible.height * 0.45, min: 420, max: 800)
        case .canvas:
            width = clamped(visible.width * 0.70, min: 800, max: 1400)
            height = clamped(visible.height * 0.70, min: 500, max: 900)
        case .rail:
            width = clamped(visible.width * 0.22, min: 480, max: 560)
            height = clamped(visible.height * 0.62, min: 480, max: 800)
        }
        width = min(width, visible.width)
        height = min(height, visible.height)
        switch aspect {
        case .landscape:
            if height >= width {
                height = min(height, width * 0.75)
            }
        case .portrait:
            if width >= height {
                width = min(width, height * 0.85)
            }
        }
        width = min(width, visible.width)
        height = min(height, visible.height)
        return CGSize(width: width, height: height)
    }

    public static func resolve(pattern: UIPattern, requested: ViewType?, allowed: [ViewType]) throws -> ViewType? {
        if pattern == .note || pattern == .card { return nil }
        let chosen = requested ?? pattern.defaultViewType
        guard let chosen else { return nil }
        guard allowed.contains(chosen) else {
            throw ViewTypeError.notAllowed(chosen.rawValue)
        }
        return chosen
    }

    private var aspect: ViewAspect {
        switch self {
        case .seek, .palette, .ask, .grid, .board, .spread, .canvas:
            return .landscape
        case .fields, .rows, .rail:
            return .portrait
        }
    }
}

private enum ViewAspect {
    case landscape
    case portrait
}

public enum ViewTypeError: Error, Equatable {
    case notAllowed(String)
    case unknown(String)
}

public extension UIPattern {
    var defaultViewType: ViewType? {
        switch self {
        case .list: return .rows
        case .form: return .fields
        case .confirm: return .ask
        case .note, .card: return nil
        }
    }
}

private func clamped(_ value: Double, min lower: Double, max upper: Double) -> Double {
    min(max(value, lower), upper)
}
