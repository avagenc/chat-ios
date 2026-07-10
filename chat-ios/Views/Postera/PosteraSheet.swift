//
//  PosteraSheet.swift
//  chat-ios
//
//  Postera panel: list of self-wake-up messages Ava has scheduled
//  (posterum), accordion + cancel.
//

import SwiftUI

struct PosteraSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var openID: String?
    @State private var refreshing = false
    @State private var confirmItem: Posterum?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                PaperGrain()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if session.postera.list.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 8) {
                                ForEach(session.postera.list) { item in
                                    posterumRow(item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.sidePadding)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Postera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Postera")
                        .font(.serif(19, .medium))
                        .foregroundStyle(Theme.ink)
                }
            }
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { await handleRefresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .spinning(refreshing)
                    }
                    .disabled(refreshing)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .task {
            await handleRefresh()
        }
        .overlay {
            if let item = confirmItem {
                ActionConfirmView(
                    meta: ConfirmMeta(
                        icon: "hourglass",
                        question: "Batalkan posterum ini?",
                        sub: "Ava tidak akan menerima pesan ini di masa depan. Tindakan ini tidak bisa dibatalkan.",
                        button: "Batalkan posterum",
                        account: nil,
                        run: { cancel(item) }
                    ),
                    onCancel: { withAnimation(.avagencEase) { confirmItem = nil } }
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Postera are self wake up messages Ava has scheduled for her future self. A single postera is called a posterum.")
                .font(.sans(12.5))
                .foregroundStyle(Theme.inkMuted)
                .lineSpacing(3)
            if let fetched = session.postera.lastFetched {
                Text("Diperbarui \(fetched)")
                    .font(.sans(11))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.bgSunk)
                Image(systemName: "hourglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
            }
            .frame(width: 44, height: 44)
            Text("Tidak ada posterum aktif saat ini.")
                .font(.sans(13))
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private func posterumRow(_ item: Posterum) -> some View {
        let open = openID == item.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.avagencEase) {
                    openID = open ? nil : item.id
                }
            } label: {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .semibold))
                        Text(item.awakenAt)
                            .font(.sans(11.5, .semibold))
                    }
                    .foregroundStyle(Theme.ava)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.ava.opacity(0.12))
                    .clipShape(Capsule())

                    Text(item.message)
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.inkGhost)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.message)
                        .font(.serif(15.5))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.bgSunk)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                        Text("Bangun pada \(Text(item.awakenAt).font(.sans(12, .semibold)))")
                            .font(.sans(12))
                    }
                    .foregroundStyle(Theme.inkMuted)

                    Button {
                        withAnimation(.avagencEase) { confirmItem = item }
                    } label: {
                        Text("Batalkan posterum")
                            .font(.sans(13, .semibold))
                            .foregroundStyle(Theme.accentDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.accentTint)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding([.horizontal, .bottom], 12)
                .transition(.opacity)
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private func handleRefresh() async {
        guard !refreshing else { return }
        refreshing = true
        try? await session.postera.load()
        refreshing = false
    }

    private func cancel(_ item: Posterum) {
        Task {
            do {
                try await session.postera.cancel(id: item.id)
                session.flashToast("Posterum dibatalkan")
            } catch {
                session.flashToast("Gagal membatalkan posterum. Coba lagi.")
            }
        }
    }
}
