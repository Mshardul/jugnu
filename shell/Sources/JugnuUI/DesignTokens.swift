import SwiftUI

public enum JugnuTokens {
    public enum Radius {
        public static let panel: CGFloat = 12
    }

    public enum Spacing {
        public static let panelPadding: CGFloat = 14
        public static let row: CGFloat = 8
    }

    /// viewA (Opt+Space launcher) geometry — values from 2026-08-25-launcher-catalog-mockup.html.
    public enum Launcher {
        public static let panelWidth: CGFloat = 640
        public static let hairline: CGFloat = 1
        public static let edgeInset: CGFloat = 16
        public static let row1Height: CGFloat = 52
        public static let favTile: CGFloat = 28
        public static let favTileRadius: CGFloat = 8
        public static let favSpacing: CGFloat = 6
        public static let searchRadius: CGFloat = 9
        public static let resultRowHeight: CGFloat = 46
        public static let resultSlotCount = 5
        public static let resultIcon: CGFloat = 26
        public static let resultIconRadius: CGFloat = 7
    }

    public enum Typography {
        public static let title = Font.headline
        public static let body = Font.body
        public static let caption = Font.caption
    }

    public static func font(presetId: String, role: Font.TextStyle) -> Font {
        if presetId == "terminalPhosphor" {
            return .system(role, design: .monospaced)
        }
        return .system(role)
    }
}
