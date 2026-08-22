import SwiftUI

public enum JugnuTokens {
    public enum Radius {
        public static let panel: CGFloat = 12
    }

    public enum Spacing {
        public static let panelPadding: CGFloat = 14
        public static let row: CGFloat = 8
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
