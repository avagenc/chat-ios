//
//  Stores.swift
//  chat-ios
//
//  Wallet, Postera, Integrations, and Session (root) stores.
//

import Foundation
import SwiftUI

// MARK: - Wallet

@Observable
final class WalletStore {
    private let api: APIClient

    private(set) var balance: Int64?
    private(set) var todayTokens: Int64?
    private(set) var todayCost: Int64?
    private(set) var lastUpdated: String? // "HH:MM"
    private(set) var refreshing = false

    init(api: APIClient = .shared) {
        self.api = api
    }

    var balanceLabel: String { Rupiah.label(balance) }
    var todayCostLabel: String { Rupiah.label(todayCost) }
    var todayTokensLabel: String {
        guard let todayTokens else { return "—" }
        return Rupiah.grouped(todayTokens)
    }

    func refresh() async throws {
        refreshing = true
        defer { refreshing = false }
        async let walletReq = api.get(WalletDTO.self, "/wallet")
        async let usageReq = api.get(UsageDTO.self, "/wallet/usage/today")
        let (wallet, usage) = try await (walletReq, usageReq)
        balance = wallet?.balance
        todayTokens = usage?.tokens
        todayCost = usage?.cost
        lastUpdated = TimeFmt.clock()
    }

    func refreshQuietly() async {
        try? await refresh()
    }

    func reset() {
        balance = nil
        todayTokens = nil
        todayCost = nil
        lastUpdated = nil
    }
}

// MARK: - Postera

@Observable
final class PosteraStore {
    private let api: APIClient

    private(set) var list: [Posterum] = []
    private(set) var lastFetched: String? // "HH:MM"

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load() async throws {
        let dtos = try await api.get([PosterumDTO].self, "/postera") ?? []
        list = dtos.map(Posterum.init(dto:))
        lastFetched = TimeFmt.clock()
    }

    func cancel(id: String) async throws {
        try await api.delete("/postera/\(id)")
        list.removeAll { $0.id == id }
    }

    func reset() {
        list = []
        lastFetched = nil
    }
}

// MARK: - Integrations

@Observable
final class IntegrationsStore {
    private let api: APIClient

    /// nil = status unknown (still fetching / fetch failed)
    private(set) var connected: [String: Bool?] = [
        "gworkspace": nil, "spotify": nil, "tuya": nil,
    ]
    /// Integration id currently being processed (auth-url request / disconnect)
    private(set) var busyIntegration: String?

    init(api: APIClient = .shared) {
        self.api = api
    }

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            for spec in Integrations.all {
                group.addTask { [weak self] in
                    await self?.check(spec)
                }
            }
        }
    }

    private func check(_ spec: IntegrationSpec) async {
        do {
            let status = try await api.get(ConnectionDTO.self, "/\(spec.id)/connection")
            connected[spec.id] = status?.connected ?? false
        } catch {
            // OAuth → leave as "checking…"; manual (Tuya) → treat as not
            // connected so the VIP CTA still shows.
            connected[spec.id] = spec.kind == .manual ? false : Bool??.some(nil)
        }
    }

    /// Request the provider consent URL to start the OAuth flow.
    func authURL(for id: String) async throws -> URL {
        busyIntegration = id
        defer { busyIntegration = nil }
        guard let dto = try await api.get(AuthURLDTO.self, "/\(id)/auth-url"),
              let url = URL(string: dto.url) else {
            throw ApiError(status: 0, detail: "invalid auth url")
        }
        return url
    }

    /// Finish linking from the OAuth callback (code + state).
    func completeLink(id: String, code: String, state: String) async throws {
        struct Body: Encodable {
            let code: String
            let state: String
        }
        try await api.post("/\(id)/connection", body: Body(code: code, state: state))
        connected[id] = true
    }

    func disconnect(id: String) async throws {
        busyIntegration = id
        defer { busyIntegration = nil }
        do {
            try await api.delete("/\(id)/connection")
            connected[id] = false
        } catch let e as ApiError where e.status == 404 {
            connected[id] = false // was never connected
        }
    }

    func reset() {
        connected = ["gworkspace": nil, "spotify": nil, "tuya": nil]
    }
}

// MARK: - Session — root app state

@Observable
final class SessionStore {
    let auth: AuthService
    let wallet: WalletStore
    let conversation: ConversationStore
    let postera: PosteraStore
    let integrations: IntegrationsStore

    // UI state
    var toast: String?
    var searchActive = false
    var searchQuery = ""
    var searchIndex = 0

    private var toastTask: Task<Void, Never>?

    init() {
        let auth = AuthService()
        let wallet = WalletStore()
        self.auth = auth
        self.wallet = wallet
        conversation = ConversationStore(wallet: wallet)
        postera = PosteraStore()
        integrations = IntegrationsStore()
        APIClient.shared.credentialProvider = auth

        if auth.authed {
            bootstrap()
        }
    }

    var profile: UserProfile {
        auth.profile ?? UserProfile(name: "Human", email: "")
    }

    /// Load initial data after login.
    func bootstrap() {
        Task { await conversation.load() }
        Task { try? await postera.load() }
        Task { await wallet.refreshQuietly() }
    }

    func logout() {
        auth.logout()
        conversation.reset()
        postera.reset()
        wallet.reset()
        integrations.reset()
        closeSearch()
    }

    /// Toast with a 2200 ms auto-dismiss.
    func flashToast(_ text: String) {
        toastTask?.cancel()
        toast = text
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2200))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func openSearch() {
        searchActive = true
        searchQuery = ""
        searchIndex = 0
    }

    func closeSearch() {
        searchActive = false
        searchQuery = ""
        searchIndex = 0
    }
}
