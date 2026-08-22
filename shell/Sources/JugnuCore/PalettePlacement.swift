import CoreGraphics
import Foundation

public enum PalettePlacement {
    public static func screenIndex(frames: [CGRect], mouse: CGPoint) -> Int? {
        frames.firstIndex { $0.contains(mouse) }
    }
}
