import SwiftUI

public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case mint = "Mint & Coral"
    case cyberpunk = "Neon Cyber"
    case electric = "Electric Violet"
    case sunset = "Sunset Glow"
    case ruby = "Ruby Crimson"
    case emerald = "Emerald Matrix"
    case ocean = "Deep Ocean"

    public var id: String { rawValue }

    public var accentColor: Color {
        switch self {
        case .mint:
            return Color(red: 0.35, green: 0.78, blue: 0.72) // #59C7B8
        case .cyberpunk:
            return Color(red: 0.00, green: 0.94, blue: 1.00) // #00F0FF
        case .electric:
            return Color(red: 0.62, green: 0.31, blue: 0.87) // #9E4FDE
        case .sunset:
            return Color(red: 1.00, green: 0.48, blue: 0.00) // #FF7A00
        case .ruby:
            return Color(red: 0.90, green: 0.22, blue: 0.27) // #E63946
        case .emerald:
            return Color(red: 0.02, green: 0.84, blue: 0.63) // #06D6A0
        case .ocean:
            return Color(red: 0.07, green: 0.54, blue: 0.70) // #118AB2
        }
    }

    public var accentSecondaryColor: Color {
        switch self {
        case .mint:
            return Color(red: 0.95, green: 0.55, blue: 0.28) // #F28C47
        case .cyberpunk:
            return Color(red: 1.00, green: 0.00, blue: 0.33) // #FF0055
        case .electric:
            return Color(red: 1.00, green: 0.36, blue: 0.56) // #FF5D8F
        case .sunset:
            return Color(red: 1.00, green: 0.72, blue: 0.01) // #FFB703
        case .ruby:
            return Color(red: 0.91, green: 0.77, blue: 0.42) // #E9C46A
        case .emerald:
            return Color(red: 0.71, green: 0.89, blue: 0.55) // #B5E48C
        case .ocean:
            return Color(red: 0.28, green: 0.79, blue: 0.89) // #48CAE4
        }
    }

    public var displayName: String { rawValue }

    public var accentHex: String {
        switch self {
        case .mint: return "#59C7B8"
        case .cyberpunk: return "#00F0FF"
        case .electric: return "#9E4FDE"
        case .sunset: return "#FF7A00"
        case .ruby: return "#E63946"
        case .emerald: return "#06D6A0"
        case .ocean: return "#118AB2"
        }
    }

    public var accentSecondaryHex: String {
        switch self {
        case .mint: return "#F28C47"
        case .cyberpunk: return "#FF0055"
        case .electric: return "#FF5D8F"
        case .sunset: return "#FFB703"
        case .ruby: return "#E9C46A"
        case .emerald: return "#B5E48C"
        case .ocean: return "#48CAE4"
        }
    }
}

public enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// CSS variables representation of the UI appearance tokens
    public var cssVariables: [String: String] {
        switch self {
        case .light:
            return [
                "--bg-primary": "#F6F7FB",
                "--bg-surface": "#FFFFFF",
                "--text-primary": "#111827",
                "--text-secondary": "#6B7280",
                "--border-color": "rgba(0, 0, 0, 0.10)",
                "--panel-bg": "rgba(255, 255, 255, 0.85)",
                "--accent": ThemeStore.currentTheme.accentHex,
                "--accent-secondary": ThemeStore.currentTheme.accentSecondaryHex
            ]
        case .dark, .system:
            return [
                "--bg-primary": "#0A0D12",
                "--bg-surface": "#121824",
                "--text-primary": "#FFFFFF",
                "--text-secondary": "#9CA3AF",
                "--border-color": "rgba(255, 255, 255, 0.12)",
                "--panel-bg": "rgba(20, 24, 34, 0.85)",
                "--accent": ThemeStore.currentTheme.accentHex,
                "--accent-secondary": ThemeStore.currentTheme.accentSecondaryHex
            ]
        }
    }

    public var cssVariablesString: String {
        cssVariables.map { "\($0.key): \($0.value);" }.sorted().joined(separator: "\n")
    }
}

public enum ThemeStore {
    private static let themeKey = "locus.appTheme"
    private static let appearanceKey = "locus.appearanceMode"

    public static var currentTheme: AppTheme {
        get {
            guard let raw = UserDefaults.standard.string(forKey: themeKey),
                  let theme = AppTheme(rawValue: raw) else {
                return .mint
            }
            return theme
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: themeKey)
            NotificationCenter.default.post(name: .locusThemeDidChange, object: newValue)
        }
    }

    public static var currentAppearance: AppearanceMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: appearanceKey),
                  let mode = AppearanceMode(rawValue: raw) else {
                return .dark
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: appearanceKey)
            NotificationCenter.default.post(name: .locusAppearanceDidChange, object: newValue)
        }
    }
}

extension Notification.Name {
    public static let locusThemeDidChange = Notification.Name("locus.themeDidChange")
    public static let locusAppearanceDidChange = Notification.Name("locus.appearanceDidChange")
}

public enum LocusTheme {
    public static var accent: Color {
        ThemeStore.currentTheme.accentColor
    }

    public static var accentSecondary: Color {
        ThemeStore.currentTheme.accentSecondaryColor
    }

    public static let danger = Color(red: 0.92, green: 0.32, blue: 0.36)
    public static let panelStroke = Color.white.opacity(0.12)
    public static let statusGood = Color(red: 0.30, green: 0.86, blue: 0.55)
    public static let statusWarn = Color(red: 0.98, green: 0.78, blue: 0.28)
    public static let statusBad = Color(red: 0.92, green: 0.32, blue: 0.36)
}

public enum LocusGlassStyle {
    case regular
    case clear
    case interactive
}

/// Liquid Glass on iOS 26+; material fallback earlier.
public struct LocusGlassModifier<S: Shape>: ViewModifier {
    public var style: LocusGlassStyle
    public var shape: S
    public var tint: Color?

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(glass, in: shape)
                .contentShape(shape)
        } else {
            content
                .background {
                    shape.fill(.ultraThinMaterial)
                    if let tint {
                        shape.fill(tint.opacity(0.55))
                    }
                }
                .overlay(shape.stroke(LocusTheme.panelStroke, lineWidth: 1))
                .contentShape(shape)
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var g: Glass = style == .clear ? .clear : .regular
        if style == .interactive { g = g.interactive() }
        if let tint { g = g.tint(tint) }
        return g
    }
}

extension View {
    public func locusGlass<S: Shape>(
        _ style: LocusGlassStyle = .regular,
        tint: Color? = nil,
        in shape: S
    ) -> some View {
        modifier(LocusGlassModifier(style: style, shape: shape, tint: tint))
    }

    public func locusGlass(_ style: LocusGlassStyle = .regular, tint: Color? = nil) -> some View {
        locusGlass(style, tint: tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension Color {
    public init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        guard cleanHex.count == 6, let rgb = UInt64(cleanHex, radix: 16) else {
            return nil
        }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
