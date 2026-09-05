import CoreGraphics
import Foundation

public struct NormalizedRect: Equatable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public static func from(_ rect: CGRect, in visible: CGRect) -> NormalizedRect {
        NormalizedRect(
            x: visible.width == 0 ? 0 : (rect.minX - visible.minX) / visible.width,
            y: visible.height == 0 ? 0 : (rect.minY - visible.minY) / visible.height,
            w: visible.width == 0 ? 0 : rect.width / visible.width,
            h: visible.height == 0 ? 0 : rect.height / visible.height
        )
    }

    public func denormalized(in visible: CGRect) -> CGRect {
        CGRect(
            x: visible.minX + x * visible.width,
            y: visible.minY + y * visible.height,
            width: w * visible.width,
            height: h * visible.height
        )
    }
}

public enum SnapRegion: String, Equatable, Sendable, CaseIterable {
    case leftHalf = "left-half"
    case rightHalf = "right-half"
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
    case center = "center-window"
    case fillDesktop = "fill-desktop"
    case maximize = "maximize"
}

public enum LayoutGeometry {
    public static func rect(for region: SnapRegion, visible: CGRect) -> CGRect {
        let midX = visible.midX
        let midY = visible.midY
        switch region {
        case .leftHalf:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .rightHalf:
            return CGRect(x: midX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .topLeft:
            return CGRect(x: visible.minX, y: midY, width: visible.width / 2, height: visible.height / 2)
        case .topRight:
            return CGRect(x: midX, y: midY, width: visible.width / 2, height: visible.height / 2)
        case .bottomLeft:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height / 2)
        case .bottomRight:
            return CGRect(x: midX, y: visible.minY, width: visible.width / 2, height: visible.height / 2)
        case .center:
            let width = visible.width * 0.7
            let height = visible.height * 0.7
            return CGRect(
                x: visible.midX - width / 2,
                y: visible.midY - height / 2,
                width: width,
                height: height
            )
        case .fillDesktop, .maximize:
            return visible
        }
    }

    public static func tileTwo(front: CGRect, other: CGRect, visible: CGRect, swap: Bool) -> (CGRect, CGRect) {
        let left = rect(for: .leftHalf, visible: visible)
        let right = rect(for: .rightHalf, visible: visible)
        if swap { return (right, left) }
        return (left, right)
    }
}
