import AppKit
import Combine
import JugnuCore
import SwiftUI

@MainActor
public final class ThemeStore: ObservableObject {
    public static let shared = ThemeStore()

    @Published public var config: ThemeConfig = .firefly
    @Published public var soundEnabled: Bool = true

    public var presetId: String {
        if config == .terminalPhosphor {
            return "terminalPhosphor"
        }
        if config == .roseQuartz {
            return "roseQuartz"
        }
        return "firefly"
    }
}

public enum JugnuPresets {
    public static let all: [(id: String, name: String, config: ThemeConfig)] = [
        ("firefly", "Firefly", .firefly),
        ("terminalPhosphor", "Terminal Phosphor", .terminalPhosphor),
        ("roseQuartz", "Rose Quartz", .roseQuartz)
    ]
}

public struct JugnuThemeColors: Equatable {
    public var accent: Color
    public var background: Color
    public var surface: Color
    public var textPrimary: Color
    public var textSecondary: Color
    public var subText: Color
    public var error: Color

    public init(theme: JugnuTheme) {
        accent = Color(jugnuHex: theme.accent, fallback: Color(red: 0.96, green: 0.65, blue: 0.14))
        background = Color(jugnuHex: theme.background, fallback: Color(red: 0.09, green: 0.07, blue: 0.05))
        surface = Color(jugnuHex: theme.surface, fallback: Color(red: 0.12, green: 0.11, blue: 0.07))
        textPrimary = Color(jugnuHex: theme.textPrimary, fallback: Color(red: 0.93, green: 0.90, blue: 0.85))
        textSecondary = Color(jugnuHex: theme.textSecondary, fallback: Color(red: 0.55, green: 0.52, blue: 0.47))
        subText = Color(jugnuHex: theme.subText, fallback: Color(red: 0.72, green: 0.69, blue: 0.62))
        error = Color(jugnuHex: theme.error, fallback: Color(red: 0.90, green: 0.28, blue: 0.30))
    }

    public var border: Color {
        surface.opacity(0.4)
    }

    public var surface2: Color {
        surface.opacity(0.7)
    }

    public var accentDeep: Color {
        accent.opacity(0.75)
    }
}

private struct ThemeEnvKey: EnvironmentKey {
    static let defaultValue = JugnuThemeColors(theme: ThemeConfig.firefly.dark)
}

public extension EnvironmentValues {
    var jugnuTheme: JugnuThemeColors {
        get { self[ThemeEnvKey.self] }
        set { self[ThemeEnvKey.self] = newValue }
    }
}

public extension Color {
    init(jugnuHex: String, fallback: Color) {
        let trimmed = jugnuHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 7, trimmed.hasPrefix("#") else {
            self = fallback
            return
        }
        let hex = trimmed.dropFirst()
        guard let value = UInt64(hex, radix: 16) else {
            self = fallback
            return
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

public func resolvedTheme(from config: ThemeConfig, colorScheme: ColorScheme) -> JugnuTheme {
    let raw = colorScheme == .dark ? config.dark : config.light
    let defaults = colorScheme == .dark ? ThemeConfig.firefly.dark : ThemeConfig.firefly.light
    return raw.sanitized(against: defaults)
}

@MainActor
public func playCommandSound(success: Bool) {
    guard ThemeStore.shared.soundEnabled else { return }
    NSSound(named: success ? "Tink" : "Basso")?.play()
}
