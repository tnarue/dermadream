//
//  DermadreamTheme.swift
//  dermadream
//

import SwiftUI

enum DermadreamTheme {
    // MARK: - Dermatological Harmony palette
    //
    // Source of truth for colour tokens used across the app. Hex values
    // mirror the design palette card 1:1.

    /// `#7D5D3F` — brand primary, active accents, primary buttons.
    static let deepUmber = Color(hex: 0x7D5D3F)
    /// `#D9C5B2` — UI secondary / selected states.
    static let sandstone = Color(hex: 0xD9C5B2)
    /// `#F9F7F2` — UI background / clean space.
    static let creamShell = Color(hex: 0xF9F7F2)
    /// `#333333` — typography & high contrast text.
    static let charcoalGray = Color(hex: 0x333333)
    /// `#C27D60` — status & feedback (critical warnings, "redness" dot).
    static let terracotta = Color(hex: 0xC27D60)
    /// `#999999` — secondary text, placeholders, borders.
    static let softSlate = Color(hex: 0x999999)
    /// `#B8C0B0` — natural element accents (safe-state checkmark, "Normal" copy).
    static let mutedSage = Color(hex: 0xB8C0B0)
    /// `#99D1C3` — cooling & hydration accents.
    static let aquaGlow = Color(hex: 0x99D1C3)

    // MARK: - Legacy aliases (kept for incremental migration)

    /// Deprecated brand teal — replaced by `deepUmber`. Kept so legacy
    /// call sites continue to compile during the palette migration.
    static let teal = deepUmber
    /// Deprecated brand orange — replaced by `terracotta` for warnings.
    static let orange = terracotta

    // MARK: - Risk gauge palette
    //
    // Intentionally NOT remapped to the Dermatological Harmony palette.
    // The gauge keeps its original semantic colours so users can still
    // read severity at a glance.

    /// Muted sage green — "low risk / safe" end of the safety-report gauge.
    static let riskLow = Color(red: 128 / 255, green: 172 / 255, blue: 108 / 255)
    /// Muted yellow — mid point of the gauge.
    static let riskMid = Color(red: 230 / 255, green: 196 / 255, blue: 102 / 255)
    /// Muted red — "high risk" end of the gauge.
    static let riskHigh = Color(red: 191 / 255, green: 71 / 255, blue: 62 / 255)

    /// Main tab switches (tab bar, Quick Menu): cross-fade between `NavigationStack` roots.
    static let mainTabChangeAnimation: Animation = .spring(response: 0.45, dampingFraction: 0.86, blendDuration: 0.2)

    // MARK: - Surfaces

    static let workspaceBackground = creamShell
    static let cardSurface = Color.white
    static let subtleBorder = softSlate.opacity(0.25)

    static func displayBold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func displaySemibold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func label(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static let navTitleSerif = Font.system(size: 22, weight: .bold, design: .serif)
}

extension Color {
    /// Convenience initialiser for `0xRRGGBB` literals so palette tokens
    /// stay readable next to the design spec.
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
