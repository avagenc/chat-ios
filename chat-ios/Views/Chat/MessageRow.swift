//
//  MessageRow.swift
//  chat-ios
//
//  Group-chat message row. Serif 17pt bubbles, line-height 1.58; agent on the
//  left (surface + line, 6pt top-leading corner), human on the right
//  (accent-tint + accent-tint-strong, 6pt top-trailing corner).
//

import SwiftUI
import UIKit

// MARK: - Text with @mentions + search highlight

enum MentionText {
    /// Render message text: known @agent → accent-deep semibold;
    /// search substring → mark; active match → solid accent/white.
    static func attributed(
        _ text: String, baseSize: CGFloat = 17, query: String = "", activeMatch: Bool = false
    ) -> AttributedString {
        var result = AttributedString(text)
        result.font = .serif(baseSize)
        result.foregroundColor = Theme.ink

        // mentions: /(@\w+)/
        for match in text.matches(of: /@(\w+)/) {
            let id = String(match.1).lowercased()
            guard Agents.byID[id] != nil,
                  let range = Range(match.range, in: result) else { continue }
            result[range].foregroundColor = Theme.accentDeep
            result[range].font = .serif(baseSize, .semibold)
        }

        // search highlight (case-insensitive, every occurrence)
        if !query.isEmpty {
            var searchStart = text.startIndex
            while let found = text.range(
                of: query, options: [.caseInsensitive], range: searchStart ..< text.endIndex
            ) {
                if let range = Range(found, in: result) {
                    if activeMatch {
                        result[range].backgroundColor = Theme.accent
                        result[range].foregroundColor = .white
                    } else {
                        result[range].backgroundColor = Theme.accentTintStrong
                    }
                }
                searchStart = found.upperBound
            }
        }
        return result
    }
}

// MARK: - Bubble shape (6pt pointer corner, 16pt elsewhere)

struct BubbleShape: Shape {
    var isHuman: Bool
    var grouped: Bool

    func path(in rect: CGRect) -> Path {
        let r = Theme.radius
        let pointer = grouped ? r : Theme.bubbleCorner
        return UnevenRoundedRectangle(
            topLeadingRadius: isHuman ? r : pointer,
            bottomLeadingRadius: r,
            bottomTrailingRadius: r,
            topTrailingRadius: isHuman ? pointer : r,
            style: .continuous
        ).path(in: rect)
    }
}

// MARK: - Row

struct MessageRow: View {
    var msg: ChatMessage
    var grouped: Bool
    var query: String = ""
    var activeMatch: Bool = false
    var onRetry: (String) -> Void = { _ in }
    var onAgentTap: (AgentSpec) -> Void = { _ in }

    private let avatarSlot: CGFloat = 26 + 8

    var body: some View {
        VStack(alignment: msg.isHuman ? .trailing : .leading, spacing: 4) {
            // agent byline (name in agent color 12.5/600 + "· role" 11 faint)
            if let agent = msg.agent, !grouped {
                Button {
                    onAgentTap(agent)
                } label: {
                    HStack(spacing: 5) {
                        Text(agent.name)
                            .font(.sans(12.5, .semibold))
                            .foregroundStyle(agent.color)
                        Text("· \(agent.role)")
                            .font(.sans(11))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, avatarSlot + 3)
            }

            HStack(alignment: .top, spacing: 8) {
                if !msg.isHuman {
                    // the avatar slot stays when grouped so bubbles line up
                    if let agent = msg.agent, !grouped {
                        AgentAvatar(agent: agent)
                    } else {
                        Color.clear.frame(width: 26, height: 1)
                    }
                }
                bubble
            }
            .frame(maxWidth: .infinity, alignment: msg.isHuman ? .trailing : .leading)

            statusLine
                .padding(.leading, msg.isHuman ? 0 : avatarSlot)
        }
        .frame(maxWidth: .infinity, alignment: msg.isHuman ? .trailing : .leading)
    }

    private var bubble: some View {
        Group {
            if msg.isTinyMention {
                Text(MentionText.attributed(msg.text, baseSize: 16, query: query, activeMatch: activeMatch))
                    .font(.serif(16, .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(bubbleBackground(in: Capsule()))
            } else {
                Text(MentionText.attributed(msg.text, query: query, activeMatch: activeMatch))
                    .lineSpacing(17 * 0.29) // line-height 1.58
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(bubbleBackground(in: BubbleShape(isHuman: msg.isHuman, grouped: grouped)))
            }
        }
        .overlay {
            if activeMatch {
                BubbleShape(isHuman: msg.isHuman, grouped: grouped)
                    .stroke(Theme.accent, lineWidth: 2)
            }
        }
        .frame(maxWidth: 300, alignment: msg.isHuman ? .trailing : .leading)
        .contextMenu {
            Section(TimeFmt.fullStamp(time: msg.time, at: msg.at)) {
                Button {
                    UIPasteboard.general.string = msg.text
                } label: {
                    Label("Salin teks", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private func bubbleBackground(in shape: some Shape) -> some View {
        shape
            .fill(msg.isHuman ? AnyShapeStyle(Theme.accentTint) : AnyShapeStyle(Theme.surface))
            .overlay(
                shape.stroke(
                    msg.isHuman ? Theme.accentTintStrong : Theme.line, lineWidth: 1
                )
            )
    }

    @ViewBuilder
    private var statusLine: some View {
        switch msg.status {
        case .sending:
            Text("Mengirim…")
                .font(.sans(11))
                .foregroundStyle(Theme.inkFaint)
        case .error(let note):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11, weight: .medium))
                Text(note == .saldo ? "Saldo tidak cukup — isi ulang dulu ya." : "Gagal terkirim.")
                    .font(.sans(11, .medium))
                Button("Coba lagi") {
                    onRetry(msg.id)
                }
                .font(.sans(11, .semibold))
                .foregroundStyle(Theme.accentDeep)
            }
            .foregroundStyle(Theme.accentDeep)
        case nil:
            Text(msg.time)
                .font(.sans(11))
                .foregroundStyle(Theme.inkFaint)
        }
    }
}

// MARK: - Thinking (general indicator: breathing Avagenc mark + whimsical status)

struct ThinkingRow: View {
    /// Playful statuses shown (in random order) while the orchestration runs.
    static let statuses = [
        "combobulating", "bomboclating", "invading syria", "gatau ah males",
        "praying", "manifesting", "reticulating splines", "ngopi dulu bentar",
        "summoning the council", "menghitung domba", "downloading wisdom",
        "percolating", "mikir keras banget", "consulting the elders",
        "menata ulang alam semesta", "polishing neurons",
    ]
    /// Dwell time per status before crossfading to the next.
    static let statusDwell: Duration = .milliseconds(2400)

    @State private var order = Self.statuses.shuffled()
    @State private var index = 0
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // bare mark + status — no avatar circle, no chat bubble
        HStack(spacing: 8) {
            // the Avagenc mark "breathes" — swells and fades in place
            LogoView(size: 18, variant: .accent)
                .scaleEffect(breathing ? 1.18 : 0.88)
                .opacity(breathing ? 1 : 0.45)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 1.05).repeatForever(),
                    value: breathing
                )
                .frame(width: 26, height: 26) // keep the avatar column alignment

            Text("\(order[index])…")
                .font(.sans(13, .medium))
                .foregroundStyle(Theme.inkMuted)
                .id(index)
                .transition(.opacity)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { breathing = true }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.statusDwell)
                guard !Task.isCancelled else { return }
                withAnimation(.avagencEase) {
                    index = (index + 1) % order.count
                }
            }
        }
    }
}

// MARK: - Day divider pill

struct DayDivider: View {
    var label: String

    var body: some View {
        Text(label.uppercased())
            .font(.sans(11))
            .kerning(0.66)
            .foregroundStyle(Theme.inkMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Theme.bgSunk)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
            .frame(maxWidth: .infinity)
    }
}
