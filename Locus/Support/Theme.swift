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
}

public enum ThemeStore {
    private static let themeKey = "locus.appTheme"

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
}

extension Notification.Name {
    public static let locusThemeDidChange = Notification.Name("locus.themeDidChange")
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
