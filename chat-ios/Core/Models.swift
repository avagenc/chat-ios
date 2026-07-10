//
//  Models.swift
//  chat-ios
//
//  API DTOs (exact backend contract) + the UI message model.
//

import Foundation

// MARK: - UI message

struct ChatMessage: Identifiable, Equatable {
    enum Status: Equatable {
        case sending
        case error(note: ErrorNote?)
    }

    enum ErrorNote: Equatable {
        case saldo // 402 from the backend — out of balance
    }

    let id: String
    var from: String // "human" or an agent id
    var text: String
    var time: String // "HH:MM"
    var at: String? // ISO timestamp from the backend
    var status: Status?

    var isHuman: Bool { from == "human" }
    var agent: AgentSpec? { Agents.byID[from] }

    /// Tiny bubble for delegation messages that are just "@zee." etc.
    var isTinyMention: Bool {
        text.wholeMatch(of: /@\w+[.!]?/) != nil
    }
}

// MARK: - Backend DTOs

/// `session.Message` — GET /sessions/messages
nonisolated struct SessionMessageDTO: Decodable {
    let content: String
    let createdAt: String?
    let name: String?
    let role: String
    let uuid: String?

    enum CodingKeys: String, CodingKey {
        case content
        case createdAt = "created_at"
        case name, role, uuid
    }

    /// Mapping to a UI message:
    /// system → nil (Postera wake-up messages for Ava);
    /// user + known agent name → an Ava delegation turn (shown as the agent);
    /// assistant → from `name` (fallback ava).
    func toUIMessage() -> ChatMessage? {
        let from: String
        switch role {
        case "system":
            return nil
        case "user":
            if let name, Agents.byID[name.lowercased()] != nil {
                from = name.lowercased()
            } else {
                from = "human"
            }
        default: // assistant
            from = name.map { Agents.byID[$0.lowercased()] != nil ? $0.lowercased() : "ava" } ?? "ava"
        }
        return ChatMessage(
            id: uuid ?? UUID().uuidString,
            from: from,
            text: content,
            time: TimeFmt.clock(iso: createdAt),
            at: createdAt
        )
    }
}

nonisolated struct MessageListDTO: Decodable {
    let messages: [SessionMessageDTO]?
}

/// POST /ava|/zee|/yori|/rafal
nonisolated struct AgentTurnRequest: Encodable {
    let message: String
}

nonisolated struct AgentTurnResponse: Decodable {
    let response: String
}

/// GET /wallet
nonisolated struct WalletDTO: Decodable {
    let balance: Int64
}

/// GET /wallet/usage/today
nonisolated struct UsageDTO: Decodable {
    let tokens: Int64
    let cost: Int64
}

/// GET /postera — PascalCase array (Go structs without json tags)
nonisolated struct PosterumDTO: Decodable {
    let id: String
    let message: String
    let triggerAt: String

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case message = "Message"
        case triggerAt = "TriggerAt"
    }
}

struct Posterum: Identifiable, Equatable {
    let id: String
    let message: String
    let awakenAt: String // pre-formatted label

    init(dto: PosterumDTO) {
        id = dto.id
        message = dto.message
        awakenAt = TimeFmt.awakenLabel(iso: dto.triggerAt)
    }
}

/// GET /{integration}/connection
nonisolated struct ConnectionDTO: Decodable {
    let connected: Bool
}

/// GET /{integration}/auth-url
nonisolated struct AuthURLDTO: Decodable {
    let url: String
}

// MARK: - Integrations

struct IntegrationSpec: Identifiable {
    enum Kind { case oauth, manual }

    let id: String
    let name: String
    let brands: [String] // "brand-*" asset names
    let agent: AgentSpec
    let kind: Kind
}

enum Integrations {
    /// One Google Workspace OAuth grant covers Gmail + Contacts + Calendar.
    /// Tuya is linked manually by the team (VIP onboarding).
    static let all: [IntegrationSpec] = [
        IntegrationSpec(
            id: "gworkspace", name: "Google Workspace",
            brands: ["brand-gmail", "brand-google-contacts", "brand-google-calendar"],
            agent: Agents.rafal, kind: .oauth
        ),
        IntegrationSpec(
            id: "spotify", name: "Spotify",
            brands: ["brand-spotify"],
            agent: Agents.yori, kind: .oauth
        ),
        IntegrationSpec(
            id: "tuya", name: "Tuya Smart",
            brands: ["brand-tuya-smart"],
            agent: Agents.zee, kind: .manual
        ),
    ]
}
