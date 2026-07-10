//
//  LoginView.swift
//  chat-ios
//
//  Sign-in screen: brand, hook headline + typewriter accent line, login card
//  (announcement strip + Google button), legal text, demo notice.
//

import AuthenticationServices
import SwiftUI
import UIKit

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var busy = false

    private let typewriterLine = "tanpa biaya langganan."
    @State private var shownChars = 0

    var body: some View {
        ZStack {
            // login uses surface as the page background
            Theme.surface.ignoresSafeArea()
            PaperGrain()

            VStack(alignment: .leading, spacing: 0) {
                // top-leading brand
                HStack(spacing: 8) {
                    LogoView(size: 24, variant: .ink)
                    Text("Avagenc")
                        .font(.serif(20, .medium))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.top, 18)

                Spacer()

                // hook
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ava dan tim multi agentnya siap melayani mu,")
                        .font(.serif(30))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(6)
                        .kerning(-0.4)

                    HStack(spacing: 0) {
                        Text(String(typewriterLine.prefix(shownChars)))
                            .font(.serif(30))
                            .foregroundStyle(Theme.accentDeep)
                            .kerning(-0.4)
                        TypewriterCursor()
                    }
                    .frame(height: 40)
                }
                .riseIn()

                // login card
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Text("BARU")
                            .font(.sans(9.5, .semibold))
                            .kerning(0.3)
                            .foregroundStyle(Theme.accentDeep)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .background(Theme.accentTint)
                            .clipShape(Capsule())

                        Text("\(Text("Rafal:").font(.sans(11, .semibold)).foregroundStyle(Theme.accentDeep)) Siap mengurus Gmail, kontak, & kalendermu.")
                            .font(.sans(11))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    Divider().overlay(Theme.line)

                    Button {
                        login()
                    } label: {
                        HStack(spacing: 10) {
                            if busy {
                                ProgressView().tint(Theme.inkMuted)
                            } else {
                                GoogleG(size: 18)
                            }
                            Text("Lanjutkan dengan Google")
                                .font(.sans(15, .medium))
                                .foregroundStyle(Theme.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .strokeBorder(Theme.lineStrong, lineWidth: 1)
                )
                .padding(.top, 34)
                .riseIn()

                // legal + notice
                VStack(spacing: 6) {
                    legalText
                        .font(.sans(11))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.center)
                    Text("*Mode demo. Pembayaran isi ulang saldo diproses melalui Midtrans.")
                        .font(.sans(11))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: 480)
        }
        .onAppear {
            startTypewriter()
        }
    }

    private var legalText: Text {
        let base = AppConfig.webAppURL
        return Text(.init(
            "Dengan masuk, kamu setuju dengan [Ketentuan](\(base)/legal) dan [Kebijakan Privasi](\(base)/legal) Avagenc."
        ))
    }

    /// Typewriter: type over ~950 ms, pause 10 s, repeat.
    private func startTypewriter() {
        if reduceMotion {
            shownChars = typewriterLine.count
            return
        }
        let charDelay = max(0.028, 0.95 / Double(typewriterLine.count))
        Task {
            while !Task.isCancelled {
                for i in 0 ... typewriterLine.count {
                    shownChars = i
                    try? await Task.sleep(for: .seconds(charDelay))
                }
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func login() {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                guard let root = WindowAnchor.key.rootViewController else {
                    throw AuthError.failed("Gagal masuk. Coba lagi.")
                }
                try await session.auth.loginWithGoogle(presenting: topController(from: root))
            } catch AuthError.cancelled {
                // user dismissed the sheet — stay quiet
            } catch AuthError.notConfigured {
                session.flashToast("Firebase belum dikonfigurasi (GoogleService-Info.plist).")
            } catch {
                session.flashToast("Gagal masuk. Coba lagi.")
            }
        }
    }

    private func topController(from root: UIViewController) -> UIViewController {
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

/// Blinking "|" cursor (0.85 s cycle).
private struct TypewriterCursor: View {
    @State private var visible = true

    var body: some View {
        Text("|")
            .font(.serif(30))
            .foregroundStyle(Theme.accentDeep)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.425).repeatForever()) {
                    visible = false
                }
            }
    }
}
