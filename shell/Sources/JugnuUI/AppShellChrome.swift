import JugnuCore
import SwiftUI

struct ShellPalette: Equatable {
    var frame: Color
    var surface: Color
    var soft: Color
    var raised: Color
    var border: Color
    var borderStrong: Color
    var text: Color
    var muted: Color
    var sub: Color
    var accent: Color
    var accentSoft: Color
    var status: Color

    init(theme: JugnuThemeColors, colorScheme: ColorScheme) {
        let dark = colorScheme == .dark
        frame = theme.background
        surface = theme.surface
        soft = dark ? Color.black.opacity(0.28) : Color.black.opacity(0.05)
        raised = dark ? Color.white.opacity(0.07) : Color.white
        border = theme.textSecondary.opacity(dark ? 0.28 : 0.22)
        borderStrong = theme.textSecondary.opacity(dark ? 0.48 : 0.38)
        text = theme.textPrimary
        muted = theme.textSecondary
        sub = theme.subText
        accent = theme.accent
        accentSoft = theme.accent.opacity(dark ? 0.22 : 0.16)
        status = Color(red: 0.45, green: 0.78, blue: 0.55)
    }
}

struct ShellGlyphTile: View {
    var systemName: String
    var palette: ShellPalette
    var side: CGFloat = 24

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: side * 0.55, weight: .medium))
            .foregroundStyle(palette.sub)
            .frame(width: side, height: side)
            .background(palette.soft)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.3, style: .continuous))
    }
}

struct ShellIconButton: View {
    var systemName: String
    var label: String
    var active: Bool = false
    var palette: ShellPalette
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
                .foregroundStyle(active ? palette.accent : palette.text)
                .background(buttonFill)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(buttonBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .onHover { hovering = $0 }
    }

    private var buttonFill: Color {
        if active {
            return palette.accentSoft
        }
        if hovering {
            return palette.surface
        }
        return .clear
    }

    private var buttonBorder: Color {
        if active {
            return palette.accent.opacity(0.55)
        }
        if hovering {
            return palette.border
        }
        return .clear
    }
}

func homeGreeting(at date: Date = Date(), calendar: Calendar = .current) -> String {
    switch calendar.component(.hour, from: date) {
    case 5 ..< 12:
        "Good morning"
    case 12 ..< 17:
        "Good afternoon"
    default:
        "Good evening"
    }
}

func homeWidgetSymbol(_ definitionID: String) -> String {
    switch definitionID {
    case BuiltInWidget.favoriteAddons:
        "star"
    case BuiltInWidget.recentActivity:
        "clock"
    case BuiltInWidget.updates:
        "arrow.triangle.2.circlepath"
    case BuiltInWidget.runningWork:
        "bolt"
    default:
        "square.grid.2x2"
    }
}
