//
//  ChatInfoScreen.swift
//  chat-ios
//
//  Chat info page: identity, agent roster (active + "Soon" teasers),
//  in-chat search, and Reset chat & knowledge.
//

import SwiftUI

struct ChatInfoScreen: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    var onSearch: () -> Void

    @State private var openAgentID: String?
    @State private var confirmReset = false

    private struct RosterAgent: Identifiable {
        let spec: AgentSpec
        let soon: Bool
        var id: String { spec.id }
    }

    private var roster: [RosterAgent] {
        Agents.all.map { RosterAgent(spec: $0, soon: false) }
            + Agents.soon.map { RosterAgent(spec: $0, soon: true) }
    }

    private var openAgent: RosterAgent? {
        roster.first { $0.id == openAgentID }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            PaperGrain()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    identity
                    agentsSection
                    searchSection
                    manageSection
                }
                .padding(.horizontal, Theme.sidePadding)
                .padding(.vertical, 24)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .overlay {
            if confirmReset {
                ActionConfirmView(
                    meta: ConfirmMeta(
                        icon: "trash",
                        question: "Reset chat & knowledge?",
                        sub: "Semua pesan di obrolan ini dan semua yang sudah Ava pelajari soal kamu akan dihapus sekaligus. Tindakan ini tidak bisa dibatalkan.",
                        button: "Reset semua",
                        account: nil,
                        run: { resetChat() }
                    ),
                    onCancel: { withAnimation(.avagencEase) { confirmReset = false } }
                )
            }
        }
    }

    // MARK: - Identity

    private var identity: some View {
        VStack(spacing: 10) {
            LogoView(size: 60, variant: .ink)
            Text("Avagenc")
                .font(.serif(23, .medium))
                .foregroundStyle(Theme.ink)
            Text("Tim multi-agent yang bekerja bareng untuk melayani kamu.")
                .font(.sans(13))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Agent roster

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupLabel(text: "\(Agents.all.count) agen")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(roster) { item in
                        agentChip(item)
                    }
                }
                .padding(.horizontal, 2)
            }

            if let open = openAgent {
                agentDetail(open)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.avagencEase, value: openAgentID)
    }

    private func agentChip(_ item: RosterAgent) -> some View {
        Button {
            openAgentID = openAgentID == item.id ? nil : item.id
        } label: {
            VStack(spacing: 6) {
                AgentAvatar(agent: item.spec, size: 54, logoSize: 24)
                    .opacity(item.soon ? 0.55 : 1)
                    .overlay(
                        Circle().strokeBorder(
                            openAgentID == item.id ? Theme.accent : .clear, lineWidth: 2
                        )
                        .padding(-3)
                    )
                    .overlay(alignment: .topTrailing) {
                        if item.soon {
                            Text("Soon")
                                .font(.sans(8.5, .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.inkMuted))
                                .offset(x: 6, y: -2)
                        }
                    }
                Text(item.spec.name)
                    .font(.sans(12, .medium))
                    .foregroundStyle(item.soon ? Theme.inkFaint : Theme.inkSoft)
            }
        }
        .buttonStyle(.plain)
    }

    private func agentDetail(_ item: RosterAgent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AgentAvatar(agent: item.spec, size: 36, logoSize: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.spec.name)
                        .font(.sans(14.5, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(item.spec.role)
                        .font(.sans(11.5))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            Text(item.spec.desc)
                .font(.sans(13))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3)
            if item.soon {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .medium))
                    Text("Segera hadir — lagi disiapin")
                        .font(.sans(12, .medium))
                }
                .foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            // leading accent border
            UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14)
                .fill(item.spec.color)
                .frame(width: 3)
        }
    }

    // MARK: - Search in chat

    private var searchSection: some View {
        SettingsRow(
            icon: "magnifyingglass",
            title: "Cari di chat",
            subtitle: "Temukan pesan, nama, atau kata",
            danger: false,
            action: onSearch
        )
    }

    // MARK: - Manage

    private var manageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupLabel(text: "Kelola")
            SettingsRow(
                icon: "trash",
                title: "Reset chat & knowledge",
                subtitle: "Hapus semua pesan dan yang Ava pelajari soal kamu",
                danger: true,
                action: { withAnimation(.avagencEase) { confirmReset = true } }
            )
        }
    }

    private func resetChat() {
        Task {
            do {
                try await session.conversation.clear()
                session.flashToast("Chat direset")
                dismiss()
            } catch {
                session.flashToast("Gagal mereset chat. Coba lagi.")
            }
        }
    }
}

// MARK: - Settings row

struct SettingsRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var danger: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(danger ? Theme.accentDeep : Theme.inkSoft)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.sans(14.5, .medium))
                        .foregroundStyle(danger ? Theme.accentDeep : Theme.ink)
                    Text(subtitle)
                        .font(.sans(12))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(-90))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkGhost)
            }
            .padding(14)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
