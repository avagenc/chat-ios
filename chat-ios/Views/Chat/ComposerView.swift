//
//  ComposerView.swift
//  chat-ios
//
//  Bottom composer: surface input bar radius 22, line-strong border
//  (focus → accent), auto-growing text field, 40pt accent circle send
//  button, @mention autocomplete above the input.
//

import SwiftUI
import UIKit

struct ComposerView: View {
    @Binding var text: String
    var busy: Bool
    var onSend: (String) -> Void

    @FocusState private var focused: Bool

    /// The @mention token being typed at the end of the text (for autocomplete).
    private var mentionQuery: String? {
        // last token; active only if it starts with '@' and isn't closed by a space
        guard let lastToken = text.split(separator: " ", omittingEmptySubsequences: false).last,
              lastToken.hasPrefix("@") else { return nil }
        let partial = String(lastToken.dropFirst()).lowercased()
        guard partial.wholeMatch(of: /\w*/) != nil else { return nil }
        return partial
    }

    private var mentionMatches: [AgentSpec] {
        guard let q = mentionQuery else { return [] }
        let matches = Agents.all.filter {
            $0.id.hasPrefix(q) || $0.name.lowercased().hasPrefix(q)
        }
        // exactly one match, fully typed → no popup needed
        if matches.count == 1, matches[0].id == q { return [] }
        return matches
    }

    private var canSend: Bool {
        !busy && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if !mentionMatches.isEmpty {
                mentionPopup
                    .padding(.horizontal, Theme.sidePadding)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(alignment: .bottom, spacing: 6) {
                TextField(
                    busy ? "Menunggu balasan agent…" : "Ketik pesan…",
                    text: $text,
                    axis: .vertical
                )
                .font(.sans(15.5))
                .foregroundStyle(Theme.ink)
                .tint(Theme.accent)
                .lineLimit(1 ... 6)
                .focused($focused)
                .disabled(busy)
                .padding(.leading, 10)
                .padding(.vertical, 10)

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(canSend ? .white : Theme.inkFaint)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(canSend ? Theme.accent : Theme.bgSunk))
                }
                .disabled(!canSend)
                .animation(.avagencEase, value: canSend)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(focused ? Theme.accent : Theme.lineStrong, lineWidth: 1)
                    )
            )
            .padding(.horizontal, Theme.sidePadding)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(
                // bg fade gradient above the composer
                LinearGradient(
                    colors: [Theme.bg.opacity(0), Theme.bg, Theme.bg],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
        .animation(.avagencEase, value: mentionMatches.isEmpty)
    }

    private func send() {
        guard canSend else { return }
        let toSend = text
        text = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSend(toSend)
    }

    private func accept(_ agent: AgentSpec) {
        guard let q = mentionQuery else { return }
        text = String(text.dropLast(q.count + 1)) + "@\(agent.id) "
    }

    // MARK: - Autocomplete popup

    private var mentionPopup: some View {
        VStack(spacing: 0) {
            ForEach(Array(mentionMatches.enumerated()), id: \.element.id) { index, agent in
                Button {
                    accept(agent)
                } label: {
                    HStack(spacing: 10) {
                        AgentAvatar(agent: agent, size: 28, logoSize: 14)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(agent.name)
                                .font(.sans(13.5, .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(agent.role)
                                .font(.sans(11))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < mentionMatches.count - 1 {
                    Divider().overlay(Theme.line).padding(.leading, 50)
                }
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.lineStrong, lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.13), radius: 12, y: 8)
    }
}
