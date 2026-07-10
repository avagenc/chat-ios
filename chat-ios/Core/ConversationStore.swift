//
//  ConversationStore.swift
//  chat-ios
//
//  The source of truth for messages is the backend's episodic memory
//  (GET /sessions/messages; single-session backend, the `chat-<uid>` thread
//  is derived server-side from the token). Sending = POST /ava (or a
//  specialist via @mention). Because the POST only returns once the whole
//  orchestration finishes, we POLL the thread while waiting so agent turns
//  appear one by one, like a group chat.
//

import Foundation

@Observable
final class ConversationStore {
    /// History cap fetched per load.
    static let historyLastN = 200
    /// Delay between polls while waiting for the orchestration reply.
    static let pollInterval: Duration = .milliseconds(2200)
    /// How long to keep watching the thread when the POST dropped on our side
    /// even though the message was already recorded on the server.
    static let watchWindow: Duration = .seconds(90)

    private let api: APIClient
    private let wallet: WalletStore

    private(set) var serverMsgs: [ChatMessage] = []
    /// Optimistic human message not yet visible in the server thread.
    private(set) var pending: ChatMessage?
    /// Ids of server messages that ALREADY existed when the optimistic message
    /// was sent — a same-text human message with an id outside this set means
    /// our message has landed.
    private var pendingBaseline = Set<String>()
    private(set) var thinking: AgentSpec?
    private(set) var busy = false
    private(set) var loaded = false

    private var sendSeq = 0
    /// An in-flight poll must not clobber the result of a later fetch.
    private var fetchSeq = 0

    init(api: APIClient = .shared, wallet: WalletStore) {
        self.api = api
        self.wallet = wallet
    }

    var messages: [ChatMessage] {
        if let pending { serverMsgs + [pending] } else { serverMsgs }
    }

    var empty: Bool {
        loaded && serverMsgs.isEmpty && pending == nil && thinking == nil
    }

    /// Load history from the backend. Called once after login.
    func load() async {
        defer { loaded = true }
        try? await fetchThread()
    }

    func sendText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !trimmed.isEmpty else { return }
        sendSeq += 1
        let msg = ChatMessage(
            id: "local-\(sendSeq)",
            from: "human",
            text: trimmed,
            time: TimeFmt.clock(),
            at: nil,
            status: .sending
        )
        pendingBaseline = Set(serverMsgs.map(\.id))
        pending = msg
        await runTurn(text: trimmed, msgID: msg.id, agent: Agents.route(trimmed))
    }

    /// Resend a failed optimistic message.
    func retry(id: String) async {
        guard !busy, let msg = pending, msg.id == id, !msg.text.isEmpty else { return }
        updatePending { $0.status = .sending }
        // Reconcile first: the previous POST may have persisted this message
        // even though its HTTP response never reached us. Resending without
        // checking = duplicate message = the agent triggered twice.
        try? await fetchThread()
        guard pending?.id == id else { return } // already landed — don't re-POST
        await runTurn(text: msg.text, msgID: id, agent: Agents.route(msg.text))
    }

    /// Reset the conversation: delete chat history AND knowledge at once
    /// (DELETE /knowledge = Zep User.Delete). 404 = already clean.
    func clear() async throws {
        do {
            try await api.delete("/knowledge")
        } catch let e as ApiError where e.status == 404 {
            // no data yet = already empty
        }
        serverMsgs = []
        pending = nil
        pendingBaseline = []
        thinking = nil
        busy = false
    }

    /// Reset local state (called on logout).
    func reset() {
        serverMsgs = []
        pending = nil
        pendingBaseline = []
        thinking = nil
        busy = false
        loaded = false
    }

    // MARK: - Internals

    private func updatePending(_ mutate: (inout ChatMessage) -> Void) {
        guard var msg = pending else { return }
        mutate(&msg)
        pending = msg
    }

    private func fetchThread() async throws {
        fetchSeq += 1
        let seq = fetchSeq
        do {
            // Short timeout: this fetch is called serially by the poller — one
            // request hanging on the network freezes live updates for the whole
            // turn. Fail fast and let the next poll try again.
            let list = try await api.get(
                MessageListDTO.self, "/sessions/messages?lastn=\(Self.historyLastN)",
                timeout: 15
            )
            guard seq == fetchSeq else { return } // a newer fetch exists
            // A nil list = empty body (204/HTTP 200 without payload); don't
            // treat it as "clean thread" — keep the old state until the next
            // fetch actually carries a payload.
            guard let messages = list?.messages else { return }
            let mapped = messages.compactMap { $0.toUIMessage() }
            serverMsgs = mapped
            // The optimistic message reached the server thread → drop the duplicate
            if let p = pending,
               mapped.contains(where: {
                   $0.from == "human" && $0.text == p.text && !pendingBaseline.contains($0.id)
               }) {
                pending = nil
            }
        } catch let e as ApiError where e.status == 404 {
            // the thread was never created — genuinely empty
            if seq == fetchSeq { serverMsgs = [] }
        }
    }

    private func runTurn(text: String, msgID: String, agent: AgentSpec) async {
        busy = true
        thinking = agent

        // Poll the thread during orchestration so delegation/specialist turns show up live
        let poller = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard !Task.isCancelled else { return }
                try? await self?.fetchThread()
            }
        }

        do {
            // Don't hang up before the server does: dropping the connection also
            // cancels the run context server-side (killing the orchestration
            // mid-flight). Cloud Run closes it at its own request timeout
            // (300 s) → 504.
            try await api.post(
                agent.endpoint ?? "/ava",
                body: AgentTurnRequest(message: text),
                timeout: 300
            )
            if pending?.id == msgID { updatePending { $0.status = nil } }
            try? await fetchThread()
        } catch {
            // A failed POST ≠ the message failed to send: the backend persists
            // the human message at the START of a run. Check the server first —
            // if it landed, marking it as an error (and the user tapping
            // "Coba lagi") would trigger the agent twice.
            var landed = false
            do {
                try await fetchThread()
                landed = pending?.id != msgID
            } catch {
                landed = false
            }
            if !landed {
                let note: ChatMessage.ErrorNote? =
                    (error as? ApiError)?.status == 402 ? .saldo : nil
                if pending?.id == msgID { updatePending { $0.status = .error(note: note) } }
            } else if !(error is ApiError) {
                // Network error on our side, but the message was recorded: the
                // orchestration is likely still running — keep the poller alive
                // for a while.
                try? await Task.sleep(for: Self.watchWindow)
                try? await fetchThread()
            }
        }

        poller.cancel()
        thinking = nil
        busy = false
        // the turn just added cost — refresh balance & usage in the background
        await wallet.refreshQuietly()
    }
}
