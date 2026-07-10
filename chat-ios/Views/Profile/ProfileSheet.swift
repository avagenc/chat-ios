//
//  ProfileSheet.swift
//  chat-ios
//
//  Profile panel: Google account card, Usage (today's cost + balance +
//  top-up), Integrations (Workspace/Spotify/Tuya), and Sign out.
//

import AuthenticationServices
import SwiftUI

struct ProfileSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var refreshing = false
    @State private var showTopup = false
    @State private var showTuyaVIP = false
    @State private var confirm: ConfirmMeta?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                PaperGrain()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        profileCard
                        usageSection
                        integrationsSection
                    }
                    .padding(.horizontal, Theme.sidePadding)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profil")
                        .font(.serif(19, .medium))
                        .foregroundStyle(Theme.ink)
                }
            }
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                logoutFooter
            }
        }
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-openTopup") {
                showTopup = true
            }
            #endif
            await refreshAll()
        }
        .sheet(isPresented: $showTopup) {
            TopupSheet()
        }
        .sheet(isPresented: $showTuyaVIP) {
            TuyaVIPSheet()
        }
        .overlay {
            if let meta = confirm {
                ActionConfirmView(meta: meta) {
                    withAnimation(.avagencEase) { confirm = nil }
                }
            }
        }
    }

    private func refreshAll() async {
        refreshing = true
        async let usage: Void = session.wallet.refreshQuietly()
        async let integrations: Void = session.integrations.refresh()
        _ = await (usage, integrations)
        refreshing = false
    }

    // MARK: - Profile card

    private var profileCard: some View {
        VStack(spacing: 10) {
            ProfileAvatar(initial: session.profile.initial, size: 76)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(.white)
                        GoogleG(size: 13)
                    }
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
                }

            Text(session.profile.name)
                .font(.serif(20, .medium))
                .foregroundStyle(Theme.ink)

            if !session.profile.email.isEmpty {
                HStack(spacing: 6) {
                    GoogleG(size: 15)
                    Text(session.profile.email)
                        .font(.sans(12.5))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
            }

            Text("Masuk lewat Akun Google")
                .font(.sans(11.5))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Usage

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupLabel(text: "Pemakaian")

            VStack(spacing: 14) {
                HStack {
                    Text("Hari ini")
                        .font(.sans(13, .medium))
                        .foregroundStyle(Theme.inkSoft)
                    Spacer()
                    if let updated = session.wallet.lastUpdated {
                        Text("Diperbarui \(updated)")
                            .font(.sans(11))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Button {
                        Task {
                            refreshing = true
                            do {
                                try await session.wallet.refresh()
                            } catch {
                                session.flashToast("Gagal memuat pemakaian. Coba lagi.")
                            }
                            refreshing = false
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .spinning(refreshing)
                    }
                    .disabled(refreshing)
                }

                VStack(alignment: .trailing, spacing: 3) {
                    Text(session.wallet.todayCostLabel)
                        .font(.serif(27, .medium))
                        .foregroundStyle(Theme.ink)
                    Text("terpakai hari ini untuk \(session.wallet.todayTokensLabel) token")
                        .font(.sans(11.5))
                        .foregroundStyle(Theme.inkFaint)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                Divider().overlay(Theme.line)

                HStack {
                    HStack(spacing: 6) {
                        Text("Saldo")
                            .font(.sans(12.5))
                            .foregroundStyle(Theme.inkMuted)
                        Text(session.wallet.balanceLabel)
                            .font(.sans(14, .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    Button {
                        showTopup = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Isi ulang")
                                .font(.sans(13, .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
        }
    }

    // MARK: - Integrations

    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupLabel(text: "Integrasi")
            Text("Hubungkan layanan biar Ava dan tim-nya bisa bantu lebih banyak!")
                .font(.sans(12.5))
                .foregroundStyle(Theme.inkMuted)

            VStack(spacing: 0) {
                ForEach(Array(Integrations.all.enumerated()), id: \.element.id) { index, spec in
                    integrationRow(spec)
                    if index < Integrations.all.count - 1 {
                        Divider().overlay(Theme.line).padding(.leading, 16)
                    }
                }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
        }
    }

    private func integrationRow(_ spec: IntegrationSpec) -> some View {
        HStack(spacing: 12) {
            BrandStack(assets: spec.brands)
                .frame(minWidth: 46, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(spec.name)
                    .font(.sans(14, .medium))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 4) {
                    Circle().fill(spec.agent.color).frame(width: 6, height: 6)
                    Text(spec.agent.name)
                        .font(.sans(11.5, .semibold))
                        .foregroundStyle(spec.agent.color)
                    Text("· \(spec.agent.role)")
                        .font(.sans(11))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            integrationControl(spec)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func integrationControl(_ spec: IntegrationSpec) -> some View {
        let state = session.integrations.connected[spec.id] ?? nil
        let busy = session.integrations.busyIntegration == spec.id

        switch (state, spec.kind) {
        case (nil, _):
            Text("memeriksa…")
                .font(.sans(11.5))
                .foregroundStyle(Theme.inkFaint)

        case (true?, .manual):
            connectedBadge(interactive: false)

        case (true?, .oauth):
            Button {
                withAnimation(.avagencEase) {
                    confirm = ConfirmMeta(
                        icon: "rectangle.portrait.and.arrow.right",
                        question: "Putuskan \(spec.name)?",
                        sub: "Agent terkait tidak bisa lagi mengakses akun ini sampai kamu menghubungkannya ulang.",
                        button: "Putuskan",
                        account: nil,
                        run: { disconnect(spec) }
                    )
                }
            } label: {
                connectedBadge(interactive: true)
            }
            .disabled(busy)

        case (false?, .manual):
            Button {
                showTuyaVIP = true
            } label: {
                HStack(spacing: 4) {
                    Text("✦").font(.system(size: 11))
                    Text("VIP").font(.sans(12, .semibold))
                }
                .foregroundStyle(Color(hex: 0x68432F))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: 0xE2BC9E).opacity(0.35))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: 0xAA714A).opacity(0.4), lineWidth: 1))
            }

        case (false?, .oauth):
            Button {
                connect(spec)
            } label: {
                Text("Hubungkan")
                    .font(.sans(12.5, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .disabled(busy)
        }
    }

    private func connectedBadge(interactive: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
            Text("Terhubung")
                .font(.sans(12, .semibold))
        }
        .foregroundStyle(Theme.success)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.success.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.success.opacity(interactive ? 0.35 : 0.2), lineWidth: 1))
    }

    // MARK: - OAuth linking

    /// Open the provider consent page in ASWebAuthenticationSession, capture
    /// the `avagenc-chat://{id}/link/callback?code&state` scheme callback,
    /// then finish with POST /{id}/connection. Note: the backend currently
    /// derives the redirect URI from its web origin — the full mobile flow
    /// needs the backend to register this scheme as a redirect.
    private func connect(_ spec: IntegrationSpec) {
        Task {
            do {
                let url = try await session.integrations.authURL(for: spec.id)
                let callback = try await LinkWebAuth.run(
                    url: url, scheme: AppConfig.linkCallbackScheme
                )
                let comps = URLComponents(url: callback, resolvingAgainstBaseURL: false)
                guard let code = comps?.queryItems?.first(where: { $0.name == "code" })?.value,
                      let state = comps?.queryItems?.first(where: { $0.name == "state" })?.value else {
                    session.flashToast("Gagal menautkan. Coba lagi.")
                    return
                }
                try await session.integrations.completeLink(id: spec.id, code: code, state: state)
                session.flashToast("\(spec.name) terhubung")
            } catch is CancellationError {
                // user dismissed the sheet — stay quiet
            } catch {
                session.flashToast("Gagal memulai penautan. Coba lagi.")
            }
        }
    }

    private func disconnect(_ spec: IntegrationSpec) {
        Task {
            do {
                try await session.integrations.disconnect(id: spec.id)
                session.flashToast("Akun diputuskan")
            } catch {
                session.flashToast("Gagal memutuskan akun. Coba lagi.")
            }
        }
    }

    // MARK: - Sign-out footer

    private var logoutFooter: some View {
        Button {
            withAnimation(.avagencEase) {
                confirm = ConfirmMeta(
                    icon: "rectangle.portrait.and.arrow.right",
                    question: "Keluar dari Avagenc?",
                    sub: "Kamu perlu masuk lagi dengan Google untuk melanjutkan obrolan.",
                    button: "Keluar",
                    account: session.profile.email.isEmpty ? nil : session.profile.email,
                    run: {
                        dismiss()
                        session.logout()
                    }
                )
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .medium))
                Text("Keluar")
                    .font(.sans(15, .semibold))
            }
            .foregroundStyle(Theme.accentDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.accentTint)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .padding(.horizontal, Theme.sidePadding)
        .padding(.vertical, 10)
        .background(Theme.bg)
    }
}

// MARK: - ASWebAuthenticationSession helper for integration linking

enum LinkWebAuth {
    private final class Context: NSObject, ASWebAuthenticationPresentationContextProviding {
        nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            MainActor.assumeIsolated { WindowAnchor.key }
        }
    }

    private static let context = Context()

    static func run(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: url, callback: .customScheme(scheme)
            ) { callbackURL, error in
                if let callbackURL {
                    cont.resume(returning: callbackURL)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    cont.resume(throwing: CancellationError())
                } else {
                    cont.resume(throwing: ApiError(status: 0, detail: "link failed"))
                }
            }
            session.presentationContextProvider = context
            session.start()
        }
    }
}

// MARK: - Tuya VIP sheet

struct TuyaVIPSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("VIP")
                    .font(.sans(10, .semibold))
                    .kerning(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: 0x68432F)))
                Text("Koneksi Manual Diperlukan")
                    .font(.sans(14.5, .semibold))
                    .foregroundStyle(Theme.ink)
            }

            Text("Tuya Smart adalah layanan VIP. Koneksi tidak bisa dilakukan otomatis — hubungi tim Avagenc untuk mengaktifkan integrasi ini.")
                .font(.sans(13.5))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(4)

            Button {
                if let url = URL(string: "mailto:support@avagenc.com") {
                    openURL(url)
                }
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 12, weight: .medium))
                    Text("support@avagenc.com")
                        .font(.sans(13.5, .semibold))
                }
                .foregroundStyle(Theme.accentDeep)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(210)])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
    }
}
