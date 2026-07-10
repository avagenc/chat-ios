//
//  Theme.swift
//  chat-ios
//
//  Avagenc design tokens.
//  Color/typography/radius values here are FINAL — do not "fix" them.
//

import SwiftUI

// MARK: - Color helpers

extension Color {
    /// Hex 0xRRGGBB + alpha.
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Tokens

nonisolated enum Theme {
    // Surfaces — warm, never pure white
    static let bg = Color(hex: 0xFAF6EC)
    static let bgSunk = Color(hex: 0xF4EEE0)
    static let surface = Color(hex: 0xFEFCF6)
    static let surface2 = Color(hex: 0xFBF7EE)

    // Ink — browny-black, never #000
    static let ink = Color(hex: 0x2C231C)
    static let inkSoft = Color(hex: 0x3A2E24)
    static let inkMuted = Color(hex: 0x2C231C, opacity: 0.52)
    static let inkFaint = Color(hex: 0x2C231C, opacity: 0.34)
    static let inkGhost = Color(hex: 0x2C231C, opacity: 0.16)

    // Hairlines — used instead of shadows
    static let line = Color(hex: 0x2C231C, opacity: 0.11)
    static let lineStrong = Color(hex: 0x2C231C, opacity: 0.17)

    // Accent — a single muted terracotta
    static let accent = Color(hex: 0xB5734A)
    static let accentDeep = Color(hex: 0x8E5733)
    static let accentTint = Color(hex: 0xB5734A, opacity: 0.13)
    static let accentTintStrong = Color(hex: 0xB5734A, opacity: 0.20)

    // Agent hues — defined in OKLCH, converted to sRGB
    static let ava = Color(hex: 0xAA714A)     // oklch(0.60 0.09 55)
    static let zee = Color(hex: 0x968647)     // oklch(0.62 0.085 95)
    static let yori = Color(hex: 0x558867)    // oklch(0.58 0.075 155)
    static let rafal = Color(hex: 0x5B81A5)   // oklch(0.59 0.07 248)
    static let gojo = Color(hex: 0x5A8F65)    // oklch(0.60 0.085 150)
    static let sophie = Color(hex: 0xB97155)  // oklch(0.62 0.10 42)

    static let success = Color(hex: 0x488055) // oklch(0.55 0.09 150)
    static let cream = Color(hex: 0xFAF6EC)

    // Radii
    static let radius: CGFloat = 16
    static let radiusSm: CGFloat = 10
    static let bubbleCorner: CGFloat = 6 // bubble "pointer" corner

    // Layout
    static let messageGap: CGFloat = 18
    static let groupedGap: CGFloat = 4
    static let sidePadding: CGFloat = 16
}

// MARK: - Typography
// Newsreader (serif) — message body, headings, brand, large numbers.
// Inter Tight (sans) — UI/labels/meta.

extension Font {
    static func serif(_ size: CGFloat, _ weight: SerifWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    static func sans(_ size: CGFloat, _ weight: SansWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    enum SerifWeight {
        case regular, medium, semibold
        var postScriptName: String {
            switch self {
            case .regular: "Newsreader-Regular"
            case .medium: "Newsreader-Medium"
            case .semibold: "Newsreader-SemiBold"
            }
        }
    }

    enum SansWeight {
        case regular, medium, semibold
        var postScriptName: String {
            switch self {
            case .regular: "InterTight-Regular"
            case .medium: "InterTight-Medium"
            case .semibold: "InterTight-SemiBold"
            }
        }
    }
}

// MARK: - Motion

extension Animation {
    static let avagencEase = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)
    static let avagencRise = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.42)
}

// MARK: - Reusable modifiers

/// Entrance: rise 8pt + fade in.
struct RiseIn: ViewModifier {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .onAppear {
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.avagencRise) { shown = true }
                }
            }
    }
}

extension View {
    func riseIn() -> some View { modifier(RiseIn()) }
}
