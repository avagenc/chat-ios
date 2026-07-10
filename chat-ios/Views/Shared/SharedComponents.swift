//
//  SharedComponents.swift
//  chat-ios
//
//  Shared components: logo, avatars, brand tile, Google G, toast,
//  ActionConfirm, paper texture.
//

import AuthenticationServices
import SwiftUI
import UIKit

// MARK: - Anchor window for ASWebAuthenticationSession

enum WindowAnchor {
    static var key: ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.compactMap(\.keyWindow).first {
            return window
        }
        // theoretical fallback — a scene always exists while UI is visible
        return UIWindow(windowScene: scenes.first!)
    }
}

// MARK: - Logo (avagenc mark in 3 fills)

enum LogoVariant: String {
    case ink = "avagenc-ink"       // brand lockup
    case accent = "avagenc-accent" // empty-state mark
    case cream = "avagenc-cream"   // inside colored avatars
}

struct LogoView: View {
    var size: CGFloat
    var variant: LogoVariant = .ink

    var body: some View {
        Image(variant.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// MARK: - Agent avatar (circle, agent-color bg, cream logo, inset white ring)

struct AgentAvatar: View {
    var agent: AgentSpec
    var size: CGFloat
    var logoSize: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(agent.color)
            LogoView(size: logoSize, variant: .cream)
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Profile mini avatar (accent gradient, white serif initial)

struct ProfileAvatar: View {
    var initial: String
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [Theme.accent, Theme.accentDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            Text(initial)
                .font(.serif(size * 0.44, .medium))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Google G (official 4-color asset)

struct GoogleG: View {
    var size: CGFloat = 18

    var body: some View {
        Image("google-g")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// MARK: - Brand tile (rounded white tile, radius = size×0.28)

struct BrandTile: View {
    var asset: String
    var size: CGFloat = 38

    var body: some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .padding(size * 0.14)
            .frame(width: size, height: size)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }
}

/// Google Workspace renders as 3 stacked tiles (overlap -9pt).
struct BrandStack: View {
    var assets: [String]

    var body: some View {
        if assets.count > 1 {
            HStack(spacing: -9) {
                ForEach(assets, id: \.self) { BrandTile(asset: $0, size: 28) }
            }
        } else if let single = assets.first {
            BrandTile(asset: single, size: 38)
        }
    }
}

// MARK: - Toast (bottom-center pill, ink bg / bg text, check icon)

struct ToastView: View {
    var text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.sans(13, .medium))
        }
        .foregroundStyle(Theme.bg)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.ink)
        .clipShape(Capsule())
        .shadow(color: Theme.ink.opacity(0.22), radius: 14, y: 8)
    }
}

// MARK: - ActionConfirm (centered confirmation with blurred scrim)

struct ConfirmMeta: Identifiable {
    var id: String { question }
    var icon: String // SF Symbol name
    var question: String
    var sub: String
    var button: String
    var account: String? // optional Google account row
    var run: () -> Void
}

struct ActionConfirmView: View {
    var meta: ConfirmMeta
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.32)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture { onCancel() }

            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accentTint)
                    Image(systemName: meta.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.accentDeep)
                }
                .frame(width: 44, height: 44)

                Text(meta.question)
                    .font(.serif(20, .medium))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text(meta.sub)
                    .font(.sans(13))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                if let account = meta.account {
                    HStack(spacing: 6) {
                        GoogleG(size: 13)
                        Text(account)
                            .font(.sans(12))
                            .foregroundStyle(Theme.inkMuted)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.bgSunk)
                    .clipShape(Capsule())
                }

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Batal")
                            .font(.sans(14, .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.bgSunk)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Button {
                        meta.run()
                        onCancel()
                    } label: {
                        Text(meta.button)
                            .font(.sans(14, .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.22), radius: 32, y: 24)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }
}

// MARK: - Paper grain (4pt radial dot grid)

struct PaperGrain: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 4
            let dot = Theme.ink.opacity(0.022 * 0.5)
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(dot)
                    )
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Group label (11pt/600 uppercase, wide tracking, ink-faint)

struct GroupLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.sans(11, .semibold))
            .kerning(0.66)
            .foregroundStyle(Theme.inkFaint)
    }
}

// MARK: - Spin (rotating refresh animation)

struct Spinning: ViewModifier {
    var active: Bool
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onChange(of: active) { _, spinning in
                if spinning {
                    withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                        angle -= 360
                    }
                } else {
                    withAnimation(.linear(duration: 0.2)) { angle = 0 }
                }
            }
    }
}

extension View {
    func spinning(_ active: Bool) -> some View { modifier(Spinning(active: active)) }
}
