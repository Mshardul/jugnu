import CoreGraphics
import Foundation

public struct LiveWindow: Equatable, Sendable {
    public var frame: CGRect
    public var displayUUID: String
    public var visible: CGRect

    public init(frame: CGRect, displayUUID: String, visible: CGRect) {
        self.frame = frame
        self.displayUUID = displayUUID
        self.visible = visible
    }
}

public enum ZoneCapture {
    public static func slots(from windows: [LiveWindow]) -> [ZoneSlot] {
        windows.map { window in
            ZoneSlot(
                displayUUID: window.displayUUID,
                fingerprint: DisplayFingerprint(width: window.visible.width, height: window.visible.height),
                norm: NormalizedRect.from(window.frame, in: window.visible)
            )
        }
    }
}
