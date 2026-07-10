//
//  ChatScreen.swift
//  chat-ios
//
//  Main screen: group-chat canvas + composer + search mode.
//

import SwiftUI

struct ChatScreen: View {
    @Environment(SessionStore.self) private var session

    @State private var draft = ""
    @State private var agentInfo: AgentSpec?

    private var conversation: ConversationStore { session.conversation }

    // ---- search ----
    private var query: String {
        session.searchActive ? session.searchQuery.trimmingCharacters(in: .whitespaces) : ""
    }

    private var matches: [String] {
        guard !query.isEmpty else { return [] }
        return conversation.messages
            .filter { $0.text.lowercased().contains(query.lowercased()) }
            .map(\.id)
    }

    private var clampedIndex: Int {
        matches.isEmpty ? 0 : min(session.searchIndex, matches.count - 1)
    }

    private var activeMatchID: String? {
        matches.isEmpty ? nil : matches[clampedIndex]
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            PaperGrain()

            ScrollViewReader { proxy in
                ScrollView {
                    canvasContent
                        .padding(.horizontal, Theme.sidePadding)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(.bottom)
                .onChange(of: conversation.messages.count) {
                    scrollToBottom(proxy)
                }
                .onChange(of: conversation.thinking) {
                    scrollToBottom(proxy)
                }
                .onChange(of: activeMatchID) { _, id in
                    if let id {
                        withAnimation(.avagencEase) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if session.searchActive {
                searchBar
            } else {
                ComposerView(
                    text: $draft,
                    busy: conversation.busy,
                    onSend: { text in Task { await conversation.sendText(text) } },
                    onCancel: { conversation.cancelTurn() }
                )
            }
        }
        .sheet(item: $agentInfo) { agent in
            AgentInfoSheet(agent: agent)
        }
        #if DEBUG
        // Test automation: `-autoSend "<text>"` sends through the real path;
        // `-prefillDraft "<text>"` only fills the composer (no send).
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-prefillDraft"), args.indices.contains(i + 1) {
                draft = args[i + 1]
            }
            guard let i = args.firstIndex(of: "-autoSend"), args.indices.contains(i + 1) else {
                return
            }
            while !conversation.loaded {
                try? await Task.sleep(for: .milliseconds(200))
            }
            try? await Task.sleep(for: .seconds(1))
            await conversation.sendText(args[i + 1])
        }
        #endif
    }

    // MARK: - Canvas

    @ViewBuilder
    private var canvasContent: some View {
        if !conversation.loaded {
            // history still loading — hold rendering so the empty state doesn't flash
            Color.clear.frame(height: 1)
        } else if conversation.empty {
            EmptyStateView { suggestion in
                Task { await conversation.sendText(suggestion) }
            }
            .frame(minHeight: 480)
        } else {
            LazyVStack(spacing: 0) {
                DayDivider(label: "Hari ini")
                    .padding(.bottom, Theme.messageGap)

                ForEach(Array(conversation.messages.enumerated()), id: \.element.id) { index, msg in
                    MessageRow(
                        msg: msg,
                        grouped: grouped(index),
                        query: query,
                        activeMatch: msg.id == activeMatchID,
                        onRetry: { id in Task { await conversation.retry(id: id) } },
                        onAgentTap: { agentInfo = $0 }
                    )
                    .id(msg.id)
                    .padding(.bottom, isLast(index) ? 0 : gapAfter(index))
                    .riseIn()
                }

                if conversation.thinking {
                    ThinkingRow()
                        .padding(.top, Theme.messageGap)
                        .riseIn()
                }

                Color.clear.frame(height: 1).id("chat-bottom")
            }
        }
    }

    /// Consecutive messages from the same sender (previous one not an error) are grouped.
    private func grouped(_ index: Int) -> Bool {
        guard index > 0 else { return false }
        let prev = conversation.messages[index - 1]
        let cur = conversation.messages[index]
        return prev.from == cur.from && prev.status == nil
    }

    private func isLast(_ index: Int) -> Bool {
        index == conversation.messages.count - 1
    }

    private func gapAfter(_ index: Int) -> CGFloat {
        grouped(index + 1) ? Theme.groupedGap : Theme.messageGap
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard !session.searchActive else { return }
        withAnimation(.avagencEase) {
            proxy.scrollTo("chat-bottom", anchor: .bottom)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkFaint)

            TextField("Cari di chat…", text: searchQueryBinding)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
                .tint(Theme.accent)
                .submitLabel(.search)
                .onSubmit { nextMatch() }

            if !query.isEmpty {
                Text("\(matches.isEmpty ? 0 : clampedIndex + 1)/\(matches.count)")
                    .font(.sans(12))
                    .foregroundStyle(Theme.inkFaint)
                    .monospacedDigit()
            }

            Button { prevMatch() } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(matches.isEmpty ? Theme.inkGhost : Theme.inkSoft)
                    .frame(width: 30, height: 30)
            }
            .disabled(matches.isEmpty)

            Button { nextMatch() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(matches.isEmpty ? Theme.inkGhost : Theme.inkSoft)
                    .frame(width: 30, height: 30)
            }
            .disabled(matches.isEmpty)

            Button("Selesai") {
                withAnimation(.avagencEase) { session.closeSearch() }
            }
            .font(.sans(14, .semibold))
            .foregroundStyle(Theme.accentDeep)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.lineStrong, lineWidth: 1)
                )
                .shadow(color: Theme.ink.opacity(0.13), radius: 12, y: 6)
        )
        .padding(.horizontal, Theme.sidePadding)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Theme.bg.opacity(0), Theme.bg, Theme.bg],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var searchQueryBinding: Binding<String> {
        Binding(
            get: { session.searchQuery },
            set: {
                session.searchQuery = $0
                session.searchIndex = 0
            }
        )
    }

    private func nextMatch() {
        guard !matches.isEmpty else { return }
        session.searchIndex = (clampedIndex + 1) % matches.count
    }

    private func prevMatch() {
        guard !matches.isEmpty else { return }
        session.searchIndex = (clampedIndex - 1 + matches.count) % matches.count
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    var onSuggestion: (String) -> Void

    private let suggestions = [
        "Kenalan dong!",
        "Avagenc Chat nih apa ya?",
        "Kamu bisa bantu apa aja?",
    ]

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle().fill(Theme.accentTint)
                LogoView(size: 26, variant: .accent)
            }
            .frame(width: 52, height: 52)

            Text("Hello, Human. We have been longing to serve you! What do you need?")
                .font(.serif(24))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 8)

            Text("Silakan coba mulai percakapan dengan contoh pesan berikut:")
                .font(.sans(13))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSuggestion(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.sans(13.5, .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Theme.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Theme.lineStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .riseIn()
    }
}

// MARK: - Agent info sheet

struct AgentInfoSheet: View {
    var agent: AgentSpec
    var soon: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AgentAvatar(agent: agent, size: 44, logoSize: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.serif(21, .medium))
                        .foregroundStyle(Theme.ink)
                    Text(agent.role)
                        .font(.sans(12))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
            }

            Text(agent.desc)
                .font(.sans(14))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(4)

            if soon {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .medium))
                    Text("Segera hadir — lagi disiapin")
                        .font(.sans(12, .medium))
                }
                .foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(220)])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
    }
}
